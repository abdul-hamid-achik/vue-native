# Error Handling

Robust error handling is essential for production-quality native apps. Vue Native provides two complementary mechanisms: a **global error handler** for app-wide crash reporting, and an **ErrorBoundary component** for localized, recoverable error states in your UI.

## Global Error Handler

Vue's built-in `app.config.errorHandler` captures every unhandled error that occurs during rendering, lifecycle hooks, and event handlers. Set it up once at app initialization:

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'

const app = createApp(App)

app.config.errorHandler = (err, instance, info) => {
  console.error('Global error:', err, info)

  // Send to your crash reporting service
  crashReporter.captureException(err, {
    componentName: instance?.$options?.name,
    lifecycleHook: info,
  })
}

app.mount()
```

The callback receives three arguments:

| Argument   | Type                  | Description                                        |
| ---------- | --------------------- | -------------------------------------------------- |
| `err`      | `Error`               | The thrown error object                             |
| `instance` | `ComponentPublicInstance \| null` | The component instance that raised the error |
| `info`     | `string`              | A Vue-specific string identifying the source (e.g. `"render function"`, `"setup function"`) |

::: tip
The global handler is a safety net, not a recovery mechanism. It cannot render fallback UI — use ErrorBoundary for that.
:::

## ErrorBoundary Component

The `ErrorBoundary` (also exported as `VErrorBoundary`) component catches errors thrown by its child tree and renders fallback UI instead of crashing the entire app.

```ts
import { ErrorBoundary } from '@thelacanians/vue-native-runtime'
// or
import { VErrorBoundary } from '@thelacanians/vue-native-runtime'
```

### Props

| Prop        | Type                                      | Description                                                   |
| ----------- | ----------------------------------------- | ------------------------------------------------------------- |
| `onError`   | `(error: Error, info: string) => void`    | Called when an error is captured. Use for logging or reporting. |
| `resetKeys` | `any[]`                                   | When any value in this array changes, the error state resets automatically. |

### Slots

| Slot        | Slot Props                                    | Description                                  |
| ----------- | --------------------------------------------- | -------------------------------------------- |
| `#default`  | —                                             | Normal content rendered when there is no error. |
| `#fallback` | `{ error: Error, errorInfo: string, reset: () => void }` | Rendered when an error has been caught.       |

### Basic Example

```vue
<script setup>
import {
  ErrorBoundary,
  VView,
  VText,
  VButton,
} from '@thelacanians/vue-native-runtime'

function logError(error, info) {
  console.error('Captured by boundary:', error.message, info)
}
</script>

<template>
  <ErrorBoundary :onError="logError">
    <template #default>
      <DangerousComponent />
    </template>

    <template #fallback="{ error, reset }">
      <VView :style="{ padding: 20, alignItems: 'center' }">
        <VText :style="{ color: 'red', fontSize: 16 }">
          Something went wrong: {{ error.message }}
        </VText>
        <VButton
          :onPress="reset"
          :style="{
            marginTop: 12,
            padding: 10,
            backgroundColor: '#007AFF',
            borderRadius: 8,
          }"
        >
          <VText :style="{ color: '#fff' }">Try Again</VText>
        </VButton>
      </VView>
    </template>
  </ErrorBoundary>
</template>
```

When `DangerousComponent` throws during rendering or in a lifecycle hook, the ErrorBoundary catches it, calls `logError`, and renders the fallback slot. Pressing "Try Again" calls `reset()`, which clears the error and re-renders the default slot.

### Automatic Recovery with resetKeys

The `resetKeys` prop accepts an array of reactive values. When any value in the array changes, the ErrorBoundary automatically resets and re-renders its default content. This is useful when the error was caused by stale data that has since been corrected.

```vue
<script setup>
import { ref } from 'vue'
import {
  ErrorBoundary,
  VView,
  VText,
  VButton,
} from '@thelacanians/vue-native-runtime'

const userId = ref(1)

function logError(error, info) {
  console.error('Profile error:', error.message)
}

function switchUser() {
  // Changing userId will automatically reset the ErrorBoundary
  userId.value = userId.value === 1 ? 2 : 1
}
</script>

<template>
  <VView :style="{ flex: 1 }">
    <ErrorBoundary :onError="logError" :resetKeys="[userId]">
      <template #default>
        <ProfileView :userId="userId" />
      </template>

      <template #fallback="{ error, reset }">
        <VView :style="{ padding: 20, alignItems: 'center' }">
          <VText :style="{ color: 'red' }">{{ error.message }}</VText>
          <VButton
            :onPress="reset"
            :style="{
              marginTop: 12,
              padding: 10,
              backgroundColor: '#007AFF',
              borderRadius: 8,
            }"
          >
            <VText :style="{ color: '#fff' }">Try Again</VText>
          </VButton>
        </VView>
      </template>
    </ErrorBoundary>

    <VButton :onPress="switchUser" :style="{ margin: 20, padding: 10 }">
      <VText>Switch User</VText>
    </VButton>
  </VView>
</template>
```

