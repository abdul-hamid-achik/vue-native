# Navigation Demo

Comprehensive navigation showcase for Vue Native.

## Navigation Patterns

- **Tab Navigator** — Bottom tab bar with Home, Search, Profile tabs
- **Drawer Navigator** — Side menu with Main, Settings, Profile screens
- **Stack Navigation** — Push/pop within tabs (Home → Detail)
- **Deep Linking** — URL scheme `navdemo://` and universal link support

## Components Used

- **TabNavigator** — `createTabNavigator()` with lazy tabs
- **DrawerNavigator** — `createDrawerNavigator()` with side menu
- **RouterView** — Stack navigation rendering
- **VNavigationBar** — Native-styled navigation bar

## Navigation Features

- `onScreenFocus` / `onScreenBlur` — Screen lifecycle hooks
- `useRouter` / `useRoute` — Programmatic navigation and route params
- `useDrawer` — Drawer open/close/toggle
- `afterEach` guard — Navigation logging
- Deep link config with `prefixes` and `screens` mapping

## URL Scheme

```
navdemo://detail/42     → Detail screen with id=42
navdemo://search        → Search tab
navdemo://profile       → Profile tab
navdemo://settings      → Settings (drawer)
```

## Running

```bash
bun run dev    # Watch mode
bun run build  # Production build
```
