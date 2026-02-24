# Security

This guide covers security best practices for Vue Native apps, including certificate pinning, secure storage, network hardening, authentication flows, and bundle integrity.

## Certificate Pinning

Certificate pinning prevents man-in-the-middle attacks by verifying that a server's TLS certificate matches a known hash. Vue Native supports per-domain SPKI (Subject Public Key Info) pinning on both platforms -- iOS via a custom `URLSession` delegate and Android via OkHttp's `CertificatePinner`.

### Generating SPKI Hashes

Extract the SHA-256 hash of your server's public key:

```bash
openssl s_client -connect api.example.com:443 -servername api.example.com </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

Prefix the output with `sha256/` when configuring pins.

::: tip
Always pin at least two hashes -- the current certificate and a backup. If you only pin one and the certificate rotates, your app will be unable to connect until you ship an update.
:::

### Configuring Pins

Pass a `pins` object to `useHttp`. Each key is a domain, and the value is an array of `sha256/` hashes:

```ts
import { useHttp } from '@thelacanians/vue-native-runtime'

const http = useHttp({
  baseURL: 'https://api.example.com',
  pins: {
    'api.example.com': [
      'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // current
      'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // backup
    ],
  },
})

const users = await http.get('/users')
```

All subsequent `fetch` requests to a pinned domain validate the server certificate against the provided hashes. A mismatch causes the request to fail immediately.

::: danger
If all pinned hashes become invalid (e.g., the server rotates certificates and you have no backup pin), the app cannot reach that domain. Always include a backup pin.
:::

## Secure Storage

### When to Use Each

| Data | Use | Why |
|------|-----|-----|
| Auth tokens, refresh tokens | `useSecureStorage` | Encrypted at rest (Keychain / EncryptedSharedPreferences) |
| API keys, credentials | `useSecureStorage` | Must not be readable by other apps or file explorers |
| User preferences, theme | `useAsyncStorage` | Not sensitive; encryption overhead unnecessary |
| Cache data, drafts | `useAsyncStorage` | Acceptable if exposed; no security requirement |

### Using Secure Storage

```ts
import { useSecureStorage } from '@thelacanians/vue-native-runtime'

const { getItem, setItem, removeItem, clear } = useSecureStorage()

// Store a token
await setItem('auth_token', token)

// Retrieve it later
const token = await getItem('auth_token')

// Remove on logout
await removeItem('auth_token')
```

On iOS, values are stored in the Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). On Android, values use `EncryptedSharedPreferences` backed by the Android Keystore.

::: warning
Never store sensitive data with `useAsyncStorage`. It uses unencrypted `UserDefaults` (iOS) and `SharedPreferences` (Android), which can be read on rooted/jailbroken devices or extracted from unencrypted backups.
:::

## Network Security

### iOS: App Transport Security

iOS enforces HTTPS by default through App Transport Security (ATS). Vue Native projects ship with ATS enabled -- no configuration needed. All `fetch` requests to HTTP URLs will be blocked by the OS unless you add an exception.

Do not add blanket ATS exceptions (`NSAllowsArbitraryLoads`). If you must connect to a legacy HTTP server, use a per-domain exception:

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>legacy-api.example.com</key>
        <dict>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Android: Network Security Configuration

Vue Native projects include a `network_security_config.xml` that permits cleartext only for localhost (dev server):

```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

All other domains default to HTTPS-only. Do not add `cleartextTrafficPermitted="true"` to the base config.

## Authentication Best Practices

### Token Storage

Store tokens in secure storage, never in `AsyncStorage`:

```ts
import { useSecureStorage, useHttp } from '@thelacanians/vue-native-runtime'

const { getItem, setItem, removeItem } = useSecureStorage()
const http = useHttp({ baseURL: 'https://api.example.com' })

async function login(email: string, password: string) {
  const { data } = await http.post('/auth/login', { email, password })
  await setItem('access_token', data.accessToken)
  await setItem('refresh_token', data.refreshToken)
}

async function logout() {
  await removeItem('access_token')
  await removeItem('refresh_token')
}
```

