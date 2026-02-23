# Native Modules

Native modules expose device capabilities to your Vue code via composables.

## Available composables

### Device & System

```ts
import { useNetwork, useAppState, useColorScheme, useDeviceInfo } from '@vue-native/runtime'

const { isConnected, connectionType } = useNetwork()
const { state } = useAppState()          // 'active' | 'inactive' | 'background'
const { colorScheme, isDark } = useColorScheme()
const { model, screenWidth, screenHeight } = useDeviceInfo()
```

### Storage

```ts
import { useAsyncStorage } from '@vue-native/runtime'

const { getItem, setItem, removeItem } = useAsyncStorage()

await setItem('key', 'value')
const value = await getItem('key')
```

### Sensors & Hardware

```ts
import { useGeolocation, useBiometry, useHaptics } from '@vue-native/runtime'

const { coords, getCurrentPosition } = useGeolocation()
const { authenticate, getSupportedBiometry } = useBiometry()
const { vibrate } = useHaptics()
```

### Media

```ts
import { useCamera } from '@vue-native/runtime'

const { launchCamera, launchImageLibrary } = useCamera()
```

### Permissions

```ts
import { usePermissions } from '@vue-native/runtime'

const { request, check } = usePermissions()
const status = await request('camera')  // 'granted' | 'denied' | 'restricted'
```

### UI

```ts
import { useKeyboard, useClipboard, useShare, useLinking, useAnimation, useHttp } from '@vue-native/runtime'

const { isVisible, height } = useKeyboard()
const { copy, paste } = useClipboard()
const { share } = useShare()
const { openURL, canOpenURL } = useLinking()
const { timing, spring } = useAnimation()
const http = useHttp({ baseURL: 'https://api.example.com' })
```

### Notifications

```ts
import { useNotifications } from '@vue-native/runtime'

const { requestPermission, scheduleLocal, onNotification } = useNotifications()
await scheduleLocal({ title: 'Reminder', body: 'Hello!', delay: 5 })
```
