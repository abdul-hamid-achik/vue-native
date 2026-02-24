# useBiometry

Biometric authentication using Face ID, Touch ID (iOS), or the device biometric sensor (Android). Provides methods to check availability, detect the biometry type, and prompt the user to authenticate.

## Usage

```vue
<script setup>
import { useBiometry } from '@thelacanians/vue-native-runtime'

const { authenticate, getSupportedBiometry, isAvailable } = useBiometry()
</script>
```

## API

```ts
useBiometry(): {
  authenticate: (reason?: string) => Promise<BiometryResult>
  getSupportedBiometry: () => Promise<BiometryType>
  isAvailable: () => Promise<boolean>
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `authenticate` | `(reason?: string) => Promise<BiometryResult>` | Prompt the user for biometric authentication. The `reason` string is displayed in the system prompt. Defaults to `"Authenticate"`. |
| `getSupportedBiometry` | `() => Promise<BiometryType>` | Returns the type of biometric hardware available on the device. |
| `isAvailable` | `() => Promise<boolean>` | Returns `true` if biometric authentication is available and enrolled. |

### Types

```ts
type BiometryType = 'faceID' | 'touchID' | 'opticID' | 'none'

interface BiometryResult {
  success: boolean
  error?: string
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses the `LocalAuthentication` framework (`LAContext`). Supports Face ID, Touch ID, and Optic ID. |
| Android | Uses `BiometricManager` for availability checks. `authenticate` requires an Activity-level `BiometricPrompt` — override `VueNativeActivity.onAuthenticateRequest()` to provide it. |

## Example

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useBiometry } from '@thelacanians/vue-native-runtime'

const { authenticate, getSupportedBiometry, isAvailable } = useBiometry()
const biometryType = ref('none')
const available = ref(false)
const status = ref('')

onMounted(async () => {
  biometryType.value = await getSupportedBiometry()
  available.value = await isAvailable()
})

async function handleAuth() {
  status.value = 'Authenticating...'
  const result = await authenticate('Confirm to view sensitive data')
  if (result.success) {
    status.value = 'Authenticated!'
  } else {
    status.value = result.error ?? 'Authentication failed'
  }
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold', marginBottom: 12 }">
      Biometric Auth
    </VText>
    <VText>Type: {{ biometryType }}</VText>
    <VText>Available: {{ available ? 'Yes' : 'No' }}</VText>
    <VText v-if="status" :style="{ marginTop: 8 }">{{ status }}</VText>
    <VButton
      v-if="available"
      :onPress="handleAuth"
      :style="{ marginTop: 16 }"
    >
      <VText>Authenticate</VText>
    </VButton>
  </VView>
</template>
```

## Notes

- On iOS, add `NSFaceIDUsageDescription` to your `Info.plist` to explain why your app uses Face ID. Without this key, the system will terminate your app when Face ID is triggered.
- On Android, `getSupportedBiometry` returns `"faceID"` as a generic label when strong biometrics are available (Android does not distinguish between face and fingerprint at the API level). It returns `"biometric"` when hardware is present but not enrolled.
- On Android, `authenticate` requires Activity-level integration with `BiometricPrompt`. The base `CameraModule` stub returns an error — override `VueNativeActivity.onAuthenticateRequest()` to provide the actual prompt.
- This composable has no reactive state and no cleanup. All methods return Promises.