If `ProfileView` crashes while rendering user 1, the fallback UI appears. When the user taps "Switch User", `userId` changes, the boundary detects the `resetKeys` change, clears the error, and re-renders `ProfileView` with the new user.

### How It Works

Under the hood, `ErrorBoundary` uses Vue's `onErrorCaptured` lifecycle hook:

1. When a descendant component throws, `onErrorCaptured` fires.
2. The boundary stores the error and switches to rendering the `#fallback` slot.
3. It returns `false` from `onErrorCaptured` to **prevent the error from propagating** further up the tree.
4. A `watch` on `resetKeys` compares values — when any key changes, the stored error is cleared and the `#default` slot renders again.
5. The `reset()` function exposed to the fallback slot manually clears the error state.

## Nesting Error Boundaries

Wrap individual sections of your app in separate boundaries so that a failure in one area does not take down the rest:

```vue
<template>
  <VView :style="{ flex: 1 }">
    <ErrorBoundary :onError="logError">
      <template #default>
        <Header />
      </template>
      <template #fallback="{ error }">
        <VText>Header failed to load</VText>
      </template>
    </ErrorBoundary>

    <ErrorBoundary :onError="logError">
      <template #default>
        <MainContent />
      </template>
      <template #fallback="{ error, reset }">
        <VView :style="{ padding: 20 }">
          <VText>{{ error.message }}</VText>
          <VButton :onPress="reset">
            <VText>Reload Content</VText>
          </VButton>
        </VView>
      </template>
    </ErrorBoundary>

    <ErrorBoundary :onError="logError">
      <template #default>
        <Footer />
      </template>
      <template #fallback="{ error }">
        <VText>Footer unavailable</VText>
      </template>
    </ErrorBoundary>
  </VView>
</template>
```

If `MainContent` throws, the header and footer continue to work normally.

## Combining Both Approaches

In a production app, use both mechanisms together:

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'

const app = createApp(App)

// 1. Global handler — catches anything ErrorBoundary misses
app.config.errorHandler = (err, instance, info) => {
  crashReporter.captureException(err, {
    component: instance?.$options?.name,
    hook: info,
  })
}

app.mount()
```

```vue
<!-- App.vue -->
<script setup>
import { ErrorBoundary, VView } from '@thelacanians/vue-native-runtime'

// 2. Boundary-level handler — logs and shows fallback UI
function onBoundaryError(error, info) {
  analytics.track('ui_error', {
    message: error.message,
    info,
  })
}
</script>

<template>
  <ErrorBoundary :onError="onBoundaryError">
    <template #default>
      <RouterView />
    </template>
    <template #fallback="{ error, reset }">
      <FullScreenError :error="error" :onRetry="reset" />
    </template>
  </ErrorBoundary>
</template>
```

## Best Practices

1. **Always set a global error handler** — it is your last line of defense for uncaught errors and the right place to integrate crash reporting services.

2. **Wrap risky subtrees in ErrorBoundary** — components that depend on network data, user-generated content, or third-party libraries are the most likely to throw.

3. **Use `resetKeys` for automatic recovery** — when the data that caused an error is expected to change (e.g. switching routes, refreshing a query), wire up `resetKeys` so the user does not have to manually tap "Retry".

4. **Provide actionable fallback UI** — a reset button, a "go back" button, or a "contact support" link gives users a path forward.

5. **Keep fallback UI simple** — the fallback itself should never throw. Use only basic components (`VView`, `VText`, `VButton`) and avoid complex logic.

6. **Nest boundaries at meaningful boundaries** — one boundary per screen or per major section is a good starting point. Avoid wrapping every single component.

7. **Log context in `onError`** — include the component name, route, and user ID in your error reports to make debugging easier.
