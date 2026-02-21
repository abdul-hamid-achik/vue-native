import UIKit
import VueNativeCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .systemGroupedBackground
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        self.window = window

        JSRuntime.shared.initialize { [weak self] in
            guard self != nil else { return }
            DispatchQueue.main.async {
                NativeBridge.shared.initialize(rootViewController: rootVC)
                JSRuntime.shared.loadBundle(
                    source: .embedded(name: "vue-native-bundle")
                ) { success in
                    if success {
                        print("[VueNativeSettings] JS bundle loaded successfully")
                    } else {
                        print("[VueNativeSettings] ERROR: Failed to load JS bundle")
                    }
                }
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
