#if canImport(UIKit)
import StoreKit

/// Native module for In-App Purchases using StoreKit 2.
///
/// Methods:
///   - initialize() -- set up transaction listener
///   - getProducts(skus: [String]) -- fetch product info
///   - purchase(sku: String, options?: { appAccountToken?: UUID string }) -- purchase a product
///   - restorePurchases() -- restore completed transactions
///   - getActiveSubscriptions() -- list active auto-renewable subscriptions
///   - showManageSubscriptions() -- open the system "manage subscriptions" sheet
///
/// Every transaction dictionary carries `jwsRepresentation` (the App Store–signed JWS a
/// server verifies with the App Store Server Library) and the `appAccountToken` the app
/// attached at purchase, so a backend can grant entitlements without trusting the client.
///
/// Events:
///   - iap:transactionUpdate { productId, state, transactionId, jwsRepresentation?, error? }
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
            var purchaseOptions: Set<Product.PurchaseOption> = []
            if let options = args.dropFirst().first as? [String: Any],
               let token = options["appAccountToken"] as? String {
                guard let uuid = UUID(uuidString: token) else {
                    callback(nil, "purchase: appAccountToken must be a UUID string")
                    return
                }
                purchaseOptions.insert(.appAccountToken(uuid))
            }
            Task {
                do {
                    let products = try await Product.products(for: [sku])
                    guard let product = products.first else {
                        callback(nil, "purchase: product '\(sku)' not found")
                        return
                    }
                    let result = try await product.purchase(options: purchaseOptions)
                    switch result {
                    case .success(let verification):
                        let transaction = try self.checkVerification(verification)
                        await transaction.finish()
                        callback(Self.transactionInfo(transaction, jws: verification.jwsRepresentation), nil)
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
                            restored.append(Self.transactionInfo(transaction, jws: result.jwsRepresentation))
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
                        active.append(Self.transactionInfo(transaction, jws: result.jwsRepresentation))
                    }
                }
                callback(active, nil)
            }

        case "showManageSubscriptions":
            Task { @MainActor in
                guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
                else {
                    callback(nil, "showManageSubscriptions: no active window scene")
                    return
                }
                do {
                    try await AppStore.showManageSubscriptions(in: scene)
                    callback(nil, nil)
                } catch {
                    callback(nil, "showManageSubscriptions: \(error.localizedDescription)")
                }
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
                    var payload = Self.transactionInfo(transaction, jws: result.jwsRepresentation)
                    payload["state"] = transaction.revocationDate == nil ? "purchased" : "revoked"
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

    /// The dictionary every method returns for a verified transaction.
    static func transactionInfo(_ transaction: Transaction, jws: String) -> [String: Any] {
        var info: [String: Any] = [
            "productId": transaction.productID,
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "purchaseDate": transaction.purchaseDate.ISO8601Format(),
            "jwsRepresentation": jws,
        ]
        if let expires = transaction.expirationDate {
            info["expiresDate"] = expires.ISO8601Format()
        }
        if let token = transaction.appAccountToken {
            info["appAccountToken"] = token.uuidString.lowercased()
        }
        if #available(iOS 16.0, *) {
            info["environment"] = transaction.environment.rawValue
        }
        return info
    }

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

    func destroy() {
        transactionTask?.cancel()
        transactionTask = nil
    }
}
#endif
