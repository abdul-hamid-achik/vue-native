---
'@thelacanians/vue-native-runtime': patch
---

Fix a second, internal unhandled rejection on every failed storage write.

`createWriteQueue`'s chain cleanup registered only a fulfilment handler, so a
rejected write produced an unhandled rejection inside the queue itself on top
of the one the caller observes. In JavaScriptCore and V8 that is console noise
at best and a termination risk at worst, and it fired on the path that matters
most: a Keychain or EncryptedSharedPreferences failure during a token refresh.
The cleanup now settles on both outcomes. `writeQueue` also gains its first
tests: same-key ordering, cross-key concurrency, surviving a rejection, and
per-backend independence for identical keys.
