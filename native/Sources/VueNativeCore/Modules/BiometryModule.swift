#if canImport(UIKit)
import UIKit
import LocalAuthentication

/// Native module for biometric authentication (Face ID, Touch ID, Optic ID).
///
/// Methods:
///   - getSupportedBiometry() -> "faceID" | "touchID" | "opticID" | "none"
///   - isAvailable() -> Bool
///   - authenticate(reason: String) -> { success: Bool, error?: String }
final class BiometryModule: NativeModule {
    var moduleName: String { "Biometry" }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "getSupportedBiometry":
            callback(supportedBiometry(), nil)
        case "isAvailable":
            let context = LAContext()
            var error: NSError?
            let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            callback(available, nil)
        case "authenticate":
            let reason = args.first as? String ?? "Authenticate"
            authenticate(reason: reason, callback: callback)
        default:
            callback(nil, "BiometryModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Private helpers

    private func authenticate(reason: String, callback: @escaping (Any?, String?) -> Void) {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            if success {
                callback(["success": true], nil)
            } else {
                let msg = error?.localizedDescription ?? "Authentication failed"
                callback(["success": false, "error": msg], nil)
            }
        }
    }

    private func supportedBiometry() -> String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "none"
        }
        switch context.biometryType {
        case .faceID:  return "faceID"
        case .touchID: return "touchID"
        case .opticID: return "opticID"
        default:       return "none"
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
#endif
