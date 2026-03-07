# Settings

A settings screen demonstrating form controls, pickers, and persistent storage.

## What It Demonstrates

- **Components:** VView, VText, VButton, VSwitch, VInput, VPicker, VScrollView
- **Composables:** `useAsyncStorage` for persistence, `useHaptics` for feedback
- **Patterns:**
  - Form state management
  - Settings persistence
  - Picker controls
  - Toggle switches

## Key Features

- User preferences form
- Theme selection (light/dark)
- Notification settings
- Profile information
- Auto-save functionality

## How to Run

```bash
cd examples/settings
bun install
bun vue-native dev
```

## Key Concepts

### Form State

```typescript
const settings = ref({
  username: '',
  email: '',
  notifications: true,
  theme: 'light',
})
```

### Auto-Save

```typescript
watch(settings, async () => {
  await useAsyncStorage().setItem('settings', JSON.stringify(settings.value))
}, { deep: true })
```

## Learn More

- [VSwitch Component](../../docs/src/components/VSwitch.md)
- [VPicker Component](../../docs/src/components/VPicker.md)
- [useAsyncStorage](../../docs/src/composables/useAsyncStorage.md)
