# Auth Flow

A login / home flow demonstrating authentication patterns with navigation guards.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VScrollView
- **Composables:** `useAsyncStorage` (token persistence), `useHaptics` (feedback)
- **Navigation:** `createRouter`, `router.reset()`, `beforeEach` guard
- **Patterns:** Protected routes, token-based auth, navigation guard redirect, `NativeBridge.invokeNativeModule`

## Key Features

- Login screen with email/password form and validation
- Navigation guard redirects unauthenticated users to Login
- Persistent auth token via AsyncStorage
- `router.reset()` replaces the stack on login/logout (no back button)
- Home screen showing auth status and explanation cards

## How to Run

```bash
bun install
bun run dev
```
