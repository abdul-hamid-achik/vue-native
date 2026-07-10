import LocalAuthentication
import VueNativeShared

/// Native module providing biometric authentication (Touch ID) on macOS.
///
/// Methods:
///   - getSupportedBiometry() -> "touchID"/"none"
///   - isAvailable() -> Bool
///   - authenticate(reason: String) -> { success: Bool }
final class BiometryModule: NativeModule {
    let moduleName = "Biometry"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "getSupportedBiometry", "isAvailable":
            let context = LAContext()
            var error: NSError?
            let canEvaluate = context.canEvaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                error: &error
            )

            let biometryType: String
            if canEvaluate {
                switch context.biometryType {
                case .touchID:
                    biometryType = "touchID"
                default:
                    biometryType = "none"
                }
            } else {
                biometryType = "none"
            }

            if method == "isAvailable" {
                callback(canEvaluate, nil)
            } else {
                callback(biometryType, nil)
            }

        case "authenticate":
            let reason = args.first as? String ?? "Authenticate"
            let context = LAContext()

            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if success {
                    callback(["success": true], nil)
                } else {
                    let message = error?.localizedDescription ?? "Authentication failed"
                    callback(["success": false, "error": message], nil)
                }
            }

        default:
            callback(nil, "BiometryModule: Unknown method '\(method)'")
        }
    }
}
