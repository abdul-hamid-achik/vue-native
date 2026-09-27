# macOS

Vue Native supports building native macOS desktop applications using AppKit. Your Vue.js components render as real native macOS controls — not web views.

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 16+
- Swift 6.0+ toolchain

## How It Works

Vue Native on macOS uses the same architecture as iOS:

1. Your Vue 3 components are compiled to an IIFE JavaScript bundle
2. JavaScriptCore (built into macOS) runs your Vue app
3. The Vue custom renderer translates virtual DOM operations into native AppKit view operations
4. A flexbox layout engine positions your views

## Quick Start

`vue-native create` scaffolds a complete macOS host (`macos/project.yml` plus `macos/Sources/`), so the whole flow is three commands:

```bash
vue-native create my-mac-app
cd my-mac-app
bun install

# watch mode: rebuilds the bundle and pushes it over WebSocket
vue-native dev --platform macos

# generates macos/*.xcodeproj with XcodeGen, then builds and launches the .app
vue-native run macos
```

XcodeGen is a hard prerequisite (`brew install xcodegen`): `macos/project.yml` is the committed source of truth and the generated `.xcodeproj` is gitignored.

See [macOS Setup](./setup.md) for the generated host file by file, hot reload, and debugging.

## Key Differences from iOS

| Aspect | iOS | macOS |
|--------|-----|-------|
| Framework | UIKit | AppKit |
| Entry Point | `VueNativeViewController` | `VueNativeWindowController` |
| Layout Engine | FlexLayout (Yoga) | LayoutNode (custom flexbox) |
| Coordinate System | Top-left origin | Top-left via `FlippedView` |
| Controls | Touch-based | Mouse/keyboard |

## macOS-Only Components

- [VToolbar](/components/VToolbar) — Native window toolbar
- [VSplitView](/components/VSplitView) — Split pane layout
- [VOutlineView](/components/VOutlineView) — Tree view

## macOS-Only Composables

- [useWindow](/composables/useWindow) — Window management
- [useMenu](/composables/useMenu) — App and context menus
- [useFileDialog](/composables/useFileDialog) — File open/save dialogs
- [useDragDrop](/composables/useDragDrop) — Drag and drop

## No-Op Components on macOS

These components exist for cross-platform compatibility but are no-ops on macOS:

- `VStatusBar` — macOS has no app status bar
- `VKeyboardAvoiding` — Desktop keyboards don't cover content
- `VRefreshControl` — No pull-to-refresh on desktop
