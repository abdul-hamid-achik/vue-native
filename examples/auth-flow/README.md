# Auth Flow

Complete authentication flow with login, registration, and protected screens.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VModal, VActivityIndicator
- **Composables:** `useHttp`, `useAsyncStorage`, `useBiometry`
- **Patterns:**
  - Authentication state management
  - Token storage
  - Protected routes
  - Biometric authentication
  - Form validation

## Key Features

- Login screen
- Registration screen
- Protected home screen
- Token-based auth
- Biometric login (Face ID/Touch ID)
- Auto-login on app start

## How to Run

```bash
cd examples/auth-flow
bun install
bun vue-native dev
```

## Key Concepts

### Auth State Management

```typescript
const user = ref<User | null>(null)
const token = ref<string | null>(null)

const isAuthenticated = computed(() => !!token.value)
```

### Token Storage

```typescript
const { setItem, getItem } = useAsyncStorage()

// Save token
await setItem('auth_token', token.value)

// Load token on startup
const saved = await getItem('auth_token')
if (saved) {
  token.value = saved
}
```

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

```typescript
const { authenticate } = useBiometry()

const result = await authenticate({
  reason: 'Authenticate to login',
})

if (result.success) {
  // Login successful
  await loginWithBiometry()
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
│   ├── router.ts
│   ├── stores/
│   │   └── auth.ts
│   └── views/
│       ├── LoginView.vue
│       ├── RegisterView.vue
│       └── HomeView.vue
├── native/
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
