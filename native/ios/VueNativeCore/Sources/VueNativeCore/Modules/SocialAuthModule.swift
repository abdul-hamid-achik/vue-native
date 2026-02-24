#if canImport(UIKit)
import UIKit
import AuthenticationServices

/// Native module for social authentication (Apple Sign In, Google Sign In).
///
/// Methods:
///   - signInWithApple() -- present Apple Sign In sheet
///   - signInWithGoogle(clientId: String) -- present Google OAuth web flow
///   - signOut(provider: String) -- clear cached credentials
///   - getCurrentUser(provider: String) -- check for existing session
///
/// Events:
///   - auth:appleCredentialRevoked -- fired when Apple credential is revoked
final class SocialAuthModule: NSObject, NativeModule, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let moduleName = "SocialAuth"
    private weak var bridge: NativeBridge?
    private var appleSignInCallback: ((Any?, String?) -> Void)?
    private var credentialObserver: NSObjectProtocol?

    init(bridge: NativeBridge? = nil) {
        self.bridge = bridge
        super.init()
        observeAppleCredentialRevocation()
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "signInWithApple":
            handleAppleSignIn(callback: callback)

        case "signInWithGoogle":
            guard let clientId = args.first as? String else {
                callback(nil, "signInWithGoogle: expected clientId string")
                return
            }
            handleGoogleSignIn(clientId: clientId, callback: callback)

        case "signOut":
            let provider = args.first as? String ?? "apple"
            handleSignOut(provider: provider, callback: callback)

        case "getCurrentUser":
            let provider = args.first as? String ?? "apple"
            handleGetCurrentUser(provider: provider, callback: callback)

        default:
            callback(nil, "SocialAuthModule: unknown method '\(method)'")
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(callback: @escaping (Any?, String?) -> Void) {
        appleSignInCallback = callback

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleSignInCallback?(nil, "signInWithApple: unexpected credential type")
            appleSignInCallback = nil
            return
        }

        var result: [String: Any] = [
            "userId": credential.user,
        ]

        if let email = credential.email {
            result["email"] = email
        }

        if let fullName = credential.fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                result["fullName"] = name
            }
        }

        if let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) {
            result["identityToken"] = token
        }

        if let codeData = credential.authorizationCode, let code = String(data: codeData, encoding: .utf8) {
            result["authorizationCode"] = code
        }

        // Persist user ID for session check
        UserDefaults.standard.set(credential.user, forKey: "vn_apple_userId")

        appleSignInCallback?(result, nil)
        appleSignInCallback = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain && nsError.code == ASAuthorizationError.canceled.rawValue {
            appleSignInCallback?(nil, "signInWithApple: user cancelled")
        } else {
            appleSignInCallback?(nil, "signInWithApple: \(error.localizedDescription)")
        }
        appleSignInCallback = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }

    // MARK: - Google Sign In (URL-based OAuth)

    private func handleGoogleSignIn(clientId: String, callback: @escaping (Any?, String?) -> Void) {
        // URL-based OAuth flow using ASWebAuthenticationSession for zero dependencies
        let redirectURI = "com.googleusercontent.apps.\(clientId.components(separatedBy: ".").first ?? clientId):/oauthredirect"
        let scope = "openid email profile"
        let urlString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientId)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope)"

        guard let url = URL(string: urlString) else {
            callback(nil, "signInWithGoogle: invalid OAuth URL")
            return
        }

        DispatchQueue.main.async {
            let scheme = redirectURI.components(separatedBy: ":").first
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain &&
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        callback(nil, "signInWithGoogle: user cancelled")
                    } else {
                        callback(nil, "signInWithGoogle: \(error.localizedDescription)")
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    callback(nil, "signInWithGoogle: no authorization code received")
                    return
                }

                let result: [String: Any] = [
                    "userId": code, // The auth code — exchange server-side for tokens
                    "authorizationCode": code,
                ]

                UserDefaults.standard.set(code, forKey: "vn_google_authCode")
                callback(result, nil)
            }

            session.prefersEphemeralWebBrowserSession = false

            // Find the presentation anchor
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                session.presentationContextProvider = window.rootViewController as? ASWebAuthenticationPresentationContextProviding
            }

            session.start()
        }
    }

    // MARK: - Sign Out

    private func handleSignOut(provider: String, callback: @escaping (Any?, String?) -> Void) {
        switch provider {
        case "apple":
            UserDefaults.standard.removeObject(forKey: "vn_apple_userId")
        case "google":
            UserDefaults.standard.removeObject(forKey: "vn_google_authCode")
        default:
            break
        }
        callback(nil, nil)
    }

    // MARK: - Get Current User

    private func handleGetCurrentUser(provider: String, callback: @escaping (Any?, String?) -> Void) {
        switch provider {
        case "apple":
            guard let userId = UserDefaults.standard.string(forKey: "vn_apple_userId") else {
                callback(nil, nil)
                return
            }
            // Verify the credential is still valid
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userId) { state, _ in
                switch state {
                case .authorized:
                    callback(["userId": userId], nil)
                default:
                    UserDefaults.standard.removeObject(forKey: "vn_apple_userId")
                    callback(nil, nil)
                }
            }
        case "google":
            if let code = UserDefaults.standard.string(forKey: "vn_google_authCode") {
                callback(["userId": code], nil)
            } else {
                callback(nil, nil)
            }
        default:
            callback(nil, nil)
        }
    }

    // MARK: - Credential Revocation Observer

    private func observeAppleCredentialRevocation() {
        credentialObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            UserDefaults.standard.removeObject(forKey: "vn_apple_userId")
            self?.bridge?.dispatchGlobalEvent("auth:appleCredentialRevoked", payload: [:])
        }
    }

    deinit {
        if let observer = credentialObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
#endif
