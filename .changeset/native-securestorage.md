---
'@thelacanians/vue-native-cli': patch
---

SecureStorage: safer `setProtected`, and Android survives an Auto Backup restore.

`setProtected` validates the value before deleting the existing secret. On
Android the encrypted store is excluded from backup and device transfer in new
projects, because its Keystore key does not migrate (existing apps should add
the same rules, see the useSecureStorage docs). A store that still cannot be
decrypted is reset instead of disabling the module.
