# Native Blocks Code-Generation Demo

This source-only example shows how Vue Native parses `<native>` blocks and
generates Swift, Kotlin, TypeScript composables, and native-module registries.
It intentionally does not include an iOS, Android, or macOS app shell, so it is
useful for inspecting code generation but is not an end-to-end native app by
itself.

## What It Demonstrates

- Platform-specific iOS and Android `NativeModule` implementations in an SFC
- Generated Swift and Kotlin source
- Generated, typed TypeScript composables
- Generated registration source for each native platform
- Deterministic regeneration through both the CLI and Vite plugin

The demo prefixes its device-information module as `ExtendedDeviceInfo` so it
does not collide with Vue Native's built-in `DeviceInfo` module when generated
inside a scaffold.

Generating a registry file does not make an arbitrary output directory part of
an Xcode or Gradle target. A runnable app must generate these files into the
native source roots supplied by a Vue Native scaffold.

## Generate and Inspect

```bash
cd examples/native-blocks-demo
bun install
bun run generate
bun run typecheck
bun run build
```

The demo deliberately writes inspection artifacts outside a native package:

```text
generated/ios/       Swift modules and registry
generated/android/   Kotlin modules and registry
generated/macos/     Empty macOS registry (there are no macOS blocks yet)
app/generated/       TypeScript composables
```

These directories are generated and ignored by Git. `bun run dev:ios`,
`bun run dev:android`, and `bun run dev:macos` start platform-targeted bundle
watchers, but a corresponding native host is still required to execute a
generated module.

## Run It in a Native App

1. Create a fresh project with `bun run create:host NativeBlocksHost`.
2. Copy the `<native>` blocks and UI from `app/App.vue` into the scaffold.
3. Keep the scaffold's default native output paths. They point at the Swift and
   Kotlin source roots compiled by its bundled native projects.
4. Import the generated composables from `app/generated/` and replace the
   source-only status handlers with real calls.
5. Start the matching watcher with `bun run dev -- --ios`,
   `bun run dev -- --android`, or `bun run dev -- --platform macos` from the
   scaffold.

The generated `GeneratedModuleRegistry` is then compiled with the native host
and called automatically by Vue Native. Do not manually register the generated
modules a second time.

## Valid Platform-Specific Modules

An iOS block implements the Swift `NativeModule` protocol:

```vue
<native platform="ios">
class GreetingModule: NativeModule {
    var moduleName: String { "Greeting" }

    func invoke(
        method: String,
        args: [Any],
        callback: @escaping (Any?, String?) -> Void
    ) {
        guard method == "greet" else {
            callback(nil, "Unknown method: \(method)")
            return
        }
        let name = args.first as? String ?? "World"
        callback("Hello, \(name)!", nil)
    }
}
</native>
```

An Android block implements the Kotlin protocol, including the active bridge
argument:

```vue
<native platform="android">
class GreetingModule : NativeModule {
    override val moduleName: String = "Greeting"

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit,
    ) {
        if (method != "greet") {
            callback(null, "Unknown method: $method")
            return
        }
        val name = args.firstOrNull() as? String ?: "World"
        callback("Hello, $name!", null)
    }
}
</native>
```

After generation, application code calls the typed composable rather than
constructing registry entries manually:

```ts
import { useGreeting } from './generated/useGreeting'

const { greet } = useGreeting()
const message = await greet('Vue Native')
```

## Repository Layout

```text
examples/native-blocks-demo/
├── app/
│   ├── main.ts
│   └── App.vue          Source blocks and source-only UI
├── env.d.ts
├── package.json
├── tsconfig.json
└── vite.config.ts       Inspection output directories
```

## Learn More

- [Native Blocks Guide](../../docs/src/guide/native-blocks.md)
- [Custom Native Modules](../../docs/src/guide/native-modules.md)
