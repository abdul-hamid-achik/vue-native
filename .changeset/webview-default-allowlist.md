---
'@thelacanians/vue-native-runtime': patch
'@thelacanians/vue-native-cli': patch
---

Fix `<VWebView :source="{ uri }">` never loading on iOS and macOS since 0.21.0.

`VWebView` sent its default `allowedOrigins: []` right after `source`, and the
native allowlist treated that empty list as "allow nothing". WebKit reports even
the initial load as a non-explicit navigation, so it was cancelled and the view
stayed blank. On Android the first page loaded, but messages and same-origin
links were refused.

The runtime now sends `allowedOrigins` only when the list is non-empty. The
three native policies keep the origin derived from `source` apart from the
host's list: a non-empty `allowedOrigins` replaces the derived origin, and an
empty or cleared list restores it, whatever order the props arrive in. A source
change now replaces the previous source's origin instead of accumulating it.
`allowedOrigins` must be an array of strings on iOS and macOS; a comma-separated
string is no longer accepted there.

On Android, page messages now go through WebView's message listener when the
installed WebView supports it, so the origin of every frame is checked, not just
the main frame's URL. Outdated WebViews keep the previous JavaScript interface
and log a warning.
