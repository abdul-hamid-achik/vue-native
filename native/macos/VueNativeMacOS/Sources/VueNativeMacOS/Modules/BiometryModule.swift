import LocalAuthentication
import VueNativeShared

/// Native module providing biometric authentication (Touch ID) on macOS.
///
/// Methods:
///   - isAvailable() -> { available: Bool, biometryType: "touchId"/"none" }
///   - authenticate(reason: String) -> { success: Bool }
final class BiometryModule: NativeModule {
    let moduleName = "Biometry"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "isAvailable":
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
                    biometryType = "touchId"
                default:
                    biometryType = "none"
                }
            } else {
                biometryType = "none"
            }

            let result: [String: Any] = [
                "available": canEvaluate,
                "biometryType": biometryType
            ]
            callback(result, nil)

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
                    callback(nil, message)
                }
            }

        default:
            callback(nil, "BiometryModule: Unknown method '\(method)'")
        }
    }
}
