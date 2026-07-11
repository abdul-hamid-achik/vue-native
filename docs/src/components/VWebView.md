# VWebView

An embedded web view component for displaying web content. Maps to `WKWebView` on iOS and macOS, and `android.webkit.WebView` on Android.

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
| `@error` | `{ message: string, url?: string }` | Fired when navigation fails; Android includes the failing URL |
| `@message` | `{ data: any }` | Fired when the web page posts a message through the platform's `vueNative` bridge |

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

The web page can send messages to your Vue Native app using the platform's `vueNative` message handler.

On iOS and macOS, use WebKit's script message handler. The payload may be any value supported by `WKScriptMessage`:

```js
window.webkit.messageHandlers.vueNative.postMessage({ type: 'ready', count: 42 })
```

On Android, use the injected `window.vueNative` interface. Android receives a string, so serialize structured data explicitly:

```js
window.vueNative.postMessage(JSON.stringify({ type: 'ready', count: 42 }))
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
  const data = typeof e.data === 'string' ? JSON.parse(e.data) : e.data
  console.log('Received from web:', data)
}
</script>
```

## Notes

- `VWebView` should typically be given `flex: 1` or explicit dimensions, as it has no intrinsic content size.
- The `javaScriptEnabled` prop is `true` by default and can be toggled at runtime. On iOS and macOS, changes use `WKWebpagePreferences` and apply to future navigations; they do not reload the current page.
- On iOS and macOS, the `@message` event uses `WKScriptMessageHandler` with the channel name `"vueNative"`.
- Android blocks mixed HTTP content inside HTTPS pages by default.
