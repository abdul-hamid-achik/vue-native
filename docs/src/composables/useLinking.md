# useLinking

Open URLs in the default browser or another app, and check whether a URL scheme can be handled on the device.

## Usage

```vue
<script setup>
import { useLinking } from '@thelacanians/vue-native-runtime'

const { openURL, canOpenURL } = useLinking()

async function openWebsite() {
  await openURL('https://example.com')
}
</script>
```

## API

```ts
useLinking(): {
  openURL: (url: string) => Promise<void>
  canOpenURL: (url: string) => Promise<boolean>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `openURL` | `(url: string) => Promise<void>` | Open a URL using the system handler. Opens in the default browser for `http`/`https`, or in the associated app for custom URL schemes. |
| `canOpenURL` | `(url: string) => Promise<boolean>` | Check whether a URL can be opened. Returns `true` if a handler is registered for the URL scheme. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UIApplication.shared.open(_:)` and `UIApplication.shared.canOpenURL(_:)`. Custom schemes must be declared in `LSApplicationQueriesSchemes` in Info.plist. |
| Android | Uses `Intent.ACTION_VIEW` with `startActivity`. `canOpenURL` resolves the intent via `PackageManager`. |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useLinking } from '@thelacanians/vue-native-runtime'

const { openURL, canOpenURL } = useLinking()
const canOpenMaps = ref(false)

async function checkMaps() {
  canOpenMaps.value = await canOpenURL('maps://')
}

async function openMaps() {
  await openURL('maps://?q=coffee')
}

async function openBrowser() {
  await openURL('https://vuejs.org')
}

async function sendEmail() {
  await openURL('mailto:hello@example.com?subject=Hello')
}

async function dialPhone() {
  await openURL('tel:+1234567890')
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VButton title="Open Website" :onPress="openBrowser" />
    <VButton title="Send Email" :onPress="sendEmail" />
    <VButton title="Call Phone" :onPress="dialPhone" />

    <VButton title="Check Maps" :onPress="checkMaps" />
    <VText>Can open Maps: {{ canOpenMaps }}</VText>
    <VButton title="Open Maps" :onPress="openMaps" />
  </VView>
</template>
```

## Notes

- On iOS, `canOpenURL` requires the queried URL scheme to be listed in the `LSApplicationQueriesSchemes` array in your app's `Info.plist`. Without this entry, `canOpenURL` returns `false` even if the app is installed.
- Common URL schemes: `https://`, `mailto:`, `tel:`, `sms:`, `maps://`.
- `openURL` will throw if the URL cannot be opened (e.g. invalid URL or no handler available).
