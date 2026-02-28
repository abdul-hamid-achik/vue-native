import Foundation

/// Protocol for dispatching events back to JS. Platform-specific bridges conform to this.
public protocol NativeEventDispatcher: AnyObject {
    func dispatchGlobalEvent(_ eventName: String, payload: [String: Any])
}
