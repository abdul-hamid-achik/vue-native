import AppKit
import VueNativeMacOS

/// Application delegate for the generated macOS host.
///
/// Subclassing `VueNativeAppDelegate` instead of implementing
/// `NSApplicationDelegate` directly is what installs a main menu at launch.
/// A programmatically launched `NSApplication` otherwise gets an *empty* menu
/// bar, and AppKit routes key equivalents through the main menu — so without
/// it Cmd+Q does not quit and Cmd+C/V/X/A never reach a focused `VInput`.
///
/// Override `makeMainMenu()` to replace or extend the standard App / Edit /
/// View / Window / Help menu. `useMenu()` merges into whatever is installed.
class AppDelegate: VueNativeAppDelegate {
    override func createWindowController() -> VueNativeWindowController {
        MainWindowController()
    }
}
