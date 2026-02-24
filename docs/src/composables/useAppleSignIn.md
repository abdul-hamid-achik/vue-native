# useAppleSignIn

Apple Sign In composable backed by `ASAuthorizationAppleIDProvider` on iOS. Provides a simple API for authenticating users with their Apple ID.

## Setup

### iOS

1. Enable "Sign in with Apple" capability in your Xcode project:
   - Select your target > Signing & Capabilities > + Capability > Sign in with Apple

2. No additional dependencies required -- uses the built-in `AuthenticationServices` framework.

### Android

Apple Sign In is not natively supported on Android. Use a web-based Apple OAuth flow or handle it server-side. The composable will return an error if `signIn()` is called on Android.

## Usage

```vue
<script setup>
import { useAppleSignIn } from '@thelacanians/vue-native-runtime'

const { signIn, signOut, user, isAuthenticated, error } = useAppleSignIn()

async function handleLogin() {
  const result = await signIn()
  if (result.success) {
    console.log('Welcome', result.user.fullName)
    console.log('Token:', result.user.identityToken)
    // Send identityToken to your backend for verification
  } else {
    console.log('Sign in failed:', result.error)
  }
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VView v-if="!isAuthenticated">
      <VButton :onPress="handleLogin">
        <VText>Sign in with Apple</VText>
      </VButton>
    </VView>

    <VView v-else>
      <VText>Welcome, {{ user?.fullName || 'User' }}</VText>
      <VText>{{ user?.email }}</VText>
      <VButton :onPress="signOut">
        <VText>Sign Out</VText>
      </VButton>
    </VView>

    <VText v-if="error" :style="{ color: 'red', marginTop: 10 }">{{ error }}</VText>
  </VView>
</template>
```

## API

```ts
useAppleSignIn(): {
  signIn: () => Promise<AuthResult>
  signOut: () => Promise<void>
  user: Ref<SocialUser | null>
  isAuthenticated: Ref<boolean>
  error: Ref<string | null>
}
```

### Reactive State

| Property | Type | Description |
|----------|------|-------------|
| `user` | `Ref<SocialUser \| null>` | The authenticated user, or `null`. |
| `isAuthenticated` | `Ref<boolean>` | `true` if the user is signed in. |
| `error` | `Ref<string \| null>` | Last error message, or `null`. |

### Methods

#### `signIn()`

Present the Apple Sign In sheet. Returns an `AuthResult` with the user info on success.

Returns `Promise<AuthResult>`.

#### `signOut()`

Clear the cached Apple credential. Does not revoke the token server-side.

### Types

#### SocialUser

| Property | Type | Description |
|----------|------|-------------|
| `userId` | `string` | Unique user identifier (stable across sign-ins). |
| `email` | `string?` | User's email (only provided on first sign-in). |
| `fullName` | `string?` | User's full name (only provided on first sign-in). |
| `identityToken` | `string?` | JWT identity token for server-side verification. |
| `authorizationCode` | `string?` | Authorization code for server-side token exchange. |
| `provider` | `'apple' \| 'google'` | The authentication provider. |

#### AuthResult

| Property | Type | Description |
|----------|------|-------------|
| `success` | `boolean` | Whether authentication succeeded. |
| `user` | `SocialUser?` | The authenticated user (if successful). |
| `error` | `string?` | Error message (if failed). |

## Session Persistence

The composable automatically checks for an existing Apple credential on creation. If a valid session exists, `user` and `isAuthenticated` are populated immediately.

If the user revokes their Apple ID credential (via Settings > Apple ID > Password & Security), the composable automatically clears the session and fires the `auth:appleCredentialRevoked` event.

## Backend Verification

Apple provides a JWT `identityToken` that you should verify on your backend:

```vue
<script setup>
import { useAppleSignIn } from '@thelacanians/vue-native-runtime'
import { useHttp } from '@thelacanians/vue-native-runtime'

const { signIn } = useAppleSignIn()
const { post } = useHttp()

async function loginWithApple() {
  const result = await signIn()
  if (result.success) {
    // Send token to your backend
    await post('/api/auth/apple', {
      identityToken: result.user.identityToken,
      authorizationCode: result.user.authorizationCode,
    })
  }
}
</script>
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Full support via `ASAuthorizationAppleIDProvider`. Requires iOS 13.0+. |
| Android | Not natively supported. Returns an error suggesting web-based OAuth. |

## Notes

- Apple only provides the user's email and full name on the **first sign-in**. Subsequent sign-ins only return the `userId`. Store the email/name on your backend during the first sign-in.
- The `identityToken` is a short-lived JWT. Exchange it for a long-lived session token on your backend.
- The composable automatically detects credential revocation and clears the local session.
- Cleanup of event listeners happens automatically when the component is unmounted.
