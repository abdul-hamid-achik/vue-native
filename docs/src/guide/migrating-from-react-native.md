# Migrating from React Native

Vue Native targets the same mental model as React Native — native views driven
by a JavaScript framework, Flexbox layout, a `StyleSheet`-style API — but the
components are Vue components and the platform APIs are Vue composables. This
guide maps the concepts you already know onto their Vue Native equivalents.

The component and composable names below are the real exports from
`@thelacanians/vue-native-runtime` (see
[`packages/runtime/src/components/`](https://github.com/abdul-hamid-achik/vue-native/tree/main/packages/runtime/src/components)
and
[`packages/runtime/src/composables/`](https://github.com/abdul-hamid-achik/vue-native/tree/main/packages/runtime/src/composables)).

## Core concepts at a glance

| React Native | Vue Native | Notes |
|--------------|------------|-------|
| JSX components (`<View>`) | Vue components (`<VView>`) | All built-ins are prefixed with `V`. |
| Hooks (`useState`, `useEffect`) | Vue reactivity (`ref`, `computed`, `watch`, lifecycle hooks) | From `vue` / `@vue/runtime-core`. |
| `StyleSheet.create` | `createStyleSheet` | Validates + freezes style objects. |
| `Platform` / `Platform.select` | `usePlatform` / `selectPlatform` | Build-time constant, dead-code eliminated. |
| `AsyncStorage` | `useAsyncStorage` | Promise-based, per-key serialized writes. |
| React Navigation | `@thelacanians/vue-native-navigation` | Name-based routes, `createRouter`, `RouterView`. |

## Component mapping

| React Native | Vue Native | Doc |
|--------------|------------|-----|
| `View` | `VView` | [VView](/components/VView.md) |
| `Text` | `VText` | [VText](/components/VText.md) |
| `Image` | `VImage` | [VImage](/components/VImage.md) |
| `ScrollView` | `VScrollView` | [VScrollView](/components/VScrollView.md) |
| `FlatList` | `VFlatList` (virtualized) or `VList` (native table/recycler) | [VFlatList](/components/VFlatList.md), [VList](/components/VList.md) |
| `SectionList` | `VSectionList` | [VSectionList](/components/VSectionList.md) |
| `TextInput` | `VInput` | [VInput](/components/VInput.md) |
| `Pressable` / `TouchableOpacity` | `VPressable` (or `VButton` for a styled button) | [VPressable](/components/VPressable.md), [VButton](/components/VButton.md) |
| `Switch` | `VSwitch` | [VSwitch](/components/VSwitch.md) |
| `ActivityIndicator` | `VActivityIndicator` | [VActivityIndicator](/components/VActivityIndicator.md) |
| `Modal` | `VModal` | [VModal](/components/VModal.md) |
| `RefreshControl` | `VRefreshControl` | [VRefreshControl](/components/VRefreshControl.md) |
| `SafeAreaView` | `VSafeArea` | [VSafeArea](/components/VSafeArea.md) |
| `KeyboardAvoidingView` | `VKeyboardAvoiding` | [VKeyboardAvoiding](/components/VKeyboardAvoiding.md) |
| `StatusBar` | `VStatusBar` | [VStatusBar](/components/VStatusBar.md) |
| `WebView` (community) | `VWebView` | [VWebView](/components/VWebView.md) |
| `Video` (community) | `VVideo` | [VVideo](/components/VVideo.md) |

Vue Native also ships components with no direct RN-core equivalent, such as
`VSlider`, `VSegmentedControl`, `VCheckbox`, `VRadio`, `VDropdown`, `VPicker`,
`VAlertDialog`, `VActionSheet`, `VProgressBar`, `VErrorBoundary`, `VTransition`,
and the macOS-only `VToolbar`, `VSplitView`, and `VOutlineView`.

### Event prop naming

RN uses `onPress`, `onChangeText`, etc. Vue Native keeps the same camelCase
names but they are wired as Vue props/events:

```vue
<!-- React Native: <TouchableOpacity onPress={handlePress}> -->
<VButton :onPress="handlePress">
  <VText>Tap me</VText>
</VButton>

<!-- React Native: <TextInput onChangeText={setText} /> -->
<VInput :onChangeText="setText" />
```

## Composables ↔ hooks / modules

Platform capabilities are exposed as composables (functions you call in
`<script setup>`), not hooks or imperative native modules.

| React Native | Vue Native | Doc |
|--------------|------------|-----|
| `Platform.OS` / flags | `usePlatform()` | [usePlatform](/composables/usePlatform.md) |
| `Platform.select({...})` | `selectPlatform({...})` | [usePlatform](/composables/usePlatform.md#selectplatform) |
| `AsyncStorage` | `useAsyncStorage()` | [useAsyncStorage](/composables/useAsyncStorage.md) |
| `Keychain` / secure storage | `useSecureStorage()` | [useSecureStorage](/composables/useSecureStorage.md) |
| `Animated` / `Reanimated` | `useAnimation()` | [useAnimation](/composables/useAnimation.md) |
| `useWindowDimensions` / `Dimensions` | `useDimensions()` | [useDimensions](/composables/useDimensions.md) |
| `AppState` | `useAppState()` | [useAppState](/composables/useAppState.md) |
| `NetInfo` | `useNetwork()` | [useNetwork](/composables/useNetwork.md) |
| `useColorScheme` | `useColorScheme()` | [useColorScheme](/composables/useColorScheme.md) |
| `BackHandler` | `useBackHandler()` | [useBackHandler](/composables/useBackHandler.md) |
| `Linking` | `useLinking()` | [useLinking](/composables/useLinking.md) |
| `Clipboard` | `useClipboard()` | [useClipboard](/composables/useClipboard.md) |
| `Share` | `useShare()` | [useShare](/composables/useShare.md) |
| `Keyboard` | `useKeyboard()` | [useKeyboard](/composables/useKeyboard.md) |
| `fetch` wrappers / axios | `useHttp()` | [useHttp](/composables/useHttp.md) |
| WebSocket | `useWebSocket()` | [useWebSocket](/composables/useWebSocket.md) |
| `react-native-haptic-feedback` | `useHaptics()` | [useHaptics](/composables/useHaptics.md) |
| `react-native-permissions` | `usePermissions()` | [usePermissions](/composables/usePermissions.md) |
| `react-native-gesture-handler` | `useGesture()` | [useGesture](/composables/useGesture.md) |
| `expo-local-authentication` | `useBiometry()` | [useBiometry](/composables/useBiometry.md) |
| `expo-camera` | `useCamera()` | [useCamera](/composables/useCamera.md) |
| `react-native-iap` | `useIAP()` | [useIAP](/composables/useIAP.md) |
| `react-native-ota-hot-update` | `useOTAUpdate()` | [useOTAUpdate](/composables/useOTAUpdate.md) |

## Styling differences

The styling API is deliberately close to RN's `StyleSheet`, with a few important
differences:

### `createStyleSheet` instead of `StyleSheet.create`

```ts
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: { flex: 1, padding: 16, backgroundColor: '#fff' },
  title: { fontSize: 20, fontWeight: '600', color: '#111' },
})
```

In development, unknown style properties trigger a console warning; the returned
objects are frozen.

### No percentages on padding/margin

`padding` and `margin` (and all `padding*` / `margin*` variants) accept
**numbers only**. Percentage strings are not supported (a breaking change in
v0.8.0). Percentage values are still supported on `width`, `height`,
`min*`/`max*`, `flexBasis`, and `top`/`right`/`bottom`/`left`. Compute
padding/margin from the parent dimension yourself if needed (e.g. with
`useDimensions`).

### `hairlineWidth`

```ts
import { hairlineWidth } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  separator: { height: hairlineWidth, backgroundColor: '#ccc' },
})
```

`hairlineWidth` is `0.5`, mirroring `StyleSheet.hairlineWidth`.

### Shadows: iOS vs Android

iOS uses `shadowColor` / `shadowOffset` / `shadowOpacity` / `shadowRadius`;
Android ignores those and requires `elevation`. Set both for cross-platform
cards. See [Styling](/guide/styling.md) for the full property reference.

### Theming

RN has no built-in theme system; most apps roll their own or use a library. Vue
Native ships one: `createTheme` + `<ThemeProvider>` + `createDynamicStyleSheet`.
See the [Theming guide](/guide/theming.md).

## Navigation

React Navigation resolves screens by route object; Vue Native's
`@thelacanians/vue-native-navigation` resolves them **by name**.

```ts
import { createRouter } from '@thelacanians/vue-native-navigation'
import Home from './screens/Home.vue'
import Detail from './screens/Detail.vue'

// Routes are keyed by NAME — there is no `path` field.
const router = createRouter([
  { name: 'Home', component: Home },
  { name: 'Detail', component: Detail },
])

export default router
```

| React Navigation | Vue Native navigation |
|------------------|-----------------------|
| `createNativeStackNavigator` + `<Stack.Screen name>` | `createRouter([{ name, component }])` |
| `navigation.navigate('Detail', { id })` | `router.push('Detail', { id })` (or `router.navigate`) |
| `navigation.goBack()` | `router.pop()` (or `router.goBack()`) |
| `navigation.replace(...)` | `router.replace(...)` |
| `navigation.reset(...)` | `router.reset(...)` |
| `useNavigation()` | `useRouter()` |
| `useRoute()` (`route.params`) | `useRoute()` (`route.value.params`) |
| `navigation.setOptions({ title })` | Per-route `options: { title }` in `RouteConfig` |
| Deep linking `linking` config | `createRouter({ routes, linking })` |
| Bottom tabs / drawer navigators | `VTabBar` / `VDrawer` components + nested routers |

Guards return a route **name** to redirect, or `false` to cancel:

```ts
router.beforeEach((to, from) => {
  if (to.config.name !== 'Login' && !isAuthenticated()) {
    return 'Login' // redirect by name
  }
})
```

See the [Navigation guide](/guide/navigation.md) and the
[Navigation section](/navigation/) for details.

## A minimal side-by-side

```jsx
// React Native
import { View, Text, StyleSheet } from 'react-native'

export default function Hello({ name }) {
  return (
    <View style={styles.box}>
      <Text style={styles.title}>Hello {name}</Text>
    </View>
  )
}

const styles = StyleSheet.create({
  box: { flex: 1, padding: 16, justifyContent: 'center' },
  title: { fontSize: 24, color: '#111' },
})
```

```vue
<!-- Vue Native -->
<script setup>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

defineProps({ name: String })

const styles = createStyleSheet({
  box: { flex: 1, padding: 16, justifyContent: 'center' },
  title: { fontSize: 24, color: '#111' },
})
</script>

<template>
  <VView :style="styles.box">
    <VText :style="styles.title">Hello {{ name }}</VText>
  </VView>
</template>
```

## See also

- [Components](/guide/components.md) — how Vue Native components work.
- [Styling](/guide/styling.md) — full style property reference.
- [Theming](/guide/theming.md) — built-in design tokens and dark mode.
- [Navigation](/guide/navigation.md) — routing and screen lifecycle.
