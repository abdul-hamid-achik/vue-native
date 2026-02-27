# Settings

An iOS-style settings screen with toggles, device info, and color scheme detection.

## What It Demonstrates

- **Components:** VScrollView, VView, VText, VSwitch, VButton, VActivityIndicator
- **Composables:** `useColorScheme` (dark mode detection), `useDeviceInfo` (model, OS version)
- **Patterns:** Grouped settings sections, data-driven UI, simulated async save

## Key Features

- Grouped toggle sections (Notifications, Privacy, Appearance, Advanced)
- Device info section showing model, OS version, and color scheme
- Save button with loading spinner and success message
- iOS Settings-style visual design

## How to Run

```bash
bun install
bun run dev
```
