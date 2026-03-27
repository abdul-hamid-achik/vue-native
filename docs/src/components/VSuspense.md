# VSuspense

Handle asynchronous component loading with loading states and error boundaries.

## Overview

`<VSuspense>` wraps async components and shows a fallback while they're loading. Combined with `defineAsyncComponent`, it enables:

- Code splitting
- Lazy loading components
- Showing loading indicators during data fetching
- Graceful error handling

## Basic Usage

```vue
<script setup>
import { defineAsyncComponent } from '@thelacanians/vue-native-runtime'
import { VSuspense, VView, VText, VActivityIndicator } from '@thelacanians/vue-native-runtime'

// Lazy load a heavy component
const HeavyChart = defineAsyncComponent(() => 
  import('./HeavyChart.vue')
)
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VSuspense>
      <template #default>
        <HeavyChart :data="chartData" />
      </template>
      
      <template #fallback>
        <VView :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
          <VActivityIndicator size="large" />
          <VText :style="{ marginTop: 16 }">Loading chart...</VText>
        </VView>
      </template>
    </VSuspense>
  </VView>
</template>
```

## defineAsyncComponent

Define asynchronously loaded components:

### Basic

```ts
import { defineAsyncComponent } from '@thelacanians/vue-native-runtime'

const AsyncModal = defineAsyncComponent(() => 
  import('./Modal.vue')
)
```

### With Options

```ts
const AsyncModal = defineAsyncComponent({
  loader: () => import('./Modal.vue'),
  loadingComponent: LoadingSpinner,
  errorComponent: ErrorView,
  delay: 200,        // Show loading after 200ms
  timeout: 10000,    // Error after 10 seconds
  onError(error, retry, fail) {
    console.error('Failed to load:', error)
    // retry() to retry loading
    // fail() to show error component
  }
})
```

## VSuspense Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `timeout` | `number` | -- | Timeout in ms before showing error |
| `suspensible` | `boolean` | `false` | Whether to participate in parent suspense |

## Slots

| Slot | Description |
|------|-------------|
| `default` | Content to show when async components are loaded |
| `fallback` | Content to show while async components are loading |

## Complete Example: Dashboard with Multiple Async Components

```vue
<script setup>
import { ref, defineAsyncComponent } from 'vue'
import { VSuspense, VView, VText, VActivityIndicator, VScrollView, VButton } from '@thelacanians/vue-native-runtime'

// Lazy load dashboard widgets
const StatsWidget = defineAsyncComponent(() => import('./StatsWidget.vue'))
const ChartWidget = defineAsyncComponent(() => import('./ChartWidget.vue'))
const RecentActivity = defineAsyncComponent(() => import('./RecentActivity.vue'))

// Custom loading component
const LoadingWidget = {
  props: ['title'],
  template: `
    <VView :style="{ padding: 16, backgroundColor: '#f0f0f0', borderRadius: 8, marginBottom: 12 }">
      <VText :style="{ fontWeight: '600', marginBottom: 8 }">{{ title }}</VText>
      <VActivityIndicator size="small" />
    </VView>
  `
}

// Error component
const ErrorWidget = {
  props: ['title', 'error'],
  template: `
    <VView :style="{ padding: 16, backgroundColor: '#ffebee', borderRadius: 8, marginBottom: 12 }">
      <VText :style="{ fontWeight: '600', color: '#c62828' }">{{ title }}</VText>
      <VText :style="{ color: '#c62828', marginTop: 4 }">Failed to load</VText>
    </VView>
  `
}
</script>

<template>
  <VScrollView :style="{ flex: 1, backgroundColor: '#fff' }">
    <VView :style="{ padding: 16 }">
      <VText :style="{ fontSize: 24, fontWeight: 'bold', marginBottom: 16 }">Dashboard</VText>
      
      <!-- All async components share the same suspense boundary -->
      <VSuspense>
        <template #default>
          <StatsWidget />
          <ChartWidget />
          <RecentActivity />
        </template>
        
        <template #fallback>
          <!-- Show individual loading states -->
          <LoadingWidget title="Statistics" />
          <LoadingWidget title="Chart" />
          <LoadingWidget title="Recent Activity" />
        </template>
      </VSuspense>
    </VView>
  </VScrollView>
</template>
```

