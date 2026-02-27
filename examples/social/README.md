# Social Feed

A social media app with tab navigation, feed, explore grid, and profile screens.

## What It Demonstrates

- **Components:** VView, VText, VButton, VImage, VScrollView, VProgressBar
- **Composables:** `useNetwork` (connectivity status), `useHaptics` (like feedback)
- **Navigation:** `createTabNavigator` from `@thelacanians/vue-native-navigation`
- **Patterns:** Multi-screen tab app, pull-to-refresh, photo grid layout, profile stats

## Key Features

- **Feed:** Social posts with likes, comments, images, and pull-to-refresh
- **Explore:** Photo grid with search bar
- **Profile:** User profile with stats, follow button, and skill progress bars
- Offline banner when network is unavailable
- Tab navigator with lazy screen mounting

## How to Run

```bash
bun install
bun run dev
```
