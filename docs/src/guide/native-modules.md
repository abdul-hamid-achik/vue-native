# Native Modules

Native modules expose device capabilities to your Vue code via composables.

## Available composables

### Device & System

```ts
import { useNetwork, useAppState, useColorScheme, useDeviceInfo } from '@thelacanians/runtime'

const { isConnected, connectionType } = useNetwork()
const { state } = useAppState()          // 'active' | 'inactive' | 'background'
const { colorScheme, isDark } = useColorScheme()
const { model, screenWidth, screenHeight } = useDeviceInfo()
```

### Storage

```ts
import { useAsyncStorage } from '@thelacanians/runtime'

const { getItem, setItem, removeItem } = useAsyncStorage()

await setItem('key', 'value')
const value = await getItem('key')
```

### Sensors & Hardware

```ts
import { useGeolocation, useBiometry, useHaptics } from '@thelacanians/runtime'

const { coords, getCurrentPosition } = useGeolocation()
const { authenticate, getSupportedBiometry } = useBiometry()
const { vibrate } = useHaptics()
```

### Media

```ts
import { useCamera } from '@thelacanians/runtime'

const { launchCamera, launchImageLibrary } = useCamera()
```

### Permissions

```ts
import { usePermissions } from '@thelacanians/runtime'

const { request, check } = usePermissions()
const status = await request('camera')  // 'granted' | 'denied' | 'restricted'
```

### UI

```ts
import { useKeyboard, useClipboard, useShare, useLinking, useAnimation, useHttp } from '@thelacanians/runtime'

const { isVisible, height } = useKeyboard()
const { copy, paste } = useClipboard()
const { share } = useShare()
const { openURL, canOpenURL } = useLinking()
const { timing, spring } = useAnimation()
const http = useHttp({ baseURL: 'https://api.example.com' })
```

### Notifications

```ts
import { useNotifications } from '@thelacanians/runtime'

const { requestPermission, scheduleLocal, onNotification } = useNotifications()
await scheduleLocal({ title: 'Reminder', body: 'Hello!', delay: 5 })
```
