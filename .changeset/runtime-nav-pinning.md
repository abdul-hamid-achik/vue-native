---
"@thelacanians/vue-native-runtime": minor
"@thelacanians/vue-native-navigation": minor
---

Serialize navigation transitions so concurrent pushes cannot drop a route; keep replace/reset/goBack guard redirects on the same stack operation; disable pointer events on inactive RouterView screens. Flatten array styles, fix concurrent useDatabase opens, and clear Teleport targets on hot-reload teardown. Android certificate pins now merge like Apple, and OTA/FileSystem/image loads use the pin-aware HTTP client. Android VScrollView honors `horizontal` and `scrollEnabled`.
