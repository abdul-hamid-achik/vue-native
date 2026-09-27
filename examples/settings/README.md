# Settings

A settings screen demonstrating form controls, pickers, and persistent storage.

> **Requires a native host for Android and macOS.** An `ios/` XcodeGen project
> is included, but there is no `android/` or `macos/` shell — so `bun run
> dev:android` and `bun run dev:macos` have nothing to run in. Scaffold one with
> `bunx vue-native create my-app` and copy `app/`, `vite.config.ts` and
> `env.d.ts` into it to target those platforms.

## What It Demonstrates

- **Components:** VView, VText, VButton, VSwitch, VScrollView, VActivityIndicator
- **Composables:** `useColorScheme`, `useDeviceInfo`
- **Patterns:**
  - Grouped settings rows with toggle switches
  - Light / dark switching via `useColorScheme`
  - Real device metadata (model, system name, system version, screen size, scale) via `useDeviceInfo`
  - A simulated save action with an activity indicator

Settings are held in local `ref` state — this example does not persist them.

## Key Features

- Grouped preference rows with toggles
- Light / dark appearance switching
- Live device information (model, OS, screen size, scale)
- Simulated save with an activity indicator

Preferences are held in component state; nothing is persisted.

## How to Run

```bash
cd examples/settings
bun install
bun run dev:ios
```

Generate the included iOS project with `cd ios && xcodegen generate`, then open
`ios/VueNativeSettings.xcodeproj`. To use the Vue source on Android, run
`bun run dev:android` after copying it into a scaffold with an Android host.

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
