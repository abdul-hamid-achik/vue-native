---
'@thelacanians/vue-native-cli': minor
---

OTA: signed release manifests, a monotonic version floor, and strict versions.

- The publisher can now sign a manifest that binds the version to the bundle:
  the UTF-8 bytes of `vue-native-ota-v1`, the version and the lowercase SHA-256,
  separated by newlines. A signature over the raw bundle bytes still verifies but
  is deprecated, because it lets anyone who can serve bytes replay an old signed
  bundle under a higher version. Hosts can refuse legacy signatures with the
  Info.plist Boolean `VueNativeOTARequireSignedManifest` or the
  `com.vuenative.ota.requireSignedManifest` meta-data.
- The anti-downgrade floor is now the highest version ever applied, stored
  natively. Rolling back no longer lowers it, so after a rollback ship a higher
  version.
- Versions must be an optional `v`, one to four dotted numbers, an optional
  `-prerelease` and an ignored `+build`. Anything else is rejected. The old
  comparator ranked `v1.8.0` above `1.9.0`; ordering now follows semver
  precedence on iOS and Android.
- iOS accepts a base64 signature split across lines, as Android already did,
  so a `base64` that wraps its output no longer fails verification on iOS only.
