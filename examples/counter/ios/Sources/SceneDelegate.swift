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

        // 1. Create the window and root view controller
        let window = UIWindow(windowScene: windowScene)
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .systemBackground
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        self.window = window

        // 2. Initialize the JavaScript runtime
        //    This creates the JSContext and registers polyfills (console, setTimeout,
        //    requestAnimationFrame, performance.now, queueMicrotask).
        JSRuntime.shared.initialize { [weak self] in
            guard self != nil else { return }

            // 3. Initialize the native bridge on the main thread.
            //    This registers __VN_flushOperations on the JSContext so that
            //    the JS renderer can send batched UI operations to UIKit.
            DispatchQueue.main.async {
                NativeBridge.shared.initialize(rootViewController: rootVC)

                // 4. Load the bundled JavaScript application.
                //    The file vue-native-bundle.js is copied into the app's
                //    resource bundle by the build system (see project.yml).
                //    JSRuntime searches Bundle.main for the resource.
                JSRuntime.shared.loadBundle(
                    source: .embedded(name: "vue-native-bundle")
                ) { success in
                    if success {
                        print("[VueNativeCounter] JS bundle loaded successfully")
                    } else {
                        print("[VueNativeCounter] ERROR: Failed to load JS bundle")
                    }
                }
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the scene is released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene moves from inactive to active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene moves from active to inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from background to foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from foreground to background.
    }
}
