# useGoogleSignIn

Google Sign In composable backed by `ASWebAuthenticationSession` (iOS) and Credential Manager API (Android). Provides a simple API for authenticating users with their Google account.

## Setup

### Create OAuth Client ID

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Navigate to APIs & Services > Credentials
4. Create an OAuth 2.0 Client ID

### iOS

1. Create an **iOS** OAuth client ID in Google Cloud Console
2. Add the reversed client ID as a URL scheme in your Xcode project:
   - Select your target > Info > URL Types
   - Add a new URL type with the reversed client ID (e.g. `com.googleusercontent.apps.YOUR_CLIENT_ID`)

### Android

1. Create an **Web application** OAuth client ID in Google Cloud Console (used as `serverClientId`)
2. Create an **Android** OAuth client ID with your app's SHA-1 fingerprint
3. Add the credential dependencies to your `build.gradle`:

```groovy
dependencies {
    implementation 'androidx.credentials:credentials:1.3.0'
    implementation 'com.google.android.libraries.identity.googleid:googleid:1.1.0'
}
```

## Usage

```vue
<script setup>
import { useGoogleSignIn } from '@thelacanians/vue-native-runtime'

const { signIn, signOut, user, isAuthenticated, error } = useGoogleSignIn(
  'YOUR_CLIENT_ID.apps.googleusercontent.com'
)

async function handleLogin() {
  const result = await signIn()
  if (result.success) {
    console.log('Welcome', result.user.fullName)
    console.log('Email:', result.user.email)
  }
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VView v-if="!isAuthenticated">
      <VButton :onPress="handleLogin">
        <VText>Sign in with Google</VText>
      </VButton>
    </VView>

    <VView v-else>
      <VText>Welcome, {{ user?.fullName }}</VText>
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
useGoogleSignIn(clientId: string): {
  signIn: () => Promise<AuthResult>
  signOut: () => Promise<void>
  user: Ref<SocialUser | null>
  isAuthenticated: Ref<boolean>
  error: Ref<string | null>
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `clientId` | `string` | Your Google OAuth 2.0 client ID. |

### Reactive State

| Property | Type | Description |
|----------|------|-------------|
| `user` | `Ref<SocialUser \| null>` | The authenticated user, or `null`. |
| `isAuthenticated` | `Ref<boolean>` | `true` if the user is signed in. |
| `error` | `Ref<string \| null>` | Last error message, or `null`. |

### Methods

#### `signIn()`

Present the Google Sign In flow. On iOS, this opens a web authentication session. On Android, this uses the Credential Manager API.

Returns `Promise<AuthResult>`.

#### `signOut()`

Clear the cached Google credential.

### Types

See [useAppleSignIn](./useAppleSignIn.md) for `SocialUser` and `AuthResult` type definitions.

## Backend Integration Example

```vue
<script setup>
import { useGoogleSignIn } from '@thelacanians/vue-native-runtime'
import { useHttp } from '@thelacanians/vue-native-runtime'

const CLIENT_ID = 'YOUR_CLIENT_ID.apps.googleusercontent.com'

const { signIn, user, isAuthenticated } = useGoogleSignIn(CLIENT_ID)
const { post } = useHttp()

async function loginWithGoogle() {
  const result = await signIn()
  if (result.success) {
    // Exchange the identity token with your backend
    const response = await post('/api/auth/google', {
      identityToken: result.user.identityToken,
    })
    console.log('Server session:', response.data)
  }
}
</script>
```

## Combined Social Auth Example

```vue
<script setup>
import { useAppleSignIn, useGoogleSignIn, usePlatform } from '@thelacanians/vue-native-runtime'

const { isIOS } = usePlatform()
const apple = useAppleSignIn()
const google = useGoogleSignIn('YOUR_CLIENT_ID.apps.googleusercontent.com')
</script>

<template>
  <VView :style="{ flex: 1, justifyContent: 'center', padding: 20 }">
    <VButton v-if="isIOS" :onPress="apple.signIn" :style="{ marginBottom: 10 }">
      <VText>Sign in with Apple</VText>
    </VButton>

    <VButton :onPress="google.signIn">
      <VText>Sign in with Google</VText>
    </VButton>
  </VView>
</template>
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `ASWebAuthenticationSession` for a zero-dependency OAuth flow. |
| Android | Uses Credential Manager API with `GoogleIdTokenCredential`. |

## Notes

- The `clientId` parameter is required. On iOS, it uses a web-based OAuth flow. On Android, it is passed to the Credential Manager as the `serverClientId`.
- The composable automatically checks for an existing Google session on creation.
- On iOS, the OAuth flow returns an authorization code. Exchange this code server-side for access and refresh tokens.
- On Android, the Credential Manager returns a Google ID token directly.
- Session state is cleared locally on `signOut()`. You may also need to revoke the token server-side.
- Cleanup of event listeners happens automatically when the component is unmounted.
