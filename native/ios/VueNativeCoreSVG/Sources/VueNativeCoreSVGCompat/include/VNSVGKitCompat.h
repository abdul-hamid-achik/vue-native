#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// SVGKit's `SVGLength` looks up the device's pixels per inch in `+initialize`, from a
/// hard-coded table of device models. Unknown models (every Apple Silicon simulator, which
/// reports `arm64`, and iPhones newer than the table) hit `NSAssert(FALSE, …)`; in Debug
/// builds that raised inside class initialization and crashed the first SVG that used a
/// length (any `stroke-width`).
///
/// Runs that initialization once with an assertion handler that logs instead of raising.
/// SVGKit then keeps its fallback value, which only matters for physical units (cm/mm/in).
void VNPrimeSVGKitDevicePPI(void);

NS_ASSUME_NONNULL_END
