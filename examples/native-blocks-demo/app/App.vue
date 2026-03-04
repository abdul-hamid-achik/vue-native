<template>
  <VView :style="styles.container">
    <VView :style="styles.header">
      <VText :style="styles.title">Native Blocks Demo</VText>
      <VText :style="styles.subtitle">Vue Native Code Generation</VText>
    </VView>

    <VScrollView
      :style="styles.scroll}>
      <!-- Example 1: Custom Haptics -->
      <VView :style="styles.section}
    >
      <VText
        :style="styles.sectionTitle}>1. Custom Haptics</VText>
        <VText :style="styles.description}
      >
        Native haptic feedback with custom patterns
      </VText>
      <VButton
        title="Light Vibrate"
        :style="styles.button}
        />
        <VButton
          title="
        Heavy@press="handleLightVibrate" Vibrate"
        :style="styles.button}
        />
        <VButton
          title="
        Pattern"@press="handleHeavyVibrate"
        :style="styles.button}
        />
      </VView>

      <!-- Example 2: Image Processor -->
      <VView :style="
        styles.section}@press="handlePattern"
      >
        <VText
          :style="styles.sectionTitle}>2. Image Processor</VText>
        <VText :style="styles.description}
        >
          Native image filters and transformations
        </VText>
        <VButton
          title="Apply Grayscale"
          :style="styles.button}
        />
        <VButton
          title="
          Apply@press="handleGrayscale" Blur"
          :style="styles.button}
        />
      </VView>

      <!-- Example 3: Device Info -->
      <VView :style="
          styles.section}@press="handleBlur"
        >
          <VText
            :style="styles.sectionTitle}>3. Device Info</VText>
        <VText :style="styles.description}
          >
            Native device information access
          </VText>
          <VButton
            title="Get Battery Level"
            :style="styles.button}
        />
        <VButton
          title="
            Get@press="handleBattery" Device Model"
            :style="styles.button}
        />
        <VText v-if="
            deviceInfo"@press="handleDeviceModel" :style="styles.result}>
          {{ deviceInfo }}
        </VText>
      </VView>
    </VScrollView>
  </VView>
</template>

