# Navigation Components

Vue Native provides tab bar and drawer navigation components for common navigation patterns.

## VTabBar

Tab bar navigation for switching between views.

### Basic Usage

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const activeTab = ref('home')

const tabs = [
  { id: 'home', label: 'Home', icon: '🏠' },
  { id: 'search', label: 'Search', icon: '🔍' },
  { id: 'profile', label: 'Profile', icon: '👤' },
]

function handleTabChange(tabId) {
  console.log('Selected tab:', tabId)
}
</script>

<template>
  <VView style="{ flex: 1 }">
    <!-- Content based on active tab -->
    <HomeView v-if="activeTab === 'home'" />
    <SearchView v-else-if="activeTab === 'search'" />
    <ProfileView v-else-if="activeTab === 'profile'" />
    
    <!-- Tab bar at bottom -->
    <VTabBar
      :tabs="tabs"
      :activeTab="activeTab"
      @change="handleTabChange"
    />
  </VView>
</template>
```

### With Badges

```vue
<script setup>
const tabs = [
  { id: 'home', label: 'Home', icon: '🏠' },
  { id: 'notifications', label: 'Alerts', icon: '🔔', badge: 3 },
  { id: 'messages', label: 'Messages', icon: '💬', badge: '99+' },
]
</script>

<template>
  <VTabBar :tabs="tabs" :activeTab="activeTab" />
</template>
```

### Top Position

```vue
<VTabBar
  :tabs="tabs"
  :activeTab="activeTab"
  position="top"
/>
```

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `tabs` | TabConfig[] | - | Array of tab configurations |
| `activeTab` | string | - | Currently active tab ID |
| `position` | 'top' \| 'bottom' | 'bottom' | Tab bar position |

### TabConfig

```typescript
interface TabConfig {
  id: string          // Unique tab identifier
  label: string       // Tab label text
  icon?: string       // Tab icon (emoji or icon name)
  badge?: number | string // Optional badge count
}
```

### Events

| Event | Params | Description |
|-------|--------|-------------|
| `change` | `tabId: string` | Emitted when tab is selected |

---

## VDrawer

Drawer (side menu) navigation component.

### Basic Usage

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const drawerOpen = ref(false)

function navigateTo(page) {
  console.log('Navigate to:', page)
  drawerOpen.value = false
}
</script>

<template>
  <VView style="{ flex: 1 }">
    <!-- Main content -->
    <VButton title="Open Menu" @press="() => drawerOpen = true" />
    
    <!-- Drawer -->
    <VDrawer v-model:open="drawerOpen">
      <VDrawer.Section title="Menu">
        <VDrawer.Item
          icon="🏠"
          label="Home"
          @press="navigateTo('home')"
        />
        <VDrawer.Item
          icon="⚙️"
          label="Settings"
          @press="navigateTo('settings')"
        />
        <VDrawer.Item
          icon="ℹ️"
          label="About"
          @press="navigateTo('about')"
        />
      </VDrawer.Section>
    </VDrawer>
  </VView>
</template>
```

### With Header

```vue
<VDrawer v-model:open="drawerOpen">
  <template #header>
    <VView style="{ padding: 20, backgroundColor: '#007AFF' }">
      <VText style="{ color: '#fff', fontSize: 20, fontWeight: 'bold' }">
        My App
      </VText>
      <VText style="{ color: '#fff', opacity: 0.8 }">
        user@example.com
      </VText>
    </VView>
  </template>
  
  <VDrawer.Item icon="🏠" label="Home" />
  <VDrawer.Item icon="⚙️" label="Settings" />
</VDrawer>
```

### Right Position

```vue
<VDrawer
  v-model:open="drawerOpen"
  position="right"
  :width="300"
>
  <!-- Drawer content -->
</VDrawer>
```

### With Badges

```vue
<VDrawer.Item
  icon="📬"
  label="Messages"
  :badge="5"
  @press="navigateTo('messages')"
/>

<VDrawer.Item
  icon="🔔"
  label="Notifications"
  :badge="'99+'"
  @press="navigateTo('notifications')"
/>
```

### Disabled Items

```vue
<VDrawer.Item
  icon="🔒"
  label="Premium"
  disabled
  @press="showPremiumUpsell"
/>
```

### Props

#### VDrawer

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `open` | boolean | false | Whether drawer is open |
| `position` | 'left' \| 'right' | 'left' | Drawer position |
| `width` | number | 280 | Drawer width in pixels |
| `closeOnPress` | boolean | true | Close on item press |

#### VDrawer.Item

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `icon` | string | '' | Icon (emoji or name) |
| `label` | string | - | Item label |
| `badge` | number \| string | null | Badge count |
| `disabled` | boolean | false | Disabled state |

### Events

#### VDrawer

| Event | Params | Description |
|-------|--------|-------------|
| `update:open` | `open: boolean` | Emitted when open state changes |
| `close` | - | Emitted when drawer closes |

#### VDrawer.Item

