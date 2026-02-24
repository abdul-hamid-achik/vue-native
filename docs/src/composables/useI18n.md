# useI18n

Locale detection and RTL (right-to-left) layout support. Reads the device locale on mount and determines if the current language uses an RTL script.

## Usage

```vue
<script setup>
import { useI18n } from '@thelacanians/vue-native-runtime'

const { locale, isRTL } = useI18n()
</script>

<template>
  <VView :style="{ flexDirection: isRTL ? 'row-reverse' : 'row' }">
    <VText>Locale: {{ locale }}</VText>
  </VView>
</template>
```

## API

```ts
useI18n(): {
  locale: Ref<string>
  isRTL: Ref<boolean>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `locale` | `Ref<string>` | The device locale string (e.g., `'en'`, `'ar'`, `'ja'`). Defaults to `'en'` until loaded. |
| `isRTL` | `Ref<boolean>` | `true` if the locale uses a right-to-left script (Arabic, Hebrew, Farsi, Urdu). |

## RTL Languages

The following language prefixes are detected as RTL:
- `ar` -- Arabic
- `he` -- Hebrew
- `fa` -- Farsi/Persian
- `ur` -- Urdu

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Reads locale from `DeviceInfo` native module. |
| Android | Reads locale from `DeviceInfo` native module. |

## Example

```vue
<script setup>
import { computed } from '@thelacanians/vue-native-runtime'
import { useI18n } from '@thelacanians/vue-native-runtime'

const { locale, isRTL } = useI18n()

const greeting = computed(() => {
  if (locale.value.startsWith('ar')) return 'مرحبا'
  if (locale.value.startsWith('ja')) return 'こんにちは'
  return 'Hello'
})
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 24, textAlign: isRTL ? 'right' : 'left' }">
      {{ greeting }}
    </VText>
    <VText :style="{ color: '#666', marginTop: 8 }">
      Locale: {{ locale }}, RTL: {{ isRTL }}
    </VText>
  </VView>
</template>
```

## Notes

- Locale is fetched asynchronously on `onMounted` via the `DeviceInfo` native module. Both refs default to their fallback values (`'en'` / `false`) until the native response arrives.
- The RTL detection is based on language prefix only. It does not account for locale-specific overrides.
- Use `isRTL` to flip layout direction (e.g., `flexDirection: 'row-reverse'`) for RTL language support.
