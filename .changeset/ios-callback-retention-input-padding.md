---
"@thelacanians/vue-native-cli": patch
---

iOS: pending `fetch` promises and `setTimeout`/`setInterval` callbacks are now kept in the JS heap (`JSCallbackRegistry`) instead of `JSManagedValue`s owned by the context, which the garbage collector could free mid-request, so a request never settled or a timer never fired (intermittent hangs, most visible with concurrent requests). `VInput` padding now insets the text and placeholder instead of being ignored.
