#if canImport(UIKit)
import Foundation
import VueNativeShared

/// Extension to register all built-in iOS modules.
/// The shared NativeModuleRegistry has no `registerDefaults()` — each platform provides its own.
@MainActor
extension NativeModuleRegistry {
    func registerDefaults() {
        let bridge = NativeBridge.shared

        // iOS-only modules
        register(HapticsModule())
        register(ClipboardModule())
        register(DeviceInfoModule())
        register(KeyboardModule())
        register(AnimationModule())
        register(AppStateModule(bridge: bridge))
        register(LinkingModule())
        register(ShareModule())
        register(PermissionsModule())
        register(CameraModule())
        register(NotificationsModule(bridge: bridge))
        register(BiometryModule())
        register(SensorsModule(bridge: bridge))
        if #available(iOS 13.0, *) {
            register(BackgroundTaskModule(bridge: bridge))
        }
        register(OTAModule(bridge: bridge))
        if #available(iOS 15.0, *) {
            register(IAPModule(bridge: bridge))
        }
        register(SocialAuthModule(bridge: bridge))
        register(BluetoothModule(bridge: bridge))
        register(CalendarModule())
        register(ContactsModule())

        // Shared modules (from VueNativeShared)
        register(AsyncStorageModule())
        register(DatabaseModule())
        register(SecureStorageModule())
        register(FileSystemModule())
        register(NetworkModule(eventDispatcher: bridge))
        register(WebSocketModule(eventDispatcher: bridge))
        register(AudioModule(eventDispatcher: bridge))
        register(GeolocationModule(eventDispatcher: bridge))
        register(PerformanceModule(eventDispatcher: bridge))

        // Register generated modules from <native> blocks
        registerGeneratedModules()
    }
}
#endif
