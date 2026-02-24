package com.vuenative.core

import android.content.Context
import android.view.View

/**
 * Singleton registry mapping component type strings to factories.
 * Also maps views to the factory that created them (via view tag).
 */
class ComponentRegistry private constructor(private val context: Context) {

    companion object {
        @Volatile private var instance: ComponentRegistry? = null

        fun getInstance(context: Context): ComponentRegistry {
            return instance ?: synchronized(this) {
                instance ?: ComponentRegistry(context.applicationContext).also {
                    instance = it
                    it.registerDefaults()
                }
            }
        }
    }

    private val factories = mutableMapOf<String, NativeComponentFactory>()

    private fun registerDefaults() {
        register("VView",              VViewFactory())
        register("VText",              VTextFactory())
        register("VButton",            VButtonFactory())
        register("VInput",             VInputFactory())
        register("VSwitch",            VSwitchFactory())
        register("VActivityIndicator", VActivityIndicatorFactory())
        register("VScrollView",        VScrollViewFactory())
        register("VImage",             VImageFactory())
        register("VKeyboardAvoiding",  VKeyboardAvoidingFactory())
        register("VSafeArea",          VSafeAreaFactory())
        register("VSlider",            VSliderFactory())
        register("VList",              VListFactory())
        register("VModal",             VModalFactory())
        register("VAlertDialog",       VAlertDialogFactory())
        register("VStatusBar",         VStatusBarFactory())
        register("VWebView",           VWebViewFactory())
        register("VProgressBar",       VProgressBarFactory())
        register("VPicker",            VPickerFactory())
        register("VSegmentedControl",  VSegmentedControlFactory())
        register("VActionSheet",       VActionSheetFactory())
        register("VRefreshControl",    VRefreshControlFactory())
        register("VPressable",         VPressableFactory())
        register("VSectionList",       VSectionListFactory())
        register("VCheckbox",          VCheckboxFactory())
        register("VRadio",             VRadioFactory())
        register("VDropdown",          VDropdownFactory())
        register("VVideo",            VVideoFactory())
        register("__ROOT__",           VRootFactory())
    }

    fun register(type: String, factory: NativeComponentFactory) {
        factories[type] = factory
    }

    fun createView(type: String): View? {
        val factory = factories[type] ?: run {
            android.util.Log.w("VueNative", "No factory for type: $type")
            return null
        }
        val view = factory.createView(context)
        view.setTag(TAG_FACTORY, factory)
        return view
    }

    fun factoryForType(type: String): NativeComponentFactory? = factories[type]

    fun factoryForView(view: View): NativeComponentFactory? =
        view.getTag(TAG_FACTORY) as? NativeComponentFactory
}
