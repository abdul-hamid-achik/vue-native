package com.vuenative.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.android.billingclient.api.*

/**
 * Native module for In-App Purchases using Google Play Billing Library.
 *
 * Methods:
 *   - initialize() -- set up BillingClient connection
 *   - getProducts(skus: List<String>) -- fetch product details
 *   - purchase(sku: String) -- launch purchase flow
 *   - restorePurchases() -- query existing purchases
 *   - getActiveSubscriptions() -- list active subscriptions
 *
 * Events:
 *   - iap:transactionUpdate { productId, state, transactionId, error? }
 */
class IAPModule : NativeModule, PurchasesUpdatedListener {
    override val moduleName = "IAP"
    private var context: Context? = null
    private var bridge: NativeBridge? = null
    private var billingClient: BillingClient? = null
    private var pendingPurchaseCallback: ((Any?, String?) -> Unit)? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cachedProducts = mutableMapOf<String, ProductDetails>()

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
        this.bridge = bridge
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "initialize" -> handleInitialize(callback)
            "getProducts" -> {
                @Suppress("UNCHECKED_CAST")
                val skus = args.getOrNull(0) as? List<String> ?: run {
                    callback(null, "getProducts: expected array of SKU strings")
                    return
                }
                handleGetProducts(skus, callback)
            }
            "purchase" -> {
                val sku = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "purchase: expected SKU string")
                    return
                }
                handlePurchase(sku, bridge, callback)
            }
            "restorePurchases" -> handleRestorePurchases(callback)
            "getActiveSubscriptions" -> handleGetActiveSubscriptions(callback)
            else -> callback(null, "IAPModule: unknown method '$method'")
        }
    }

    // ── Initialize ──────────────────────────────────────────────────────────

    private fun handleInitialize(callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run { callback(null, "IAP: no context"); return }

        billingClient = BillingClient.newBuilder(ctx)
            .setListener(this)
            .enablePendingPurchases()
            .build()

        billingClient?.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    callback(null, null)
                } else {
                    callback(null, "IAP initialize failed: ${result.debugMessage}")
                }
            }

            override fun onBillingServiceDisconnected() {
                // Retry connection on next invoke
            }
        })
    }

    // ── Get Products ────────────────────────────────────────────────────────

    private fun handleGetProducts(skus: List<String>, callback: (Any?, String?) -> Unit) {
        val client = billingClient ?: run { callback(null, "IAP: not initialized"); return }

        // Query both INAPP and SUBS
        val inappParams = QueryProductDetailsParams.newBuilder()
            .setProductList(skus.map { sku ->
                QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(sku)
                    .setProductType(BillingClient.ProductType.INAPP)
                    .build()
            })
            .build()

        val subsParams = QueryProductDetailsParams.newBuilder()
            .setProductList(skus.map { sku ->
                QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(sku)
                    .setProductType(BillingClient.ProductType.SUBS)
                    .build()
            })
            .build()

        val allProducts = mutableListOf<Map<String, Any>>()

        client.queryProductDetailsAsync(inappParams) { inappResult, inappDetails ->
            if (inappResult.responseCode == BillingClient.BillingResponseCode.OK) {
                for (details in inappDetails) {
                    cachedProducts[details.productId] = details
                    allProducts.add(productDetailsToMap(details))
                }
            }

            client.queryProductDetailsAsync(subsParams) { subsResult, subsDetails ->
                if (subsResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    for (details in subsDetails) {
                        cachedProducts[details.productId] = details
                        allProducts.add(productDetailsToMap(details))
                    }
                }

                callback(allProducts, null)
            }
        }
    }

    // ── Purchase ────────────────────────────────────────────────────────────

    private fun handlePurchase(sku: String, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val client = billingClient ?: run { callback(null, "IAP: not initialized"); return }
        val productDetails = cachedProducts[sku] ?: run {
            callback(null, "purchase: product '$sku' not found. Call getProducts first.")
            return
        }

        pendingPurchaseCallback = callback

        val flowParamsBuilder = BillingFlowParams.newBuilder()

        // Handle subscription vs one-time
        val offerToken = productDetails.subscriptionOfferDetails?.firstOrNull()?.offerToken
        val productBuilder = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(productDetails)
        if (offerToken != null) {
            productBuilder.setOfferToken(offerToken)
        }
        flowParamsBuilder.setProductDetailsParamsList(listOf(productBuilder.build()))

        val activity = (context as? android.app.Activity) ?: run {
            callback(null, "purchase: no activity available")
            pendingPurchaseCallback = null
            return
        }

        mainHandler.post {
            val result = client.launchBillingFlow(activity, flowParamsBuilder.build())
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                pendingPurchaseCallback?.invoke(null, "purchase: billing flow failed: ${result.debugMessage}")
                pendingPurchaseCallback = null
            }
        }
    }

    // ── PurchasesUpdatedListener ────────────────────────────────────────────

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        val callback = pendingPurchaseCallback
        pendingPurchaseCallback = null

        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                val purchase = purchases?.firstOrNull()
                if (purchase != null) {
                    acknowledgePurchase(purchase)
                    val info = mapOf(
                        "productId" to (purchase.products.firstOrNull() ?: ""),
                        "transactionId" to purchase.orderId,
                        "purchaseDate" to purchase.purchaseTime.toString(),
                    )
                    callback?.invoke(info, null)
                    bridge?.dispatchGlobalEvent("iap:transactionUpdate", mapOf(
                        "productId" to (purchase.products.firstOrNull() ?: ""),
                        "state" to "purchased",
                        "transactionId" to purchase.orderId,
                    ))
                } else {
                    callback?.invoke(null, "purchase: no purchase returned")
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                callback?.invoke(null, "purchase: user cancelled")
                bridge?.dispatchGlobalEvent("iap:transactionUpdate", mapOf(
                    "productId" to "",
                    "state" to "failed",
                    "error" to "user cancelled",
                ))
            }
            else -> {
                val error = "purchase failed: ${result.debugMessage}"
                callback?.invoke(null, error)
                bridge?.dispatchGlobalEvent("iap:transactionUpdate", mapOf(
                    "productId" to "",
                    "state" to "failed",
                    "error" to error,
                ))
            }
        }
    }

    // ── Restore Purchases ───────────────────────────────────────────────────

    private fun handleRestorePurchases(callback: (Any?, String?) -> Unit) {
        val client = billingClient ?: run { callback(null, "IAP: not initialized"); return }

        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()

        client.queryPurchasesAsync(params) { inappResult, inappPurchases ->
            val restored = mutableListOf<Map<String, Any?>>()
            if (inappResult.responseCode == BillingClient.BillingResponseCode.OK) {
                for (p in inappPurchases) {
                    restored.add(purchaseToMap(p))
                }
            }

            val subsParams = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()

            client.queryPurchasesAsync(subsParams) { subsResult, subsPurchases ->
                if (subsResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    for (p in subsPurchases) {
                        restored.add(purchaseToMap(p))
                    }
                }
                callback(restored, null)
            }
        }
    }

    // ── Active Subscriptions ────────────────────────────────────────────────

    private fun handleGetActiveSubscriptions(callback: (Any?, String?) -> Unit) {
        val client = billingClient ?: run { callback(null, "IAP: not initialized"); return }

        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()

        client.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                val active = purchases
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .map { purchaseToMap(it) }
                callback(active, null)
            } else {
                callback(null, "getActiveSubscriptions: ${result.debugMessage}")
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun acknowledgePurchase(purchase: Purchase) {
        if (purchase.isAcknowledged) return
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        billingClient?.acknowledgePurchase(params) { /* fire and forget */ }
    }

    private fun productDetailsToMap(details: ProductDetails): Map<String, Any> {
        val oneTime = details.oneTimePurchaseOfferDetails
        val sub = details.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList?.firstOrNull()

        return mapOf(
            "id" to details.productId,
            "displayName" to details.name,
            "description" to details.description,
            "price" to ((oneTime?.priceAmountMicros ?: sub?.priceAmountMicros ?: 0L) / 1_000_000.0),
            "displayPrice" to (oneTime?.formattedPrice ?: sub?.formattedPrice ?: ""),
            "currencyCode" to (oneTime?.priceCurrencyCode ?: sub?.priceCurrencyCode ?: ""),
            "type" to if (details.productType == BillingClient.ProductType.SUBS) "autoRenewable" else "nonConsumable",
        )
    }

    private fun purchaseToMap(purchase: Purchase): Map<String, Any?> = mapOf(
        "productId" to (purchase.products.firstOrNull() ?: ""),
        "transactionId" to purchase.orderId,
        "purchaseDate" to purchase.purchaseTime.toString(),
    )

    override fun destroy() {
        billingClient?.endConnection()
        billingClient = null
    }
}