## Example: Nested Suspense

Use nested suspense to have independent loading states:

```vue
<script setup>
import { defineAsyncComponent } from '@thelacanians/vue-native-runtime'
import { VSuspense, VView, VActivityIndicator } from '@thelacanians/vue-native-runtime'

const Header = defineAsyncComponent(() => import('./Header.vue'))
const Sidebar = defineAsyncComponent(() => import('./Sidebar.vue'))
const MainContent = defineAsyncComponent(() => import('./MainContent.vue'))
</script>

<template>
  <VView :style="{ flex: 1 }">
    <!-- Header loads independently -->
    <VSuspense>
      <template #default>
        <Header />
      </template>
      <template #fallback>
        <VView :style="{ height: 60, backgroundColor: '#f0f0f0' }">
          <VActivityIndicator />
        </VView>
      </template>
    </VSuspense>
    
    <VView :style="{ flex: 1, flexDirection: 'row' }">
      <!-- Sidebar loads independently -->
      <VSuspense>
        <template #default>
          <Sidebar />
        </template>
        <template #fallback>
          <VView :style="{ width: 200, backgroundColor: '#f5f5f5' }">
            <VActivityIndicator />
          </VView>
        </template>
      </VSuspense>
      
      <!-- Main content loads independently -->
      <VSuspense>
        <template #default>
          <MainContent />
        </template>
        <template #fallback>
          <VView :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
            <VActivityIndicator size="large" />
          </VView>
        </template>
      </VSuspense>
    </VView>
  </VView>
</template>
```

## Async Setup with async/await

Use `async setup()` in components for data fetching:

```vue
<!-- UserProfile.vue -->
<script setup>
import { ref } from 'vue'
import { useHttp } from '@thelacanians/vue-native-runtime'
import { VView, VText, VImage } from '@thelacanians/vue-native-runtime'

const props = defineProps(['userId'])

// This will be awaited by Suspense
const user = ref(null)

async function loadUser() {
  const { data } = await useHttp(`https://api.example.com/users/${props.userId}`)
  user.value = data
}

// Called during suspense wait
await loadUser()
</script>

<template>
  <VView :style="{ padding: 16 }">
    <VImage 
      :source="{ uri: user.avatar }" 
      :style="{ width: 80, height: 80, borderRadius: 40 }" 
    />
    <VText :style="{ fontSize: 20, fontWeight: 'bold' }">{{ user.name }}</VText>
    <VText :style="{ color: '#666' }">{{ user.email }}</VText>
  </VView>
</template>
```

```vue
<!-- Parent.vue -->
<script setup>
import { VSuspense, VView, VActivityIndicator, VText } from '@thelacanians/vue-native-runtime'
import UserProfile from './UserProfile.vue'
</script>

<template>
  <VSuspense>
    <template #default>
      <UserProfile :userId="123" />
    </template>
    <template #fallback>
      <VView :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
        <VActivityIndicator size="large" />
        <VText>Loading profile...</VText>
      </VView>
    </template>
  </VSuspense>
</template>
```

## Error Handling

Combine with `VErrorBoundary` for complete error handling:

```vue
<script setup>
import { VSuspense, VErrorBoundary, VView, VText, VButton, VActivityIndicator } from '@thelacanians/vue-native-runtime'
import AsyncComponent from './AsyncComponent.vue'
</script>

<template>
  <VErrorBoundary>
    <template #default="{ error, resetError }">
      <VView v-if="error" :style="{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 }">
        <VText :style="{ color: '#c62828', marginBottom: 16 }">{{ error.message }}</VText>
        <VButton title="Retry" :onPress="resetError" />
      </VView>
      
      <VSuspense v-else>
        <template #default>
          <AsyncComponent />
        </template>
        <template #fallback>
          <VView :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
            <VActivityIndicator />
          </VView>
        </template>
      </VSuspense>
    </template>
  </VErrorBoundary>
</template>
```

## Platform Notes

All platforms support `VSuspense` through Vue's built-in async component handling. The async loading happens in JavaScript before native components are created.

## See Also

- [KeepAlive](./KeepAlive.md) - Cache component instances
- [VTransition](./VTransition.md) - Animate components
- [VErrorBoundary](./VErrorBoundary.md) - Handle component errors