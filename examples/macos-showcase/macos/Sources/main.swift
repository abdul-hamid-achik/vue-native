import AppKit

// Retained for the process lifetime: NSApplication.delegate is weak, and
// top-level bindings in main.swift live as long as the executable does.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate

// Nothing reads an activation policy out of a nib here, so state it: the app
// owns a Dock item and should come to the front when `vue-native run macos`
// launches it with `open`.
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
