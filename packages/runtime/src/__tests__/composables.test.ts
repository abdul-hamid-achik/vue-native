/**
 * Composable tests — verifies that each composable calls the correct
 * NativeBridge module/method and handles reactive state and cleanup.
 */
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { installMockBridge } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')

// We need to spy on NativeBridge methods
let invokeModuleSpy: ReturnType<typeof vi.spyOn>
let onGlobalEventSpy: ReturnType<typeof vi.spyOn>

// Track registered global event handlers for manual triggering
const globalEventHandlers: Map<string, Array<(payload: any) => void>> = new Map()
const _originalOnGlobalEvent = NativeBridge.onGlobalEvent.bind(NativeBridge)

describe('Composables', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()

    // Clear tracked handlers
    globalEventHandlers.clear()

    // Mock invokeNativeModule to return resolved promises
    invokeModuleSpy = vi.spyOn(NativeBridge, 'invokeNativeModule').mockImplementation(
      () => Promise.resolve(undefined as any),
    )

    // Spy on onGlobalEvent but let it work and also track handlers
    onGlobalEventSpy = vi.spyOn(NativeBridge, 'onGlobalEvent').mockImplementation(
      (event: string, handler: (payload: any) => void) => {
        if (!globalEventHandlers.has(event)) {
          globalEventHandlers.set(event, [])
        }
        globalEventHandlers.get(event)!.push(handler)
        return () => {
          const handlers = globalEventHandlers.get(event)
          if (handlers) {
            const idx = handlers.indexOf(handler)
            if (idx > -1) handlers.splice(idx, 1)
          }
        }
      },
    )
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  function triggerGlobalEvent(event: string, payload: any) {
    const handlers = globalEventHandlers.get(event) ?? []
    for (const handler of handlers) {
      handler(payload)
    }
  }

  // ---------------------------------------------------------------------------
  // useHaptics
  // ---------------------------------------------------------------------------
  describe('useHaptics', () => {
    it('vibrate calls Haptics.vibrate', async () => {
      const { useHaptics } = await import('../composables/useHaptics')
      const { vibrate } = useHaptics()
      await vibrate('heavy')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Haptics', 'vibrate', ['heavy'])
    })

    it('notificationFeedback calls Haptics.notificationFeedback', async () => {
      const { useHaptics } = await import('../composables/useHaptics')
      const { notificationFeedback } = useHaptics()
      await notificationFeedback('error')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Haptics', 'notificationFeedback', ['error'])
    })

    it('selectionChanged calls Haptics.selectionChanged', async () => {
      const { useHaptics } = await import('../composables/useHaptics')
      const { selectionChanged } = useHaptics()
      await selectionChanged()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Haptics', 'selectionChanged', [])
    })
  })

  // ---------------------------------------------------------------------------
  // useAsyncStorage
  // ---------------------------------------------------------------------------
  describe('useAsyncStorage', () => {
    it('getItem calls AsyncStorage.getItem', async () => {
      const { useAsyncStorage } = await import('../composables/useAsyncStorage')
      const { getItem } = useAsyncStorage()
      await getItem('key1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('AsyncStorage', 'getItem', ['key1'])
    })

    it('setItem calls AsyncStorage.setItem', async () => {
      const { useAsyncStorage } = await import('../composables/useAsyncStorage')
      const { setItem } = useAsyncStorage()
      await setItem('key1', 'value1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('AsyncStorage', 'setItem', ['key1', 'value1'])
    })

    it('removeItem calls AsyncStorage.removeItem', async () => {
      const { useAsyncStorage } = await import('../composables/useAsyncStorage')
      const { removeItem } = useAsyncStorage()
      await removeItem('key1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('AsyncStorage', 'removeItem', ['key1'])
    })

    it('getAllKeys calls AsyncStorage.getAllKeys', async () => {
      const { useAsyncStorage } = await import('../composables/useAsyncStorage')
      const { getAllKeys } = useAsyncStorage()
      await getAllKeys()
      expect(invokeModuleSpy).toHaveBeenCalledWith('AsyncStorage', 'getAllKeys', [])
    })

    it('clear calls AsyncStorage.clear', async () => {
      const { useAsyncStorage } = await import('../composables/useAsyncStorage')
      const { clear } = useAsyncStorage()
      await clear()
      expect(invokeModuleSpy).toHaveBeenCalledWith('AsyncStorage', 'clear', [])
    })
  })

  // ---------------------------------------------------------------------------
  // useClipboard
  // ---------------------------------------------------------------------------
  describe('useClipboard', () => {
    it('copy calls Clipboard.copy', async () => {
      const { useClipboard } = await import('../composables/useClipboard')
      const { copy } = useClipboard()
      await copy('hello')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Clipboard', 'copy', ['hello'])
    })

    it('paste calls Clipboard.paste and updates content ref', async () => {
      invokeModuleSpy.mockResolvedValueOnce('pasted-text')
      const { useClipboard } = await import('../composables/useClipboard')
      const { paste, content } = useClipboard()
      const result = await paste()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Clipboard', 'paste', [])
      expect(result).toBe('pasted-text')
      expect(content.value).toBe('pasted-text')
    })
  })

  // ---------------------------------------------------------------------------
  // useAnimation
  // ---------------------------------------------------------------------------
  describe('useAnimation', () => {
    it('timing calls Animation.timing', async () => {
      const { useAnimation } = await import('../composables/useAnimation')
      const { timing } = useAnimation()
      await timing(42, { opacity: 1 }, { duration: 300 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Animation', 'timing', [42, { opacity: 1 }, { duration: 300 }])
    })

    it('spring calls Animation.spring', async () => {
      const { useAnimation } = await import('../composables/useAnimation')
      const { spring } = useAnimation()
      await spring(42, { scale: 1 }, { tension: 40 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Animation', 'spring', [42, { scale: 1 }, { tension: 40 }])
    })

    it('keyframe calls Animation.keyframe', async () => {
      const { useAnimation } = await import('../composables/useAnimation')
      const { keyframe } = useAnimation()
      const steps = [{ offset: 0, opacity: 0 }, { offset: 1, opacity: 1 }]
      await keyframe(42, steps, { duration: 600 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Animation', 'keyframe', [42, steps, { duration: 600 }])
    })

    it('sequence calls Animation.sequence', async () => {
      const { useAnimation } = await import('../composables/useAnimation')
      const { sequence } = useAnimation()
      const animations = [
        { type: 'timing' as const, viewId: 1, toStyles: { opacity: 0 }, options: { duration: 200 } },
      ]
      await sequence(animations)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Animation', 'sequence', [animations])
    })

    it('parallel calls Animation.parallel', async () => {
      const { useAnimation } = await import('../composables/useAnimation')
      const { parallel } = useAnimation()
      const animations = [
        { type: 'timing' as const, viewId: 1, toStyles: { opacity: 0 }, options: { duration: 200 } },
      ]
      await parallel(animations)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Animation', 'parallel', [animations])
    })

    it('fadeIn calls timing with opacity: 1', async () => {
      const { useAnimation } = await import('../composables/useAnimation')
      const { fadeIn } = useAnimation()
      await fadeIn(42, 500)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Animation', 'timing', [42, { opacity: 1 }, { duration: 500 }])
    })

    it('fadeOut calls timing with opacity: 0', async () => {
      const { useAnimation } = await import('../composables/useAnimation')
      const { fadeOut } = useAnimation()
      await fadeOut(42)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Animation', 'timing', [42, { opacity: 0 }, { duration: 300 }])
    })
  })

  // ---------------------------------------------------------------------------
  // useFileSystem
  // ---------------------------------------------------------------------------
  describe('useFileSystem', () => {
    it('readFile calls FileSystem.readFile', async () => {
      const { useFileSystem } = await import('../composables/useFileSystem')
      const { readFile } = useFileSystem()
      await readFile('/docs/test.txt')
      expect(invokeModuleSpy).toHaveBeenCalledWith('FileSystem', 'readFile', ['/docs/test.txt', 'utf8'])
    })

    it('writeFile calls FileSystem.writeFile', async () => {
      const { useFileSystem } = await import('../composables/useFileSystem')
      const { writeFile } = useFileSystem()
      await writeFile('/docs/test.txt', 'hello')
      expect(invokeModuleSpy).toHaveBeenCalledWith('FileSystem', 'writeFile', ['/docs/test.txt', 'hello', 'utf8'])
    })

    it('deleteFile calls FileSystem.deleteFile', async () => {
      const { useFileSystem } = await import('../composables/useFileSystem')
      const { deleteFile } = useFileSystem()
      await deleteFile('/docs/test.txt')
      expect(invokeModuleSpy).toHaveBeenCalledWith('FileSystem', 'deleteFile', ['/docs/test.txt'])
    })

    it('exists calls FileSystem.exists', async () => {
      const { useFileSystem } = await import('../composables/useFileSystem')
      const { exists } = useFileSystem()
      await exists('/docs/test.txt')
      expect(invokeModuleSpy).toHaveBeenCalledWith('FileSystem', 'exists', ['/docs/test.txt'])
    })

    it('getDocumentsPath calls FileSystem.getDocumentsPath', async () => {
      const { useFileSystem } = await import('../composables/useFileSystem')
      const { getDocumentsPath } = useFileSystem()
      await getDocumentsPath()
      expect(invokeModuleSpy).toHaveBeenCalledWith('FileSystem', 'getDocumentsPath', [])
    })

    it('getCachesPath calls FileSystem.getCachesPath', async () => {
      const { useFileSystem } = await import('../composables/useFileSystem')
      const { getCachesPath } = useFileSystem()
      await getCachesPath()
      expect(invokeModuleSpy).toHaveBeenCalledWith('FileSystem', 'getCachesPath', [])
    })

    it('mkdir calls FileSystem.mkdir', async () => {
      const { useFileSystem } = await import('../composables/useFileSystem')
      const { mkdir } = useFileSystem()
      await mkdir('/docs/newdir')
      expect(invokeModuleSpy).toHaveBeenCalledWith('FileSystem', 'mkdir', ['/docs/newdir'])
    })
  })

  // ---------------------------------------------------------------------------
  // usePlatform
  // ---------------------------------------------------------------------------
  describe('usePlatform', () => {
    it('returns platform info', async () => {
      const { usePlatform } = await import('../composables/usePlatform')
      const { platform, isIOS, isAndroid } = usePlatform()
      // Since __PLATFORM__ is not defined, defaults to 'ios'
      expect(platform).toBe('ios')
      expect(isIOS).toBe(true)
      expect(isAndroid).toBe(false)
    })
  })

  // ---------------------------------------------------------------------------
  // useNetwork (reactive + global event)
  // ---------------------------------------------------------------------------
  describe('useNetwork', () => {
    it('subscribes to network:change global event', async () => {
      const { useNetwork } = await import('../composables/useNetwork')
      useNetwork()
      expect(onGlobalEventSpy).toHaveBeenCalledWith('network:change', expect.any(Function))
    })

    it('updates reactive state on network:change', async () => {
      const { useNetwork } = await import('../composables/useNetwork')
      const { isConnected, connectionType } = useNetwork()

      // Defaults
      expect(isConnected.value).toBe(true)

      // Simulate network change
      triggerGlobalEvent('network:change', { isConnected: false, connectionType: 'none' })

      expect(isConnected.value).toBe(false)
      expect(connectionType.value).toBe('none')
    })

    it('fetches initial status from Network.getStatus', async () => {
      const { useNetwork } = await import('../composables/useNetwork')
      useNetwork()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Network', 'getStatus')
    })
  })

  // ---------------------------------------------------------------------------
  // useAppState (reactive + global event)
  // ---------------------------------------------------------------------------
  describe('useAppState', () => {
    it('subscribes to appState:change global event', async () => {
      const { useAppState } = await import('../composables/useAppState')
      useAppState()
      expect(onGlobalEventSpy).toHaveBeenCalledWith('appState:change', expect.any(Function))
    })

    it('updates reactive state on appState:change', async () => {
      const { useAppState } = await import('../composables/useAppState')
      const { state } = useAppState()

      expect(state.value).toBe('active')
      triggerGlobalEvent('appState:change', { state: 'background' })
      expect(state.value).toBe('background')
    })
  })

  // ---------------------------------------------------------------------------
  // useColorScheme (reactive + global event)
  // ---------------------------------------------------------------------------
  describe('useColorScheme', () => {
    it('subscribes to colorScheme:change', async () => {
      const { useColorScheme } = await import('../composables/useColorScheme')
      useColorScheme()
      expect(onGlobalEventSpy).toHaveBeenCalledWith('colorScheme:change', expect.any(Function))
    })

    it('updates isDark on dark mode change', async () => {
      const { useColorScheme } = await import('../composables/useColorScheme')
      const { colorScheme, isDark } = useColorScheme()

      expect(colorScheme.value).toBe('light')
      expect(isDark.value).toBe(false)

      triggerGlobalEvent('colorScheme:change', { colorScheme: 'dark' })

      expect(colorScheme.value).toBe('dark')
      expect(isDark.value).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // useWebSocket (reactive + global events + lifecycle)
  // ---------------------------------------------------------------------------
  describe('useWebSocket', () => {
    it('auto-connects by default', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { status } = useWebSocket('wss://test.example.com')
      expect(status.value).toBe('CONNECTING')
      expect(invokeModuleSpy).toHaveBeenCalledWith('WebSocket', 'connect', expect.arrayContaining(['wss://test.example.com']))
    })

    it('does not connect if autoConnect is false', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { status } = useWebSocket('wss://test.example.com', { autoConnect: false })
      expect(status.value).toBe('CLOSED')
    })

    it('subscribes to websocket events', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      useWebSocket('wss://test.example.com')
      expect(onGlobalEventSpy).toHaveBeenCalledWith('websocket:open', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('websocket:message', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('websocket:close', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('websocket:error', expect.any(Function))
    })

    it('updates lastMessage on websocket:message', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { lastMessage, status } = useWebSocket('wss://test.example.com')

      // Get the connectionId from the connect call
      const connectCall = invokeModuleSpy.mock.calls.find(
        (c: unknown[]) => c[0] === 'WebSocket' && c[1] === 'connect',
      )
      const connectionId = connectCall?.[2]?.[1]

      // Simulate open
      triggerGlobalEvent('websocket:open', { connectionId })
      expect(status.value).toBe('OPEN')

      // Simulate message
      triggerGlobalEvent('websocket:message', { connectionId, data: 'hello world' })
      expect(lastMessage.value).toBe('hello world')
    })

    it('send calls WebSocket.send when open', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { send, status: _status } = useWebSocket('wss://test.example.com')

      const connectCall = invokeModuleSpy.mock.calls.find(
        (c: unknown[]) => c[0] === 'WebSocket' && c[1] === 'connect',
      )
      const connectionId = connectCall?.[2]?.[1]

      // Simulate open
      triggerGlobalEvent('websocket:open', { connectionId })

      invokeModuleSpy.mockClear()
      send('hello')
      expect(invokeModuleSpy).toHaveBeenCalledWith('WebSocket', 'send', [connectionId, 'hello'])
    })

    it('send does nothing when not open', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { send } = useWebSocket('wss://test.example.com', { autoConnect: false })

      invokeModuleSpy.mockClear()
      send('hello')
      // Should not have called WebSocket.send
      const sendCalls = invokeModuleSpy.mock.calls.filter((c: unknown[]) => c[0] === 'WebSocket' && c[1] === 'send')
      expect(sendCalls).toHaveLength(0)
    })

    it('send stringifies objects', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { send } = useWebSocket('wss://test.example.com')

      const connectCall = invokeModuleSpy.mock.calls.find(
        (c: unknown[]) => c[0] === 'WebSocket' && c[1] === 'connect',
      )
      const connectionId = connectCall?.[2]?.[1]
      triggerGlobalEvent('websocket:open', { connectionId })

      invokeModuleSpy.mockClear()
      send({ type: 'ping' })
      expect(invokeModuleSpy).toHaveBeenCalledWith('WebSocket', 'send', [connectionId, '{"type":"ping"}'])
    })
  })

  // ---------------------------------------------------------------------------
  // useDatabase
  // ---------------------------------------------------------------------------
  describe('useDatabase', () => {
    it('execute opens the database and runs SQL', async () => {
      const { useDatabase } = await import('../composables/useDatabase')
      const db = useDatabase('testdb')
      await db.execute('CREATE TABLE test (id INTEGER)')
      // First call opens, second executes
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'open', ['testdb'])
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'execute', ['testdb', 'CREATE TABLE test (id INTEGER)', []])
    })

    it('query opens the database and runs query', async () => {
      const { useDatabase } = await import('../composables/useDatabase')
      const db = useDatabase('testdb')
      await db.query('SELECT * FROM test')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'open', ['testdb'])
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'query', ['testdb', 'SELECT * FROM test', []])
    })

    it('close calls Database.close', async () => {
      const { useDatabase } = await import('../composables/useDatabase')
      const db = useDatabase('testdb')
      // Must open first
      await db.execute('SELECT 1')
      await db.close()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'close', ['testdb'])
    })

    it('uses "default" as default database name', async () => {
      const { useDatabase } = await import('../composables/useDatabase')
      const db = useDatabase()
      await db.execute('SELECT 1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'open', ['default'])
    })
  })

  // ---------------------------------------------------------------------------
  // useAudio
  // ---------------------------------------------------------------------------
  describe('useAudio', () => {
    it('play calls Audio.play and sets isPlaying', async () => {
      invokeModuleSpy.mockResolvedValue({ duration: 120 })
      const { useAudio } = await import('../composables/useAudio')
      const { play, isPlaying, duration } = useAudio()
      await play('https://example.com/song.mp3', { volume: 0.8 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'play', ['https://example.com/song.mp3', { volume: 0.8 }])
      expect(isPlaying.value).toBe(true)
      expect(duration.value).toBe(120)
    })

    it('pause calls Audio.pause and clears isPlaying', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { pause, isPlaying } = useAudio()
      await pause()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'pause', [])
      expect(isPlaying.value).toBe(false)
    })

    it('stop calls Audio.stop and resets state', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { stop, isPlaying, position, duration } = useAudio()
      await stop()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'stop', [])
      expect(isPlaying.value).toBe(false)
      expect(position.value).toBe(0)
      expect(duration.value).toBe(0)
    })

    it('seek calls Audio.seek', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { seek } = useAudio()
      await seek(30)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'seek', [30])
    })

    it('startRecording calls Audio.startRecording', async () => {
      invokeModuleSpy.mockResolvedValue({ uri: '/tmp/rec.m4a' })
      const { useAudio } = await import('../composables/useAudio')
      const { startRecording, isRecording } = useAudio()
      const uri = await startRecording({ quality: 'high' })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'startRecording', [{ quality: 'high' }])
      expect(isRecording.value).toBe(true)
      expect(uri).toBe('/tmp/rec.m4a')
    })

    it('stopRecording calls Audio.stopRecording and returns result', async () => {
      invokeModuleSpy.mockResolvedValue({ uri: '/tmp/rec.m4a', duration: 5.5 })
      const { useAudio } = await import('../composables/useAudio')
      const { stopRecording, isRecording } = useAudio()
      const result = await stopRecording()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'stopRecording', [])
      expect(isRecording.value).toBe(false)
      expect(result).toEqual({ uri: '/tmp/rec.m4a', duration: 5.5 })
    })

    it('updates position/duration on audio:progress event', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { position, duration } = useAudio()
      triggerGlobalEvent('audio:progress', { currentTime: 15, duration: 120 })
      expect(position.value).toBe(15)
      expect(duration.value).toBe(120)
    })

    it('resets isPlaying on audio:complete event', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const audio = useAudio()
      // Manually set playing state
      triggerGlobalEvent('audio:complete', {})
      expect(audio.isPlaying.value).toBe(false)
      expect(audio.position.value).toBe(0)
    })

    it('sets error on audio:error event', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { error } = useAudio()
      triggerGlobalEvent('audio:error', { message: 'Playback failed' })
      expect(error.value).toBe('Playback failed')
    })
  })

  // ---------------------------------------------------------------------------
  // useSensors (useAccelerometer / useGyroscope)
  // ---------------------------------------------------------------------------
  describe('useAccelerometer', () => {
    it('start calls Sensors.startAccelerometer and subscribes to events', async () => {
      const { useAccelerometer } = await import('../composables/useSensors')
      const { start, x, y, z } = useAccelerometer({ interval: 50 })
      start()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Sensors', 'startAccelerometer', [50])
      expect(onGlobalEventSpy).toHaveBeenCalledWith('sensor:accelerometer', expect.any(Function))

      // Simulate sensor data
      triggerGlobalEvent('sensor:accelerometer', { x: 0.1, y: 0.2, z: 9.8 })
      expect(x.value).toBe(0.1)
      expect(y.value).toBe(0.2)
      expect(z.value).toBe(9.8)
    })

    it('stop calls Sensors.stopAccelerometer', async () => {
      const { useAccelerometer } = await import('../composables/useSensors')
      const { start, stop } = useAccelerometer()
      start()
      invokeModuleSpy.mockClear()
      stop()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Sensors', 'stopAccelerometer')
    })

    it('checks sensor availability on creation', async () => {
      const { useAccelerometer } = await import('../composables/useSensors')
      useAccelerometer()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Sensors', 'isAvailable', ['accelerometer'])
    })
  })

  describe('useGyroscope', () => {
    it('start calls Sensors.startGyroscope', async () => {
      const { useGyroscope } = await import('../composables/useSensors')
      const { start } = useGyroscope({ interval: 100 })
      start()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Sensors', 'startGyroscope', [100])
    })

    it('updates reactive data on sensor event', async () => {
      const { useGyroscope } = await import('../composables/useSensors')
      const { start, x, y, z } = useGyroscope()
      start()
      triggerGlobalEvent('sensor:gyroscope', { x: 1.1, y: 2.2, z: 3.3 })
      expect(x.value).toBe(1.1)
      expect(y.value).toBe(2.2)
      expect(z.value).toBe(3.3)
    })
  })

  // ---------------------------------------------------------------------------
  // useBackgroundTask
  // ---------------------------------------------------------------------------
  describe('useBackgroundTask', () => {
    it('scheduleTask calls BackgroundTask.scheduleTask', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { scheduleTask } = useBackgroundTask()
      await scheduleTask('com.myapp.sync', { type: 'refresh', requiresNetworkConnectivity: true })
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'scheduleTask', [
        'com.myapp.sync',
        'refresh',
        expect.objectContaining({ requiresNetworkConnectivity: true }),
      ])
    })

    it('cancelTask calls BackgroundTask.cancelTask', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { cancelTask } = useBackgroundTask()
      await cancelTask('com.myapp.sync')
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'cancelTask', ['com.myapp.sync'])
    })

    it('cancelAllTasks calls BackgroundTask.cancelAllTasks', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { cancelAllTasks } = useBackgroundTask()
      await cancelAllTasks()
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'cancelAllTasks', [])
    })

    it('completeTask calls BackgroundTask.completeTask', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { completeTask } = useBackgroundTask()
      await completeTask('com.myapp.sync')
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'completeTask', ['com.myapp.sync', true])
    })

    it('registerTask calls BackgroundTask.registerTask', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { registerTask } = useBackgroundTask()
      await registerTask('com.myapp.sync')
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'registerTask', ['com.myapp.sync'])
    })

    it('onTaskExecute receives background:taskExecute events', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { onTaskExecute } = useBackgroundTask()

      expect(onGlobalEventSpy).toHaveBeenCalledWith('background:taskExecute', expect.any(Function))

      const handler = vi.fn()
      onTaskExecute(handler)

      triggerGlobalEvent('background:taskExecute', { taskId: 'com.myapp.sync' })
      expect(handler).toHaveBeenCalledWith('com.myapp.sync')
    })

    it('onTaskExecute with taskId only fires for matching task', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { onTaskExecute } = useBackgroundTask()

      const specificHandler = vi.fn()
      const defaultHandler = vi.fn()

      onTaskExecute(specificHandler, 'com.myapp.sync')
      onTaskExecute(defaultHandler)

      triggerGlobalEvent('background:taskExecute', { taskId: 'com.myapp.sync' })
      expect(specificHandler).toHaveBeenCalledWith('com.myapp.sync')
      expect(defaultHandler).not.toHaveBeenCalled()
    })

    it('scheduleTask defaults to refresh type', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { scheduleTask } = useBackgroundTask()
      await scheduleTask('com.myapp.sync')
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'scheduleTask', [
        'com.myapp.sync',
        'refresh',
        expect.any(Object),
      ])
    })
  })

  // ---------------------------------------------------------------------------
  // useOTAUpdate
  // ---------------------------------------------------------------------------
  describe('useOTAUpdate', () => {
    it('fetches current version on init', async () => {
      invokeModuleSpy.mockResolvedValue({ version: '3', isUsingOTA: true, bundlePath: '/path' })
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      useOTAUpdate('https://updates.example.com/check')
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'getCurrentVersion', [])
    })

    it('checkForUpdate calls OTA.checkForUpdate', async () => {
      invokeModuleSpy.mockResolvedValue({
        updateAvailable: true,
        version: '2.0.0',
        downloadUrl: 'https://cdn.example.com/bundle.js',
        hash: 'abc123',
        size: 1024,
        releaseNotes: 'Bug fixes',
      })
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { checkForUpdate, availableVersion, isChecking } = useOTAUpdate('https://updates.example.com/check')

      const result = await checkForUpdate()
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'checkForUpdate', ['https://updates.example.com/check'])
      expect(result.updateAvailable).toBe(true)
      expect(result.version).toBe('2.0.0')
      expect(availableVersion.value).toBe('2.0.0')
      expect(isChecking.value).toBe(false)
    })

    it('downloadUpdate calls OTA.downloadUpdate', async () => {
      invokeModuleSpy.mockResolvedValue({ path: '/docs/bundle.js', size: 2048 })
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { downloadUpdate, isDownloading, status } = useOTAUpdate('https://updates.example.com/check')

      await downloadUpdate('https://cdn.example.com/bundle.js', 'abc123')
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'downloadUpdate', ['https://cdn.example.com/bundle.js', 'abc123'])
      expect(isDownloading.value).toBe(false)
      expect(status.value).toBe('ready')
    })

    it('downloadUpdate throws if no URL provided and no prior check', async () => {
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { downloadUpdate, error, status } = useOTAUpdate('https://updates.example.com/check')

      await expect(downloadUpdate()).rejects.toThrow('No download URL')
      expect(error.value).toContain('No download URL')
      expect(status.value).toBe('error')
    })

    it('applyUpdate calls OTA.applyUpdate and refreshes version', async () => {
      invokeModuleSpy
        .mockResolvedValueOnce({ version: '1', isUsingOTA: false, bundlePath: '' }) // getCurrentVersion on init
        .mockResolvedValueOnce({ applied: true }) // applyUpdate
        .mockResolvedValueOnce({ version: '2', isUsingOTA: true, bundlePath: '/path' }) // getCurrentVersion after apply
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { applyUpdate, currentVersion } = useOTAUpdate('https://updates.example.com/check')

      await applyUpdate()
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'applyUpdate', [])
      expect(currentVersion.value).toBe('2')
    })

    it('rollback calls OTA.rollback', async () => {
      invokeModuleSpy
        .mockResolvedValueOnce({ version: '2', isUsingOTA: true, bundlePath: '/path' }) // getCurrentVersion on init
        .mockResolvedValueOnce({ rolledBack: true, toEmbedded: true }) // rollback
        .mockResolvedValueOnce({ version: 'embedded', isUsingOTA: false, bundlePath: '' }) // getCurrentVersion after rollback
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { rollback, currentVersion } = useOTAUpdate('https://updates.example.com/check')

      await rollback()
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'rollback', [])
      expect(currentVersion.value).toBe('embedded')
    })

    it('updates downloadProgress on ota:downloadProgress event', async () => {
      invokeModuleSpy.mockResolvedValue({ version: '1', isUsingOTA: false, bundlePath: '' })
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { downloadProgress } = useOTAUpdate('https://updates.example.com/check')

      expect(onGlobalEventSpy).toHaveBeenCalledWith('ota:downloadProgress', expect.any(Function))

      triggerGlobalEvent('ota:downloadProgress', { progress: 0.5, bytesDownloaded: 512, totalBytes: 1024 })
      expect(downloadProgress.value).toBe(0.5)
    })

    it('sets error on checkForUpdate failure', async () => {
      invokeModuleSpy
        .mockResolvedValueOnce({ version: '1', isUsingOTA: false, bundlePath: '' }) // init
        .mockRejectedValueOnce(new Error('Network error'))
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { checkForUpdate, error, status } = useOTAUpdate('https://updates.example.com/check')

      await expect(checkForUpdate()).rejects.toThrow('Network error')
      expect(error.value).toBe('Network error')
      expect(status.value).toBe('error')
    })
  })

  // ---------------------------------------------------------------------------
  // useBluetooth
  // ---------------------------------------------------------------------------
  describe('useBluetooth', () => {
    it('checks BLE state on creation', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      useBluetooth()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'getState')
    })

    it('subscribes to BLE events', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      useBluetooth()
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:stateChanged', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:deviceFound', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:connected', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:disconnected', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:error', expect.any(Function))
    })

    it('scan calls Bluetooth.startScan', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { scan, isScanning } = useBluetooth()
      await scan(['180D'])
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'startScan', [['180D']])
      expect(isScanning.value).toBe(true)
    })

    it('stopScan calls Bluetooth.stopScan', async () => {
      invokeModuleSpy.mockResolvedValue(undefined)
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { stopScan, isScanning } = useBluetooth()
      await stopScan()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'stopScan')
      expect(isScanning.value).toBe(false)
    })

    it('updates devices on ble:deviceFound', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { devices } = useBluetooth()

      triggerGlobalEvent('ble:deviceFound', { id: 'dev1', name: 'HeartRate', rssi: -50 })
      expect(devices.value).toHaveLength(1)
      expect(devices.value[0].id).toBe('dev1')
      expect(devices.value[0].name).toBe('HeartRate')
    })

    it('connect calls Bluetooth.connect', async () => {
      invokeModuleSpy.mockResolvedValue({ id: 'dev1', name: 'HeartRate' })
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { connect } = useBluetooth()
      const result = await connect('dev1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'connect', ['dev1'])
      expect(result.id).toBe('dev1')
    })

    it('disconnect calls Bluetooth.disconnect', async () => {
      invokeModuleSpy.mockResolvedValue(undefined)
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { disconnect, connectedDevice } = useBluetooth()
      await disconnect('dev1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'disconnect', ['dev1'])
      expect(connectedDevice.value).toBeNull()
    })

    it('read calls Bluetooth.readCharacteristic', async () => {
      invokeModuleSpy.mockResolvedValue({ value: 'AQID', characteristicUUID: 'char1', serviceUUID: 'svc1' })
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { read } = useBluetooth()
      const result = await read('dev1', 'svc1', 'char1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'readCharacteristic', ['dev1', 'svc1', 'char1'])
      expect(result.value).toBe('AQID')
    })

    it('write calls Bluetooth.writeCharacteristic', async () => {
      invokeModuleSpy.mockResolvedValue(undefined)
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { write } = useBluetooth()
      await write('dev1', 'svc1', 'char1', 'AQID')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'writeCharacteristic', ['dev1', 'svc1', 'char1', 'AQID'])
    })

    it('updates isAvailable on ble:stateChanged', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOff')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { isAvailable } = useBluetooth()

      triggerGlobalEvent('ble:stateChanged', { state: 'poweredOn' })
      expect(isAvailable.value).toBe(true)

      triggerGlobalEvent('ble:stateChanged', { state: 'poweredOff' })
      expect(isAvailable.value).toBe(false)
    })

    it('updates connectedDevice on ble:connected', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { connectedDevice } = useBluetooth()

      triggerGlobalEvent('ble:connected', { id: 'dev1', name: 'HeartRate' })
      expect(connectedDevice.value?.id).toBe('dev1')
    })

    it('clears connectedDevice on ble:disconnected', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { connectedDevice } = useBluetooth()

      triggerGlobalEvent('ble:connected', { id: 'dev1', name: 'HeartRate' })
      triggerGlobalEvent('ble:disconnected', { id: 'dev1' })
      expect(connectedDevice.value).toBeNull()
    })

    it('sets error on ble:error', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { error } = useBluetooth()

      triggerGlobalEvent('ble:error', { message: 'Connection failed' })
      expect(error.value).toBe('Connection failed')
    })
  })

  // ---------------------------------------------------------------------------
  // useCalendar
  // ---------------------------------------------------------------------------
  describe('useCalendar', () => {
    it('requestAccess calls Calendar.requestAccess', async () => {
      invokeModuleSpy.mockResolvedValue({ granted: true })
      const { useCalendar } = await import('../composables/useCalendar')
      const { requestAccess, hasAccess } = useCalendar()
      const result = await requestAccess()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Calendar', 'requestAccess')
      expect(result).toBe(true)
      expect(hasAccess.value).toBe(true)
    })

    it('requestAccess sets hasAccess to false when denied', async () => {
      invokeModuleSpy.mockResolvedValue({ granted: false })
      const { useCalendar } = await import('../composables/useCalendar')
      const { requestAccess, hasAccess } = useCalendar()
      const result = await requestAccess()
      expect(result).toBe(false)
      expect(hasAccess.value).toBe(false)
    })

    it('getEvents calls Calendar.getEvents', async () => {
      const mockEvents = [{ id: 'e1', title: 'Meeting', startDate: 1000, endDate: 2000 }]
      invokeModuleSpy.mockResolvedValue(mockEvents)
      const { useCalendar } = await import('../composables/useCalendar')
      const { getEvents } = useCalendar()
      const events = await getEvents(1000, 2000)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Calendar', 'getEvents', [1000, 2000])
      expect(events).toEqual(mockEvents)
    })

    it('createEvent calls Calendar.createEvent', async () => {
      invokeModuleSpy.mockResolvedValue({ eventId: 'new-event-1' })
      const { useCalendar } = await import('../composables/useCalendar')
      const { createEvent } = useCalendar()
      const result = await createEvent({
        title: 'Team Standup',
        startDate: 1000,
        endDate: 2000,
        notes: 'Daily standup meeting',
      })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Calendar', 'createEvent', [
        'Team Standup', 1000, 2000, 'Daily standup meeting', undefined,
      ])
      expect(result.eventId).toBe('new-event-1')
    })

    it('deleteEvent calls Calendar.deleteEvent', async () => {
      invokeModuleSpy.mockResolvedValue(undefined)
      const { useCalendar } = await import('../composables/useCalendar')
      const { deleteEvent } = useCalendar()
      await deleteEvent('event-123')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Calendar', 'deleteEvent', ['event-123'])
    })

    it('getCalendars calls Calendar.getCalendars', async () => {
      const mockCalendars = [{ id: 'cal1', title: 'Personal', color: '#FF0000', type: 'local' }]
      invokeModuleSpy.mockResolvedValue(mockCalendars)
      const { useCalendar } = await import('../composables/useCalendar')
      const { getCalendars } = useCalendar()
      const calendars = await getCalendars()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Calendar', 'getCalendars')
      expect(calendars).toEqual(mockCalendars)
    })

    it('sets error on requestAccess failure', async () => {
      invokeModuleSpy.mockRejectedValue(new Error('Permission denied'))
      const { useCalendar } = await import('../composables/useCalendar')
      const { requestAccess, error, hasAccess } = useCalendar()
      const result = await requestAccess()
      expect(result).toBe(false)
      expect(hasAccess.value).toBe(false)
      expect(error.value).toBe('Permission denied')
    })
  })

  // ---------------------------------------------------------------------------
  // useContacts
  // ---------------------------------------------------------------------------
  describe('useContacts', () => {
    it('requestAccess calls Contacts.requestAccess', async () => {
      invokeModuleSpy.mockResolvedValue({ granted: true })
      const { useContacts } = await import('../composables/useContacts')
      const { requestAccess, hasAccess } = useContacts()
      const result = await requestAccess()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Contacts', 'requestAccess')
      expect(result).toBe(true)
      expect(hasAccess.value).toBe(true)
    })

    it('requestAccess sets hasAccess to false when denied', async () => {
      invokeModuleSpy.mockResolvedValue({ granted: false })
      const { useContacts } = await import('../composables/useContacts')
      const { requestAccess, hasAccess } = useContacts()
      const result = await requestAccess()
      expect(result).toBe(false)
      expect(hasAccess.value).toBe(false)
    })

    it('getContacts calls Contacts.getContacts with query', async () => {
      const mockContacts = [{ id: 'c1', givenName: 'John', familyName: 'Doe' }]
      invokeModuleSpy.mockResolvedValue(mockContacts)
      const { useContacts } = await import('../composables/useContacts')
      const { getContacts } = useContacts()
      const contacts = await getContacts('John')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Contacts', 'getContacts', ['John'])
      expect(contacts).toEqual(mockContacts)
    })

    it('getContacts calls Contacts.getContacts without query', async () => {
      invokeModuleSpy.mockResolvedValue([])
      const { useContacts } = await import('../composables/useContacts')
      const { getContacts } = useContacts()
      await getContacts()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Contacts', 'getContacts', [undefined])
    })

    it('getContact calls Contacts.getContact', async () => {
      const mockContact = { id: 'c1', givenName: 'John', familyName: 'Doe' }
      invokeModuleSpy.mockResolvedValue(mockContact)
      const { useContacts } = await import('../composables/useContacts')
      const { getContact } = useContacts()
      const contact = await getContact('c1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Contacts', 'getContact', ['c1'])
      expect(contact).toEqual(mockContact)
    })

    it('createContact calls Contacts.createContact', async () => {
      invokeModuleSpy.mockResolvedValue({ id: 'new-c1' })
      const { useContacts } = await import('../composables/useContacts')
      const { createContact } = useContacts()
      const data = { givenName: 'Jane', familyName: 'Smith', emailAddresses: [{ label: 'home', value: 'jane@example.com' }] }
      const result = await createContact(data)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Contacts', 'createContact', [data])
      expect(result.id).toBe('new-c1')
    })

    it('deleteContact calls Contacts.deleteContact', async () => {
      invokeModuleSpy.mockResolvedValue(undefined)
      const { useContacts } = await import('../composables/useContacts')
      const { deleteContact } = useContacts()
      await deleteContact('c1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Contacts', 'deleteContact', ['c1'])
    })

    it('sets error on requestAccess failure', async () => {
      invokeModuleSpy.mockRejectedValue(new Error('Access denied'))
      const { useContacts } = await import('../composables/useContacts')
      const { requestAccess, error, hasAccess } = useContacts()
      const result = await requestAccess()
      expect(result).toBe(false)
      expect(hasAccess.value).toBe(false)
      expect(error.value).toBe('Access denied')
    })
  })
})
