# Auth Flow

Complete authentication flow with login, registration, and protected screens.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VScrollView, VSafeArea
- **Composables:** `useSecureStorage`, `useAsyncStorage`, `useHaptics`, `useRouter`
- **Navigation:** `createRouter` with a `beforeEach` guard
- **Patterns:**
  - Protected routes — the guard reads the session token and redirects to Login when it is missing
  - Secret storage: the auth token goes to Keychain (iOS) / EncryptedSharedPreferences (Android), never plaintext `AsyncStorage`
  - Non-sensitive profile data kept in `AsyncStorage`
  - Login / logout with `router.reset()`
  - Inline form validation with haptic feedback

## Key Features

- Login screen with inline validation
- Protected home screen
- Token-based auth stored in Keychain / EncryptedSharedPreferences
- Auto-login on app start via a `beforeEach` navigation guard
- Logout that clears the secure token

There is no registration screen and no biometric login in this example, although
`useBiometry` exists in the runtime.

## How to Run

```bash
cd examples/auth-flow
bun install
bun run dev:ios
# or: bun run dev:android
```

This directory contains the Vue source and build configuration, not a native app
shell. Copy `app/`, `vite.config.ts`, and `env.d.ts` into a project created by
the Vue Native CLI before launching it on a simulator or device.

## Key Concepts

### Auth State Management

```typescript
const user = ref<User | null>(null)
const token = ref<string | null>(null)

const isAuthenticated = computed(() => !!token.value)
```

### Token Storage

```typescript
import { useSecureStorage, useAsyncStorage } from '@thelacanians/vue-native-runtime'

// Secrets go to Keychain (iOS) / EncryptedSharedPreferences (Android).
const { setItem: setSecret, removeItem: removeSecret } = useSecureStorage()
// Non-sensitive profile data can stay in plaintext AsyncStorage.
const { setItem, getItem } = useAsyncStorage()

await setSecret('auth_token', token)
await setItem('auth_user', JSON.stringify({ email }))

// The navigation guard reads the token back through the bridge, because it runs
// before any component mounts. SecureStorage's native methods are
// get / set / remove / clear.
const stored = await NativeBridge.invokeNativeModule('SecureStorage', 'get', ['auth_token'])
```

Do **not** put an auth token in `useAsyncStorage` — it is plaintext on disk.


### Protected Routes

```typescript
router.beforeEach(async (to, from, next) => {
  if (to.meta.requiresAuth && !isAuthenticated.value) {
    next({ name: 'login' })
  } else {
    next()
  }
})
```

### Biometric Authentication

Not implemented in this example. `useBiometry()` is available in the runtime and
would look like:

```typescript
const { authenticate, isAvailable } = useBiometry()

if (await isAvailable()) {
  // authenticate() takes the prompt reason as a plain string.
  const result = await authenticate('Authenticate to continue')
  if (result.success) {
    // fall through to the session
  }
}
```


### API Calls with Token

```typescript
const { post } = useHttp()

const response = await post('/login', {
  email: email.value,
  password: password.value,
})

token.value = response.data.token
```

## File Structure

```
examples/auth-flow/
├── app/
│   ├── main.ts
│   ├── App.vue
│   └── screens/
│       ├── LoginScreen.vue
│       └── HomeScreen.vue
├── vite.config.ts
└── package.json
```

## Learn More

- [useHttp](../../docs/src/composables/useHttp.md)
- [useAsyncStorage](../../docs/src/composables/useAsyncStorage.md)
- [useBiometry](../../docs/src/composables/useBiometry.md)
- [Navigation Guards](../../docs/src/navigation/guards.md)

## Try This

Experiment with:
1. Add password reset flow
2. Implement OAuth (Google/Apple sign-in)
3. Add refresh token logic
4. Implement session timeout
5. Add multi-factor authentication
