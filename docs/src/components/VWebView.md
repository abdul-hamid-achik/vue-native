# VWebView

An embedded web view component for displaying web content. Maps to `WKWebView` on iOS and `android.webkit.WebView` on Android.

## Usage

```vue
<VWebView
  :source="{ uri: 'https://example.com' }"
  :style="{ flex: 1 }"
  @load="onLoad"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `source` | `WebViewSource` | **required** | The content to display (URL or inline HTML) |
| `javaScriptEnabled` | `boolean` | `true` | Enable JavaScript execution in the web view |
| `style` | `StyleProp` | — | Layout + appearance styles |

### WebViewSource

```ts
interface WebViewSource {
  uri?: string   // URL to load
  html?: string  // Inline HTML string to render
}
```

Provide either `uri` or `html`, not both.

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@load` | `{ url: string }` | Fired when the page finishes loading |
| `@error` | `{ message: string }` | Fired when navigation fails |
| `@message` | `{ data: any }` | Fired when the web page posts a message via `window.webkit.messageHandlers.vueNative.postMessage(data)` |

## Example

### Loading a URL

```vue
<script setup>
import { ref } from 'vue'

const loading = ref(true)

function onLoad(e) {
  loading.value = false
  console.log('Loaded:', e.url)
}

function onError(e) {
  loading.value = false
  console.log('Error:', e.message)
}
</script>

<template>
  <VView :style="styles.container">
    <VActivityIndicator v-if="loading" :style="styles.loader" />
    <VWebView
      :source="{ uri: 'https://vuejs.org' }"
      :style="styles.webview"
      @load="onLoad"
      @error="onError"
    />
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
  },
  webview: {
    flex: 1,
  },
  loader: {
    position: 'absolute',
    top: 100,
    alignSelf: 'center',
  },
})
</script>
```

### Loading inline HTML

```vue
<template>
  <VWebView
    :source="{ html: '<h1>Hello from Vue Native!</h1><p>This is inline HTML.</p>' }"
    :style="{ flex: 1 }"
  />
</template>
```

### Receiving messages from web content

The web page can send messages to your Vue Native app using the `vueNative` message handler:

```js
// Inside the web page's JavaScript
window.webkit.messageHandlers.vueNative.postMessage({ type: 'ready', count: 42 })
```

```vue
<template>
  <VWebView
    :source="{ uri: 'https://example.com' }"
    :style="{ flex: 1 }"
    @message="onMessage"
  />
</template>

<script setup>
function onMessage(e) {
  console.log('Received from web:', e.data)
}
</script>
```

## Notes

- `VWebView` should typically be given `flex: 1` or explicit dimensions, as it has no intrinsic content size.
- The `javaScriptEnabled` prop is `true` by default. On iOS, WKWebView has JavaScript enabled at initialization and cannot be toggled at runtime.
- On iOS, the `@message` event uses `WKScriptMessageHandler` with the channel name `"vueNative"`.
