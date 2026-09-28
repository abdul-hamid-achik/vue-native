import VueNativeMacOS

/// Bootstrap for the optional SVG component product.
///
/// `<VSVG>` is the only Vue Native component that needs SVGKit, so it ships in
/// its own SPM product instead of `VueNativeMacOS`. An app that never renders an
/// SVG leaves this product out of its dependency list and never resolves SVGKit
/// (or the CocoaLumberjack version pin SVGKit's stale platform floors force on
/// every consumer of it).
///
/// An app that *does* use `<VSVG>` must link this product **and** call
/// ``register()`` once at launch, before the first window is created:
///
/// ```swift
/// import VueNativeMacOSSVG
///
/// class AppDelegate: VueNativeAppDelegate {
///     override func applicationDidFinishLaunching(_ notification: Notification) {
///         VueNativeMacOSSVG.register()
///         super.applicationDidFinishLaunching(notification)
///     }
/// }
/// ```
///
/// Registration is explicit rather than automatic on purpose. A Swift static
/// initializer in a library only runs if something else in the module is
/// referenced first, and the linker drops unreferenced object files from a
/// static library outright — so auto-registration would make `<VSVG>` work or
/// not work depending on link order, with a blank view as the failure mode.
/// Without this call, `VueNativeMacOS` logs an error naming this product and
/// renders nothing for `<VSVG>`.
@MainActor
public enum VueNativeMacOSSVG {

    /// Register `<VSVG>` with the component registry.
    ///
    /// Idempotent, and safe to call before or after `VueNativeMacOS` first uses
    /// its registry: the factory is recorded for the registry's default
    /// registration pass and installed immediately if that pass already ran.
    public static func register() {
        VueNativeWindowController.provideOptionalComponent("VSVG", factory: VSVGFactory())
    }
}
