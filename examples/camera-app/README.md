# Camera App

A camera app with photo capture, library picker, and gallery strip.

## What It Demonstrates

- **Components:** VView, VText, VButton, VImage, VScrollView, VActivityIndicator
- **Composables:** `useCamera` (capture / library), `usePermissions` (camera access)
- **Patterns:** Permission flow, async actions with loading overlay, `onMounted` lifecycle

## Key Features

- Camera capture and photo library picker
- Runtime permission request flow
- Full-screen photo preview with timestamp overlay
- Horizontal gallery strip with selection highlight
- Loading overlay during capture

## How to Run

```bash
bun install
bun run dev
```
