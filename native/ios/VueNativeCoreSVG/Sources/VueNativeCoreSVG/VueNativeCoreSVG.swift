#if canImport(UIKit)
import VueNativeCore

/// Bootstrap for the optional SVG component product.
///
/// `<VSVG>` is the only Vue Native component that needs SVGKit, so it ships in
/// its own SPM product instead of `VueNativeCore`. An app that never renders an
/// SVG leaves this product out of its dependency list and never resolves SVGKit
/// (or the CocoaLumberjack version pin SVGKit's stale platform floors force on
/// every consumer of it).
///
/// An app that *does* use `<VSVG>` must link this product **and** call
/// ``register()`` once at launch, before the first view is created:
///
/// ```swift
/// import VueNativeCoreSVG
///
/// func application(
///     _ application: UIApplication,
///     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
/// ) -> Bool {
///     VueNativeCoreSVG.register()
///     return true
/// }
/// ```
///
/// Registration is explicit rather than automatic on purpose. A Swift static
/// initializer in a library only runs if something else in the module is
/// referenced first, and the linker drops unreferenced object files from a
/// static library outright — so auto-registration would make `<VSVG>` work or
/// not work depending on link order, with a blank view as the failure mode.
/// Without this call, `VueNativeCore` logs an error naming this product and
/// renders nothing for `<VSVG>`.
@MainActor
public enum VueNativeCoreSVG {

    /// Register `<VSVG>` with the component registry.
    ///
    /// Idempotent, and safe to call before or after `VueNativeCore` first uses
    /// its registry: the factory is recorded for the registry's default
    /// registration pass and installed immediately if that pass already ran.
    public static func register() {
        VueNativeViewController.provideOptionalComponent("VSVG", factory: VSVGFactory())
    }
}
#endif