<script setup lang="ts"
          >
            import { ref } from 'vue'
            // These will be auto-generated from <native>
              blocks
              // import { useCustomHaptics } from './generated/useCustomHaptics'
              // import { useImageProcessor } from './generated/useImageProcessor'
              // import { useDeviceInfo } from './generated/useDeviceInfo'

              const deviceInfo = ref('')

              // const { vibrate, pattern } = useCustomHaptics()
              // const { applyFilter } = useImageProcessor()
              // const { getBatteryLevel, getDeviceModel } = useDeviceInfo()

              async function handleLightVibrate() {
              // await vibrate('light')
              console.log('Light vibrate triggered')
              }

              async function handleHeavyVibrate() {
              // await vibrate('heavy')
              console.log('Heavy vibrate triggered')
              }

              async function handlePattern() {
              // await pattern([100, 50, 100, 50, 200])
              console.log('Pattern vibrate triggered')
              }

              async function handleGrayscale() {
              // await applyFilter('grayscale')
              console.log('Grayscale filter applied')
              }

              async function handleBlur() {
              // await applyFilter('blur', { radius: 5 })
              console.log('Blur filter applied')
              }

              async function handleBattery() {
              // const level = await getBatteryLevel()
              // deviceInfo.value = `Battery: ${level * 100}%`
              deviceInfo.value = 'Battery: 85%'
              }

              async function handleDeviceModel() {
              // const model = await getDeviceModel()
              // deviceInfo.value = `Device: ${model}`
              deviceInfo.value = 'Device: iPhone 15 Pro'
              }
              </script>

              <native platform="ios">
                // CustomHapticsModule - Advanced haptic feedback patterns
                class CustomHapticsModule: NativeModule {
                var moduleName: String { "CustomHaptics" }

                func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
                switch method {
                case "vibrate":
                let style = args[0] as? String ?? "medium"
                vibrate(style: style)
                callback(nil, nil)

                case "pattern":
                let pattern = args[0] as? [Int] ?? []
                playPattern(pattern)
                callback(nil, nil)

                default:
                callback(nil, "Unknown method: \(method)")
                }
                }

                private func vibrate(style: String) {
                let generator: UIImpactFeedbackGenerator
                switch style {
                case "light":
                generator = UIImpactFeedbackGenerator(style: .light)
                case "medium":
                generator = UIImpactFeedbackGenerator(style: .medium)
                case "heavy":
                generator = UIImpactFeedbackGenerator(style: .heavy)
                default:
                generator = UIImpactFeedbackGenerator(style: .medium)
                }
                generator.prepare()
                generator.impactOccurred()
                }

                private func playPattern(_ pattern: [Int]) {
                DispatchQueue.global().async {
                for (index, duration) in pattern.enumerated() {
                usleep(UInt32(duration * 1000))
                if index % 2 == 0 {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
                }
                }
                }
                }
                }
              </native>

              <native platform="android">
                // CustomHapticsModule - Advanced haptic feedback patterns
                class CustomHapticsModule: NativeModule {
                override val moduleName: String = "CustomHaptics"

                override fun invoke(method: String, args: List<Any>
                  , callback: (Any?, String?) -> Unit) {
                  when (method) {
                  "vibrate" -> {
                  val style = args[0] as? String ?: "medium"
                  vibrate(style)
                  callback(null, null)
                  }
                  "pattern" -> {
                  val pattern = args[0] as? List<Int>
                    ?: emptyList()
                    playPattern(pattern)
                    callback(null, null)
                    }
                    else -> callback(null, "Unknown method: $method")
                    }
                    }

                    private fun vibrate(style: String) {
                    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    val duration = when (style) {
                    "light" -> 10L
                    "medium" -> 20L
                    "heavy" -> 40L
                    else -> 20L
                    }
                    vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
                    }

                    private fun playPattern(pattern: List<Int>
                      ) {
                      Thread {
                      val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                      pattern.forEachIndexed { index, duration ->
                      Thread.sleep(duration.toLong())
                      if (index % 2 == 0) {
                      vibrator.vibrate(VibrationEffect.createOneShot(20, VibrationEffect.DEFAULT_AMPLITUDE))
                      }
                      }
                      }.start()
                      }
                      }
                    </int>
                  </int>
                </any>
              </native>

              <native platform="ios">
                // ImageProcessorModule - Native image filters using Core Image
                class ImageProcessorModule: NativeModule {
                var moduleName: String { "ImageProcessor" }

                private var lastImage: CIImage?

                func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
                switch method {
                case "applyFilter":
                let filterName = args[0] as! String
                let options = args[1] as? [String: Any] ?? [:]
                let result = applyFilter(filterName, options: options)
                callback(result, nil)

                default:
                callback(nil, "Unknown method: \(method)")
                }
                }

                private func applyFilter(_ name: String, options: [String: Any]) -> String? {
                // Create sample image if none exists
                let image = lastImage ?? CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
                .cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))

                guard let filter = CIFilter(name: name) else {
                return nil
                }

                filter.setValue(image, forKey: kCIInputImageKey)

                // Apply options
                for (key, value) in options {
                filter.setValue(value, forKey: key)
                }

                guard let output = filter.outputImage else {
                return nil
                }

                lastImage = output
                return "Filter applied successfully"
                }
                }
              </native>

              <native platform="android">
                // ImageProcessorModule - Native image filters using Bitmap
                class ImageProcessorModule: NativeModule {
                override val moduleName: String = "ImageProcessor"

                private var lastImage: android.graphics.Bitmap?

                override fun invoke(method: String, args: List<Any>
                  , callback: (Any?, String?) -> Unit) {
                  when (method) {
                  "applyFilter" -> {
                  val filterName = args[0] as String
                  val options = args[1] as? Map<String, Any>
                    ?: emptyMap()
                    val result = applyFilter(filterName, options)
                    callback(result, null)
                    }
                    else -> callback(null, "Unknown method: $method")
                    }
                    }

                    private fun applyFilter(name: String, options: Map<String, Any>
                      ): String? {
                      // Create sample bitmap if none exists
                      val bitmap = lastImage ?: android.graphics.Bitmap.createBitmap(100, 100, android.graphics.Bitmap.Config.ARGB_8888)

                      return when (name) {
                      "grayscale" -> {
                      val matrix = android.graphics.ColorMatrix()
                      matrix.setSaturation(0f)
                      val paint = android.graphics.Paint().apply {
                      colorFilter = android.graphics.ColorMatrixColorFilter(matrix)
                      }
                      val canvas = android.graphics.Canvas(bitmap)
                      canvas.drawBitmap(bitmap, 0f, 0f, paint)
                      "Grayscale applied"
                      }
                      "blur" -> {
                      val radius = options["radius"] as? Float ?: 5f
                      // Use RenderScript or modern alternative for blur
                      "Blur applied with radius $radius"
                      }
                      else -> null
                      }
                      }
                      }
                    </string,>
                  </string,>
                </any>
              </native>

              <native platform="ios">
                // DeviceInfoModule - Extended device information
                class DeviceInfoModule: NativeModule {
                var moduleName: String { "DeviceInfo" }

                func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
                switch method {
                case "getBatteryLevel":
                let level = UIDevice.current.batteryLevel
                if level == -1 {
                callback(nil, "Battery monitoring not enabled")
                } else {
                callback(level, nil)
                }

                case "getDeviceModel":
                let model = getDeviceModel()
                callback(model, nil)

                default:
                callback(nil, "Unknown method: \(method)")
                }
                }

                private func getDeviceModel() -> String {
                var systemInfo = utsname()
                uname(&systemInfo)
                let machineMirror = Mirror(reflecting: systemInfo.machine)
                let identifier = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
                }

                // Map identifier to model name
                switch identifier {
                case "iPhone16,1": return "iPhone 15 Pro"
                case "iPhone16,2": return "iPhone 15 Pro Max"
                case "iPhone15,3": return "iPhone 14 Pro Max"
                default: return "iPhone (\(identifier))"
                }
                }
                }
              </native>

              <native platform="android">
                // DeviceInfoModule - Extended device information
                class DeviceInfoModule: NativeModule {
                override val moduleName: String = "DeviceInfo"

                override fun invoke(method: String, args: List<Any>
                  , callback: (Any?, String?) -> Unit) {
                  when (method) {
                  "getBatteryLevel" -> {
                  val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? android.os.BatteryManager
                  val level = batteryManager?.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
                  callback(level / 100.0, null)
                  }
                  "getDeviceModel" -> {
                  val model = android.os.Build.MODEL
                  callback(model, null)
                  }
                  else -> callback(null, "Unknown method: $method")
                  }
                  }
                  }
                </any>
              </native>

              <style>
                const styles = {
                container: {
                flex: 1,
                backgroundColor: '#f5f5f5',
                },
                header: {
                padding: 24,
                paddingTop: 60,
                backgroundColor: '#007AFF',
                },
                title: {
                fontSize: 32,
                fontWeight: 'bold',
                color: '#ffffff',
                },
                subtitle: {
                fontSize: 16,
                color: '#ffffff',
                opacity: 0.8,
                marginTop: 4,
                },
                scroll: {
                flex: 1,
                },
                section: {
                backgroundColor: '#ffffff',
                padding: 20,
                marginVertical: 8,
                marginHorizontal: 16,
                borderRadius: 12,
                },
                sectionTitle: {
                fontSize: 20,
                fontWeight: '600',
                color: '#000000',
                marginBottom: 8,
                },
                description: {
                fontSize: 14,
                color: '#666666',
                marginBottom: 16,
                },
                button: {
                marginBottom: 8,
                },
                result: {
                fontSize: 14,
                color: '#007AFF',
                marginTop: 12,
                fontWeight: '500',
                },
                }
              </style>
            </native>
          </vbutton>
        </vbutton>
      </vbutton>
    </vscrollview>
  </vview>
</template>
