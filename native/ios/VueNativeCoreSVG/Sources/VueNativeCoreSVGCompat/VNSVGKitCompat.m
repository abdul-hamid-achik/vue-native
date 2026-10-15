#import "VNSVGKitCompat.h"

/// Logs a failed assertion instead of raising. Installed only while SVGKit primes itself.
@interface VNLoggingAssertionHandler : NSAssertionHandler
@end

@implementation VNLoggingAssertionHandler

- (void)handleFailureInMethod:(SEL)selector
                       object:(id)object
                         file:(NSString *)fileName
                   lineNumber:(NSInteger)line
                  description:(nullable NSString *)format, ... {
    NSLog(@"[VueNative SVG] SVGKit assertion ignored in %@: %@", NSStringFromSelector(selector), format);
}

- (void)handleFailureInFunction:(NSString *)functionName
                           file:(NSString *)fileName
                     lineNumber:(NSInteger)line
                    description:(nullable NSString *)format, ... {
    NSLog(@"[VueNative SVG] SVGKit assertion ignored in %@: %@", functionName, format);
}

@end

void VNPrimeSVGKitDevicePPI(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class svgLength = NSClassFromString(@"SVGLength");
        if (svgLength == Nil) return;
        NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
        id previous = threadDictionary[NSAssertionHandlerKey];
        threadDictionary[NSAssertionHandlerKey] = [VNLoggingAssertionHandler new];
        [svgLength class]; // the first message runs +initialize
        if (previous) {
            threadDictionary[NSAssertionHandlerKey] = previous;
        } else {
            [threadDictionary removeObjectForKey:NSAssertionHandlerKey];
        }
    });
}