| Event | Params | Description |
|-------|--------|-------------|
| `press` | - | Emitted when item is pressed |

### Slots

#### VDrawer

- `header` - Drawer header content
- `default` - Drawer content (receives `close` function)

---

## Patterns

### Tab + Drawer Combination

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const drawerOpen = ref(false)
const activeTab = ref('home')

const tabs = [
  { id: 'home', label: 'Home', icon: '🏠' },
  { id: 'explore', label: 'Explore', icon: '🔍' },
  { id: 'profile', label: 'Profile', icon: '👤' },
]
</script>

<template>
  <VView style="{ flex: 1 }">
    <!-- Main content -->
    <VButton 
      title="☰ Menu" 
      @press="() => drawerOpen = true"
      style="{ position: 'absolute', top: 20, left: 20, zIndex: 100 }"
    />
    
    <!-- Tab content -->
    <HomeView v-if="activeTab === 'home'" />
    <ExploreView v-else-if="activeTab === 'explore'" />
    <ProfileView v-else-if="activeTab === 'profile'" />
    
    <!-- Drawer -->
    <VDrawer v-model:open="drawerOpen">
      <VDrawer.Section title="Navigation">
        <VDrawer.Item
          icon="🏠"
          label="Home"
          @press="() => { activeTab = 'home'; drawerOpen = false }"
        />
        <VDrawer.Item
          icon="🔍"
          label="Explore"
          @press="() => { activeTab = 'explore'; drawerOpen = false }"
        />
        <VDrawer.Item
          icon="👤"
          label="Profile"
          @press="() => { activeTab = 'profile'; drawerOpen = false }"
        />
      </VDrawer.Section>
      
      <VDrawer.Section title="More">
        <VDrawer.Item icon="⚙️" label="Settings" />
        <VDrawer.Item icon="ℹ️" label="About" />
      </VDrawer.Section>
    </VDrawer>
    
    <!-- Tab bar -->
    <VTabBar
      :tabs="tabs"
      :activeTab="activeTab"
      @change="(tab) => activeTab = tab"
    />
  </VView>
</template>
```

### Programmatic Control

```typescript
// Access drawer methods
const drawerRef = ref(null)

function openDrawer() {
  drawerOpen.value = true
}

function closeDrawer() {
  drawerOpen.value = false
}

// Access tab bar methods
function switchToTab(tabId: string) {
  activeTab.value = tabId
}
```

### With Navigation

```vue
<script setup>
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()
const drawerOpen = ref(false)

function navigateTo(route) {
  router.push(route)
  drawerOpen.value = false
}
</script>

<template>
  <VDrawer v-model:open="drawerOpen">
    <VDrawer.Item
      icon="🏠"
      label="Home"
      @press="navigateTo('home')"
    />
    <VDrawer.Item
      icon="📊"
      label="Dashboard"
      @press="navigateTo('dashboard')"
    />
  </VDrawer>
</template>
```

---

## Styling

### Custom Tab Bar Styles

```vue
<VTabBar
  :tabs="tabs"
  :activeTab="activeTab"
  :style="{
    backgroundColor: '#000',
    borderTopWidth: 0,
  }"
/>
```

### Custom Drawer Styles

```vue
<VDrawer
  v-model:open="drawerOpen"
  :style="{
    backgroundColor: '#1a1a1a',
  }"
>
  <VDrawer.Item
    :style="{
      borderBottomColor: '#333',
    }"
  />
</VDrawer>
```

---

## Accessibility

Both components include built-in accessibility support:

- Tab items have `role="tab"` and proper selection state
- Drawer items have `role="menuitem"`
- Keyboard navigation support
- Screen reader announcements

### Custom Accessibility

```vue
<VTabBar
  :tabs="tabs"
  :activeTab="activeTab"
  :accessibilityLabel="`Tab bar, ${activeTab} selected`"
/>

<VDrawer.Item
  icon="⚙️"
  label="Settings"
  accessibilityLabel="Open settings menu"
  accessibilityHint="Double-tap to navigate to settings"
/>
```

---

## Troubleshooting

### Tab bar not showing

**Problem:** Tab bar doesn't appear.

**Solution:** Ensure parent has `flex: 1` and tab bar has proper positioning:
```vue
<VView style="{ flex: 1 }">
  <VTabBar ... />
</VView>
```

### Drawer not closing

**Problem:** Drawer stays open after item press.

**Solution:** Use `closeOnPress` prop or manually close:
```vue
<VDrawer 
  v-model:open="drawerOpen"
  :closeOnPress="true"
>
  <VDrawer.Item @press="() => drawerOpen = false" />
</VDrawer>
```

### Tab change not detected

**Problem:** `@change` event not firing.

**Solution:** Ensure you're using the correct event name and handler:
```vue
<VTabBar @change="handleTabChange" />
```

---

## Related

- [Navigation Guide](./navigation.md)
- [VButton Component](../components/VButton.md)
- [VView Component](../components/VView.md)
