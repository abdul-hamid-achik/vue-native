---
"@thelacanians/vue-native-cli": minor
---

`skewX`/`skewY` transforms now render on Android. A transform list containing skew is composed into a single native matrix with the exact same composition order and center pivot as iOS's transform engine (parity verified numerically case by case), applied via `setAnimationMatrix` on API 29+ and a static `fillAfter` animation on API 21–28. The common no-skew path is untouched, and native-driven pan now composes with a skewed view (it keeps its skew while dragged). Known limits, both documented: Android hit-testing does not follow skewed geometry, and skew combined with `rotateX`/`rotateY`/`perspective` in the same list still falls back to ignoring the skew with a one-time warning.
