import AppKit

// MARK: - Safe array subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Main window helper

extension NSApplication {
    /// The main window, or the first visible window.
    static var vn_mainWindow: NSWindow? {
        NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible }
    }

    /// Returns the main window's content view controller.
    static var vn_contentViewController: NSViewController? {
        vn_mainWindow?.contentViewController
    }
}
