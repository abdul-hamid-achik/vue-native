# Counter

A simple counter app demonstrating the basics of Vue Native.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput
- **Composables:** `useHaptics` (button press feedback)
- **Patterns:** `ref`, `computed`, two-way binding with `v-model`, `createStyleSheet`

## Key Features

- Editable greeting with reactive name input
- Increment / decrement counter with haptic feedback
- Clean, centered layout using Yoga FlexBox

## How to Run

```bash
cd examples/counter
bun install
bun run dev:ios
```

Open the included `ios/VueNativeCounter.xcodeproj` in Xcode. Android and macOS
native hosts are not included; use `bun run dev:android` or `bun run dev:macos`
only after copying the Vue source into a matching generated project.
