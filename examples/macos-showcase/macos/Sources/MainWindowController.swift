import Foundation
import VueNativeMacOS

/// Hosts the Vue app in the application's main window.
///
/// `NativeBridge.shared` and `JSRuntime.shared` are process-wide singletons, so
/// this is the app's one and only Vue surface — a second window controller
/// would tear the first one's registry down rather than render a second app.
final class MainWindowController: VueNativeWindowController {
    /// Matches the resource copied in by macos/project.yml
    /// (../dist/vue-native-bundle.js -> Contents/Resources/vue-native-bundle.js).
    override var bundleName: String { "vue-native-bundle" }

    #if DEBUG
    /// `vue-native dev --platform macos` serves the rebuilt bundle here.
    /// A production build skips the connection entirely.
    override var devServerURL: URL? { URL(string: "ws://localhost:8174") }
    #endif
}
