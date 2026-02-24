#if canImport(UIKit)
import StoreKit

/// Native module for In-App Purchases using StoreKit 2.
///
/// Methods:
///   - initialize() -- set up transaction listener
///   - getProducts(skus: [String]) -- fetch product info
///   - purchase(sku: String) -- purchase a product
///   - restorePurchases() -- restore completed transactions
///   - getActiveSubscriptions() -- list active auto-renewable subscriptions
///
/// Events:
///   - iap:transactionUpdate { productId, state, transactionId, error? }
@available(iOS 15.0, *)
final class IAPModule: NativeModule {
    let moduleName = "IAP"
    private weak var bridge: NativeBridge?
    private var transactionTask: Task<Void, Never>?

    init(bridge: NativeBridge? = nil) {
        self.bridge = bridge
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "initialize":
            startTransactionListener()
            callback(nil, nil)

        case "getProducts":
            guard let skus = args.first as? [String] else {
                callback(nil, "getProducts: expected array of SKU strings")
                return
            }
            Task {
                do {
                    let products = try await Product.products(for: Set(skus))
                    let result: [[String: Any]] = products.map { product in
                        [
                            "id": product.id,
                            "displayName": product.displayName,
                            "description": product.description,
                            "price": NSDecimalNumber(decimal: product.price).doubleValue,
                            "displayPrice": product.displayPrice,
                            "currencyCode": product.priceFormatStyle.currencyCode,
                            "type": self.productTypeString(product.type),
                        ]
                    }
                    callback(result, nil)
                } catch {
                    callback(nil, "getProducts: \(error.localizedDescription)")
                }
            }

        case "purchase":
            guard let sku = args.first as? String else {
                callback(nil, "purchase: expected SKU string")
                return
            }
            Task {
                do {
                    let products = try await Product.products(for: [sku])
                    guard let product = products.first else {
                        callback(nil, "purchase: product '\(sku)' not found")
                        return
                    }
                    let result = try await product.purchase()
                    switch result {
                    case .success(let verification):
                        let transaction = try self.checkVerification(verification)
                        await transaction.finish()
                        let purchaseInfo: [String: Any] = [
                            "productId": transaction.productID,
                            "transactionId": String(transaction.id),
                            "purchaseDate": transaction.purchaseDate.ISO8601Format(),
                        ]
                        callback(purchaseInfo, nil)
                    case .userCancelled:
                        callback(nil, "purchase: user cancelled")
                    case .pending:
                        callback(nil, "purchase: transaction pending approval")
                    @unknown default:
                        callback(nil, "purchase: unknown result")
                    }
                } catch {
                    callback(nil, "purchase: \(error.localizedDescription)")
                }
            }

        case "restorePurchases":
            Task {
                do {
                    try await AppStore.sync()
                    var restored: [[String: Any]] = []
                    for await result in Transaction.currentEntitlements {
                        if let transaction = try? self.checkVerification(result) {
                            var info: [String: Any] = [
                                "productId": transaction.productID,
                                "transactionId": String(transaction.id),
                                "purchaseDate": transaction.purchaseDate.ISO8601Format(),
                            ]
                            if let expires = transaction.expirationDate {
                                info["expiresDate"] = expires.ISO8601Format()
                            }
                            restored.append(info)
                        }
                    }
                    callback(restored, nil)
                } catch {
                    callback(nil, "restorePurchases: \(error.localizedDescription)")
                }
            }

        case "getActiveSubscriptions":
            Task {
                var active: [[String: Any]] = []
                for await result in Transaction.currentEntitlements {
                    if let transaction = try? self.checkVerification(result) {
                        guard transaction.productType == .autoRenewable else { continue }
                        guard transaction.revocationDate == nil else { continue }
                        var info: [String: Any] = [
                            "productId": transaction.productID,
                            "transactionId": String(transaction.id),
                            "purchaseDate": transaction.purchaseDate.ISO8601Format(),
                        ]
                        if let expires = transaction.expirationDate {
                            info["expiresDate"] = expires.ISO8601Format()
                        }
                        active.append(info)
                    }
                }
                callback(active, nil)
            }

        default:
            callback(nil, "IAPModule: unknown method '\(method)'")
        }
    }

    // MARK: - Transaction Listener

    private func startTransactionListener() {
        transactionTask?.cancel()
        transactionTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                do {
                    let transaction = try self.checkVerification(result)
                    await transaction.finish()
                    let payload: [String: Any] = [
                        "productId": transaction.productID,
                        "state": "purchased",
                        "transactionId": String(transaction.id),
                    ]
                    await MainActor.run {
                        self.bridge?.dispatchGlobalEvent("iap:transactionUpdate", payload: payload)
                    }
                } catch {
                    let payload: [String: Any] = [
                        "productId": "",
                        "state": "failed",
                        "error": error.localizedDescription,
                    ]
                    await MainActor.run {
                        self.bridge?.dispatchGlobalEvent("iap:transactionUpdate", payload: payload)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func productTypeString(_ type: Product.ProductType) -> String {
        switch type {
        case .consumable: return "consumable"
        case .nonConsumable: return "nonConsumable"
        case .autoRenewable: return "autoRenewable"
        case .nonRenewable: return "nonRenewable"
        default: return "unknown"
        }
    }
}
#endif
