# VErrorBoundary

A component that catches JavaScript errors in its child tree and renders a fallback UI instead of crashing the entire app. Uses `onErrorCaptured` internally and prevents error propagation to parent components.

When `resetKeys` change, the error state is automatically cleared and the normal content is re-rendered.

## Usage

```vue
<VErrorBoundary :onError="(err) => console.warn(err)">
  <template #default>
    <MyComponent />
  </template>
  <template #fallback="{ error, reset }">
    <VText>Something went wrong: {{ error.message }}</VText>
    <VButton :onPress="reset">
      <VText>Try Again</VText>
    </VButton>
  </template>
</VErrorBoundary>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `onError` | `(error: Error, info: string) => void` | -- | Callback invoked when an error is captured. Receives the error and a string with component trace info |
| `resetKeys` | `any[]` | `[]` | Array of values to watch. When any value changes, the error state is automatically cleared |

## Slots

| Slot | Scoped Props | Description |
|------|-------------|-------------|
| `#default` | -- | Normal content rendered when there is no error |
| `#fallback` | `{ error, errorInfo, reset }` | Rendered when an error is caught. `error` is the `Error` object, `errorInfo` is the component trace string, and `reset` is a function that clears the error state |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const retryCount = ref(0)

function handleError(error, info) {
  // Send to your error reporting service
  console.warn('Captured error:', error.message)
  console.warn('Component trace:', info)
}

function retry() {
  retryCount.value++
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 24 }">
    <VText :style="{ fontSize: 20, fontWeight: '700', marginBottom: 16 }">
      Error Boundary Demo
    </VText>

    <VErrorBoundary
      :onError="handleError"
      :resetKeys="[retryCount]"
    >
      <template #default>
        <VView :style="{ padding: 16, backgroundColor: '#f8f8f8', borderRadius: 8 }">
          <VText>This content is protected by the error boundary.</VText>
          <VText :style="{ marginTop: 8, color: '#666' }">
            If any child component throws, the fallback UI will appear.
          </VText>
        </VView>
      </template>

      <template #fallback="{ error, errorInfo, reset }">
        <VView
          :style="{
            padding: 20,
            backgroundColor: '#FFF3F3',
            borderRadius: 8,
            borderWidth: 1,
            borderColor: '#FF3B30',
            gap: 12,
          }"
        >
          <VText :style="{ fontSize: 16, fontWeight: '600', color: '#FF3B30' }">
            Something went wrong
          </VText>

          <VText :style="{ color: '#666', fontSize: 13 }">
            {{ error.message }}
          </VText>

          <VButton
            :style="{
              backgroundColor: '#007AFF',
              padding: 12,
              borderRadius: 8,
              alignItems: 'center',
              marginTop: 4,
            }"
            :onPress="reset"
          >
            <VText :style="{ color: '#fff', fontWeight: '600' }">
              Try Again
            </VText>
          </VButton>
        </VView>
      </template>
    </VErrorBoundary>
  </VView>
</template>
```
