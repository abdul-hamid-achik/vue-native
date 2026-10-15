---
"@thelacanians/vue-native-cli": patch
---

`useIAP`: iOS transactions now include the App Store–signed `jwsRepresentation` (plus `originalTransactionId`, `appAccountToken` and `environment`) so a server can verify purchases; `purchase(sku, { appAccountToken })` ties a purchase to your user; new `showManageSubscriptions()` opens the system subscription screen (iOS sheet, Play Store on Android); transaction updates carry the same fields and report refunds as `revoked`.
