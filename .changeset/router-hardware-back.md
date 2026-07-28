---
"@thelacanians/vue-native-navigation": minor
---

Add an opt-in `handleBackButton` router option. When enabled (`createRouter({ routes, handleBackButton: true })`), the router handles the Android hardware back button/gesture: it pops the stack when possible and exits the app at the root. Defaults to `false`, so existing behavior is unchanged. When enabled, do not also register `useBackHandler` for the same screen.

Also clarifies in the `RouteOptions` documentation that `title`/`headerShown`/`animation`/`tabBarLabel`/`tabBarIcon` are accepted for forward compatibility but are not yet rendered by the router.