### Token Refresh Flow

Intercept 401 responses, refresh the token, and retry:

```ts
async function authenticatedRequest(method: string, url: string, body?: any) {
  const token = await getItem('access_token')
  try {
    return await http[method](url, body, { Authorization: `Bearer ${token}` })
  } catch (err) {
    if (err.status === 401) {
      const refreshToken = await getItem('refresh_token')
      const { data } = await http.post('/auth/refresh', { token: refreshToken })
      await setItem('access_token', data.accessToken)
      return await http[method](url, body, { Authorization: `Bearer ${data.accessToken}` })
    }
    throw err
  }
}
```

### Biometric Gate

Use `useBiometry` to require Face ID, Touch ID, or fingerprint before sensitive operations:

```ts
import { useBiometry } from '@thelacanians/vue-native-runtime'

const { authenticate, isAvailable } = useBiometry()

async function accessSensitiveData() {
  if (!(await isAvailable())) return promptForPin()

  const result = await authenticate('Confirm your identity')
  if (!result.success) throw new Error('Authentication failed')

  const token = await getItem('access_token')
  return http.get('/account/details', { Authorization: `Bearer ${token}` })
}
```

### Social Authentication

When using `useAppleSignIn` or `useGoogleSignIn`, exchange the identity token for your own backend token. Never use the provider's token directly for API calls:

```ts
import { useAppleSignIn, useHttp, useSecureStorage } from '@thelacanians/vue-native-runtime'

const { signIn } = useAppleSignIn()
const http = useHttp({ baseURL: 'https://api.example.com' })
const { setItem } = useSecureStorage()

async function handleAppleLogin() {
  const result = await signIn()
  if (!result.success) return
  const { data } = await http.post('/auth/apple', {
    identityToken: result.user.identityToken,
    authorizationCode: result.user.authorizationCode,
  })
  await setItem('access_token', data.accessToken)
  await setItem('refresh_token', data.refreshToken)
}
```

## Bundle Security

### OTA Update Verification

The `useOTAUpdate` composable verifies downloaded bundles against a SHA-256 hash provided by your update server. The native module rejects any bundle whose computed hash does not match:

```ts
import { useOTAUpdate } from '@thelacanians/vue-native-runtime'

const { checkForUpdate, downloadUpdate, applyUpdate } = useOTAUpdate(
  'https://updates.example.com/api/check'
)

const info = await checkForUpdate()
if (info.updateAvailable) {
  await downloadUpdate()  // SHA-256 verified by native module
  await applyUpdate()     // New bundle loads on next launch
}
```

::: tip
Serve OTA bundles over HTTPS with certificate pinning enabled. Combine transport security (TLS + pinning) with content verification (SHA-256) for defense in depth.
:::

### Code Signing

The JS bundle embedded in your app is covered by the platform's binary code signature. OTA-delivered bundles are verified by SHA-256 hash instead, since they arrive after installation.

## Common Pitfalls

::: danger
**Never log tokens or credentials.** `console.log` output is visible in Xcode's console, Android Logcat, and the Safari/Chrome debugger. Strip log statements before shipping.
:::

**Do not embed secrets in JavaScript.** Your JS bundle is a plain text file inside the app container. Anyone with the IPA or APK can extract and read it. API keys and credentials belong on your server.

**Do not disable ATS or cleartext protections globally.** Setting `NSAllowsArbitraryLoads` or `cleartextTrafficPermitted="true"` at the base level removes HTTPS enforcement for your entire app.

**Rotate certificate pins before they expire.** Track expiration dates and push an update with the new hash before the old certificate is decommissioned.

**Persist refresh tokens in secure storage.** If tokens live only in memory, the user must re-authenticate every time the OS terminates the app.

**Validate all server responses.** Malformed or malicious responses should not crash the app or corrupt stored state.
