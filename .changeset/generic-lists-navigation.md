---
"@thelacanians/vue-native-runtime": minor
"@thelacanians/vue-native-navigation": minor
---

**Runtime — generic list slots:**

- `VList` and `VSectionList` are now generic components: the `#item` slot scope infers the item type `T` from `data` (VList) or `sections` (VSectionList), so `item` is no longer `unknown`. `VSectionList`'s section is typed via the exported `VSectionListSection<T>`.

**Navigation:**

- `handleURL` now returns a `Promise<boolean>` that settles after guard resolution, and accepts `HandleURLOptions` with a `strategy: 'push' | 'reset'` deep-link strategy (`reset` resets the stack to the matched route instead of pushing).
- New opt-in `swipeBack` router option: when enabled, the router listens for the native `gesture:swipeBack` event (iOS edge-pan) and pops the stack.
- Tab and drawer navigators now run `beforeEach`/`beforeResolve` guards on screen transitions (guard redirects are not supported for tab/drawer transitions and block the transition instead).

**iOS (ships with the tag):**

- `VInput multiline` is now real: the registered view is a stable container that swaps an internal `UITextField`/`UITextView`, preserving text, traits, delegate, and events across the swap (with a placeholder overlay for multiline and a secure-single-line fallback).
- Native left-edge swipe-back gesture dispatches `gesture:swipeBack` for the router's `swipeBack` option.
