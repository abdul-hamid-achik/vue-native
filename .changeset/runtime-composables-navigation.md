---
'@thelacanians/vue-native-runtime': patch
'@thelacanians/vue-native-navigation': patch
---

`useDatabase` recovers from a failed open, gestures follow remounts, and tab guards cannot race.

- `useDatabase` retries the native open after a failure instead of replaying the
  same rejection for the life of the component.
- `useGesture` and `useComposedGestures` follow a template ref for the life of
  the scope, so a `v-if` remount or `key` change moves the listeners to the new
  view, and a comment anchor is never bound.
- Tab and drawer navigators apply only the latest request when async guards
  resolve out of order.
