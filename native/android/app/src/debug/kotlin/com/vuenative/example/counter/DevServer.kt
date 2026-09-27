package com.vuenative.example.counter

/**
 * Debug-variant-only hot-reload endpoint.
 *
 * `10.0.2.2` is the emulator's alias for the host machine's loopback interface,
 * so `vue-native dev` running on the developer's machine is reachable from an
 * Android emulator at this address. On a physical device use
 * `ws://<your-mac-LAN-ip>:5173` (start the dev server with `--lan`).
 *
 * This file exists only in `src/debug`; the release variant compiles against the
 * `src/release` copy, which returns null.
 */
internal object DevServer {
    val url: String? = "ws://10.0.2.2:5173"
}
