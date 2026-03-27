# KeepAlive

Cache component instances to preserve state and avoid re-rendering when switching between views.

## Overview

`<KeepAlive>` wraps dynamic components and caches their instances when they're switched out. This is useful for:

- Preserving scroll position in lists
- Keeping form input state
- Avoiding expensive re-renders
- Creating tab-based interfaces

## Basic Usage

```vue
<script setup>
import { ref, keepAlive } from 'vue'
import { KeepAlive, VView, VText, VButton } from '@thelacanians/vue-native-runtime'
import HomeTab from './HomeTab.vue'
import ProfileTab from './ProfileTab.vue'
import SettingsTab from './SettingsTab.vue'

const currentTab = ref('home')

const tabs = {
  home: HomeTab,
  profile: ProfileTab,
  settings: SettingsTab,
}
</script>

<template>
  <VView :style="{ flex: 1 }">
    <KeepAlive>
      <component :is="tabs[currentTab]" />
    </KeepAlive>
    
    <VView :style="{ flexDirection: 'row', justifyContent: 'space-around', padding: 8 }">
      <VButton 
        title="Home" 
        :onPress="() => currentTab = 'home'"
        :style="{ opacity: currentTab === 'home' ? 1 : 0.5 }"
      />
      <VButton 
        title="Profile" 
        :onPress="() => currentTab = 'profile'"
        :style="{ opacity: currentTab === 'profile' ? 1 : 0.5 }"
      />
      <VButton 
        title="Settings" 
        :onPress="() => currentTab = 'settings'"
        :style="{ opacity: currentTab === 'settings' ? 1 : 0.5 }"
      />
    </VView>
  </VView>
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `include` | `string \| RegExp \| Array` | -- | Only cache components matching these names |
| `exclude` | `string \| RegExp \| Array` | -- | Never cache components matching these names |
| `max` | `number` | -- | Maximum number of component instances to cache |

## Include / Exclude

Control which components are cached:

### By Name (String)

```vue
<KeepAlive include="HomeTab,ProfileTab">
  <component :is="currentComponent" />
</KeepAlive>
```

### By Pattern (RegExp)

```vue
<KeepAlive :include="/Tab$/">
  <component :is="currentComponent" />
</KeepAlive>
```

### By Array

```vue
<script setup>
const cachedComponents = ['HomeTab', 'ProfileTab', 'SettingsTab']
</script>

<template>
  <KeepAlive :include="cachedComponents">
    <component :is="currentComponent" />
  </KeepAlive>
</template>
```

## Maximum Cache Size

Limit the number of cached instances using LRU (Least Recently Used) eviction:

```vue
<KeepAlive :max="5">
  <component :is="currentComponent" />
</KeepAlive>
```

When the cache exceeds 5 instances, the least recently used component is destroyed.

## Complete Example: Tab Navigation with State Preservation

```vue
<script setup>
import { ref } from 'vue'
import { KeepAlive, VView, VText, VButton, VScrollView } from '@thelacanians/vue-native-runtime'

// Each tab maintains its own scroll position
const HomeTab = {
  template: `
    <VScrollView :style="{ flex: 1, backgroundColor: '#f5f5f5' }">
      <VView v-for="i in 50" :key="i" :style="{ padding: 20, borderBottomWidth: 1, borderBottomColor: '#ddd' }">
        <VText>Home Item {{ i }}</VText>
      </VView>
    </VScrollView>
  `
}

const ProfileTab = {
  template: `
    <VView :style="{ flex: 1, padding: 20 }">
      <VText :style="{ fontSize: 24, fontWeight: 'bold', marginBottom: 16 }">Profile</VText>
      <VText>This tab's state is preserved when you switch away.</VText>
    </VView>
  `
}

const currentTab = ref('home')
</script>

<template>
  <VView :style="{ flex: 1 }">
    <!-- Both tabs stay cached, preserving scroll position -->
    <KeepAlive>
      <component :is="currentTab === 'home' ? HomeTab : ProfileTab" />
    </KeepAlive>
    
    <VView :style="{ flexDirection: 'row', borderTopWidth: 1, borderTopColor: '#ccc' }">
      <VButton 
        title="Home" 
        :onPress="() => currentTab = 'home'"
      />
      <VButton 
        title="Profile" 
        :onPress="() => currentTab = 'profile'"
      />
    </VView>
  </VView>
</template>
```

## Lifecycle Hooks

Components inside `<KeepAlive>` have access to special lifecycle hooks:

```vue
<script setup>
import { onActivated, onDeactivated } from 'vue'

onActivated(() => {
  console.log('Component activated (restored from cache)')
})

onDeactivated(() => {
  console.log('Component deactivated (moved to cache)')
})
</script>
```

| Hook | Description |
|------|-------------|
| `onActivated` | Called when component is restored from cache |
| `onDeactivated` | Called when component is moved to cache |

## Example: Form State Preservation

```vue
<script setup>
import { ref } from 'vue'
import { KeepAlive, VView, VText, VInput, VButton } from '@thelacanians/vue-native-runtime'

const FormTab = {
  template: `
    <VView :style="{ flex: 1, padding: 20 }">
      <VText :style="{ marginBottom: 8 }">Name:</VText>
      <VInput :style="{ borderWidth: 1, borderColor: '#ccc', padding: 8, marginBottom: 16 }" />
      
      <VText :style="{ marginBottom: 8 }">Email:</VText>
      <VInput :style="{ borderWidth: 1, borderColor: '#ccc', padding: 8, marginBottom: 16 }" />
      
      <VButton title="Submit" :onPress="() => {}" />
    </VView>
  `
}

const currentTab = ref('form')
</script>

<template>
  <VView :style="{ flex: 1 }">
    <KeepAlive>
      <component :is="FormTab" v-if="currentTab === 'form'" />
      <VView v-else :style="{ flex: 1, padding: 20 }">
        <VText>Other content</VText>
      </VView>
    </KeepAlive>
    
    <VButton 
      title="Toggle" 
      :onPress="() => currentTab = currentTab === 'form' ? 'other' : 'form'" 
    />
  </VView>
</template>
```

## Platform Notes

All platforms (iOS, Android, macOS) support `KeepAlive` through Vue's built-in caching mechanism. The cached component's view hierarchy is preserved in memory.

## See Also

- [VSuspense](./VSuspense.md) - Handle async component loading
- [VTransition](./VTransition.md) - Animate component transitions
- [Vue KeepAlive Docs](https://vuejs.org/guide/built-ins/keep-alive.html)