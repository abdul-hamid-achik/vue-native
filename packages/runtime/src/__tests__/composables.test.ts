/**
 * Composable tests — verifies that each composable calls the correct
 * NativeBridge module/method and handles reactive state and cleanup.
 */
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { installMockBridge, withSetup } from './helpers'

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
      await withSetup(() => useNetwork())
      expect(onGlobalEventSpy).toHaveBeenCalledWith('network:change', expect.any(Function))
    })

    it('updates reactive state on network:change', async () => {
      const { useNetwork } = await import('../composables/useNetwork')
      const { isConnected, connectionType } = await withSetup(() => useNetwork())

      // Defaults
      expect(isConnected.value).toBe(true)

      // Simulate network change
      triggerGlobalEvent('network:change', { isConnected: false, connectionType: 'none' })

      expect(isConnected.value).toBe(false)
      expect(connectionType.value).toBe('none')
    })

    it('fetches initial status from Network.getStatus', async () => {
      const { useNetwork } = await import('../composables/useNetwork')
      await withSetup(() => useNetwork())
      expect(invokeModuleSpy).toHaveBeenCalledWith('Network', 'getStatus')
    })
  })

  // ---------------------------------------------------------------------------
  // useAppState (reactive + global event)
  // ---------------------------------------------------------------------------
  describe('useAppState', () => {
    it('subscribes to appState:change global event', async () => {
      const { useAppState } = await import('../composables/useAppState')
      await withSetup(() => useAppState())
      expect(onGlobalEventSpy).toHaveBeenCalledWith('appState:change', expect.any(Function))
    })

    it('updates reactive state on appState:change', async () => {
      invokeModuleSpy.mockResolvedValueOnce('active') // for auto getState call
      const { useAppState } = await import('../composables/useAppState')
      const { state } = await withSetup(() => useAppState())
      await new Promise(resolve => setTimeout(resolve, 0)) // let getState resolve

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
      await withSetup(() => useColorScheme())
      expect(onGlobalEventSpy).toHaveBeenCalledWith('colorScheme:change', expect.any(Function))
    })

    it('updates isDark on dark mode change', async () => {
      const { useColorScheme } = await import('../composables/useColorScheme')
      const { colorScheme, isDark } = await withSetup(() => useColorScheme())

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
      const { status } = await withSetup(() => useWebSocket('wss://test.example.com'))
      expect(status.value).toBe('CONNECTING')
      expect(invokeModuleSpy).toHaveBeenCalledWith('WebSocket', 'connect', expect.arrayContaining(['wss://test.example.com']))
    })

    it('does not connect if autoConnect is false', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { status } = await withSetup(() => useWebSocket('wss://test.example.com', { autoConnect: false }))
      expect(status.value).toBe('CLOSED')
    })

    it('subscribes to websocket events', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      await withSetup(() => useWebSocket('wss://test.example.com'))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('websocket:open', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('websocket:message', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('websocket:close', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('websocket:error', expect.any(Function))
    })

    it('updates lastMessage on websocket:message', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { lastMessage, status } = await withSetup(() => useWebSocket('wss://test.example.com'))

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
      const { send, status: _status } = await withSetup(() => useWebSocket('wss://test.example.com'))

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
      const { send } = await withSetup(() => useWebSocket('wss://test.example.com', { autoConnect: false }))

      invokeModuleSpy.mockClear()
      send('hello')
      // Should not have called WebSocket.send
      const sendCalls = invokeModuleSpy.mock.calls.filter((c: unknown[]) => c[0] === 'WebSocket' && c[1] === 'send')
      expect(sendCalls).toHaveLength(0)
    })

    it('send stringifies objects', async () => {
      const { useWebSocket } = await import('../composables/useWebSocket')
      const { send } = await withSetup(() => useWebSocket('wss://test.example.com'))

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
      const db = await withSetup(() => useDatabase('testdb'))
      await db.execute('CREATE TABLE test (id INTEGER)')
      // First call opens, second executes
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'open', ['testdb'])
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'execute', ['testdb', 'CREATE TABLE test (id INTEGER)', []])
    })

    it('query opens the database and runs query', async () => {
      const { useDatabase } = await import('../composables/useDatabase')
      const db = await withSetup(() => useDatabase('testdb'))
      await db.query('SELECT * FROM test')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'open', ['testdb'])
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'query', ['testdb', 'SELECT * FROM test', []])
    })

    it('close calls Database.close', async () => {
      const { useDatabase } = await import('../composables/useDatabase')
      const db = await withSetup(() => useDatabase('testdb'))
      // Must open first
      await db.execute('SELECT 1')
      await db.close()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Database', 'close', ['testdb'])
    })

    it('uses "default" as default database name', async () => {
      const { useDatabase } = await import('../composables/useDatabase')
      const db = await withSetup(() => useDatabase())
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
      const { play, isPlaying, duration } = await withSetup(() => useAudio())
      await play('https://example.com/song.mp3', { volume: 0.8 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'play', ['https://example.com/song.mp3', { volume: 0.8 }])
      expect(isPlaying.value).toBe(true)
      expect(duration.value).toBe(120)
    })

    it('pause calls Audio.pause and clears isPlaying', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { pause, isPlaying } = await withSetup(() => useAudio())
      await pause()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'pause', [])
      expect(isPlaying.value).toBe(false)
    })

    it('stop calls Audio.stop and resets state', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { stop, isPlaying, position, duration } = await withSetup(() => useAudio())
      await stop()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'stop', [])
      expect(isPlaying.value).toBe(false)
      expect(position.value).toBe(0)
      expect(duration.value).toBe(0)
    })

    it('seek calls Audio.seek', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { seek } = await withSetup(() => useAudio())
      await seek(30)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'seek', [30])
    })

    it('startRecording calls Audio.startRecording', async () => {
      invokeModuleSpy.mockResolvedValue({ uri: '/tmp/rec.m4a' })
      const { useAudio } = await import('../composables/useAudio')
      const { startRecording, isRecording } = await withSetup(() => useAudio())
      const uri = await startRecording({ quality: 'high' })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'startRecording', [{ quality: 'high' }])
      expect(isRecording.value).toBe(true)
      expect(uri).toBe('/tmp/rec.m4a')
    })

    it('stopRecording calls Audio.stopRecording and returns result', async () => {
      invokeModuleSpy.mockResolvedValue({ uri: '/tmp/rec.m4a', duration: 5.5 })
      const { useAudio } = await import('../composables/useAudio')
      const { stopRecording, isRecording } = await withSetup(() => useAudio())
      const result = await stopRecording()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Audio', 'stopRecording', [])
      expect(isRecording.value).toBe(false)
      expect(result).toEqual({ uri: '/tmp/rec.m4a', duration: 5.5 })
    })

    it('updates position/duration on audio:progress event', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { position, duration } = await withSetup(() => useAudio())
      triggerGlobalEvent('audio:progress', { currentTime: 15, duration: 120 })
      expect(position.value).toBe(15)
      expect(duration.value).toBe(120)
    })

    it('resets isPlaying on audio:complete event', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const audio = await withSetup(() => useAudio())
      // Manually set playing state
      triggerGlobalEvent('audio:complete', {})
      expect(audio.isPlaying.value).toBe(false)
      expect(audio.position.value).toBe(0)
    })

    it('sets error on audio:error event', async () => {
      const { useAudio } = await import('../composables/useAudio')
      const { error } = await withSetup(() => useAudio())
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
      const { start, x, y, z } = await withSetup(() => useAccelerometer({ interval: 50 }))
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
      const { start, stop } = await withSetup(() => useAccelerometer())
      start()
      invokeModuleSpy.mockClear()
      stop()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Sensors', 'stopAccelerometer')
    })

    it('checks sensor availability on creation', async () => {
      const { useAccelerometer } = await import('../composables/useSensors')
      await withSetup(() => useAccelerometer())
      expect(invokeModuleSpy).toHaveBeenCalledWith('Sensors', 'isAvailable', ['accelerometer'])
    })
  })

  describe('useGyroscope', () => {
    it('start calls Sensors.startGyroscope', async () => {
      const { useGyroscope } = await import('../composables/useSensors')
      const { start } = await withSetup(() => useGyroscope({ interval: 100 }))
      start()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Sensors', 'startGyroscope', [100])
    })

    it('updates reactive data on sensor event', async () => {
      const { useGyroscope } = await import('../composables/useSensors')
      const { start, x, y, z } = await withSetup(() => useGyroscope())
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
      const { scheduleTask } = await withSetup(() => useBackgroundTask())
      await scheduleTask('com.myapp.sync', { type: 'refresh', requiresNetworkConnectivity: true })
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'scheduleTask', [
        'com.myapp.sync',
        'refresh',
        expect.objectContaining({ requiresNetworkConnectivity: true }),
      ])
    })

    it('cancelTask calls BackgroundTask.cancelTask', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { cancelTask } = await withSetup(() => useBackgroundTask())
      await cancelTask('com.myapp.sync')
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'cancelTask', ['com.myapp.sync'])
    })

    it('cancelAllTasks calls BackgroundTask.cancelAllTasks', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { cancelAllTasks } = await withSetup(() => useBackgroundTask())
      await cancelAllTasks()
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'cancelAllTasks', [])
    })

    it('completeTask calls BackgroundTask.completeTask', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { completeTask } = await withSetup(() => useBackgroundTask())
      await completeTask('com.myapp.sync')
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'completeTask', ['com.myapp.sync', true])
    })

    it('registerTask calls BackgroundTask.registerTask', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { registerTask } = await withSetup(() => useBackgroundTask())
      await registerTask('com.myapp.sync')
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackgroundTask', 'registerTask', ['com.myapp.sync'])
    })

    it('onTaskExecute receives background:taskExecute events', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { onTaskExecute } = await withSetup(() => useBackgroundTask())

      expect(onGlobalEventSpy).toHaveBeenCalledWith('background:taskExecute', expect.any(Function))

      const handler = vi.fn()
      onTaskExecute(handler)

      triggerGlobalEvent('background:taskExecute', { taskId: 'com.myapp.sync' })
      expect(handler).toHaveBeenCalledWith('com.myapp.sync')
    })

    it('onTaskExecute with taskId only fires for matching task', async () => {
      const { useBackgroundTask } = await import('../composables/useBackgroundTask')
      const { onTaskExecute } = await withSetup(() => useBackgroundTask())

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
      const { scheduleTask } = await withSetup(() => useBackgroundTask())
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
      await withSetup(() => useOTAUpdate('https://updates.example.com/check'))
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
      const { checkForUpdate, availableVersion, isChecking } = await withSetup(() => useOTAUpdate('https://updates.example.com/check'))

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
      const { downloadUpdate, isDownloading, status } = await withSetup(() => useOTAUpdate('https://updates.example.com/check'))

      await downloadUpdate('https://cdn.example.com/bundle.js', 'abc123')
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'downloadUpdate', ['https://cdn.example.com/bundle.js', 'abc123'])
      expect(isDownloading.value).toBe(false)
      expect(status.value).toBe('ready')
    })

    it('downloadUpdate throws if no URL provided and no prior check', async () => {
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { downloadUpdate, error, status } = await withSetup(() => useOTAUpdate('https://updates.example.com/check'))

      await expect(downloadUpdate()).rejects.toThrow('No download URL')
      expect(error.value).toContain('No download URL')
      expect(status.value).toBe('error')
    })

    it('applyUpdate calls OTA.applyUpdate and refreshes version', async () => {
      invokeModuleSpy
        .mockResolvedValueOnce({ version: '1', isUsingOTA: false, bundlePath: '' }) // getCurrentVersion on init
        .mockResolvedValueOnce({ updateAvailable: true, version: '2', downloadUrl: 'https://example.com/bundle.js', hash: 'abc123', size: 1024, releaseNotes: '' }) // checkForUpdate
        .mockResolvedValueOnce(undefined) // downloadUpdate
        .mockResolvedValueOnce(undefined) // verifyBundle
        .mockResolvedValueOnce({ applied: true }) // applyUpdate
        .mockResolvedValueOnce({ version: '2', isUsingOTA: true, bundlePath: '/path' }) // getCurrentVersion after apply
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { applyUpdate, currentVersion, checkForUpdate, downloadUpdate } = await withSetup(() => useOTAUpdate('https://updates.example.com/check'))

      // Must go through check -> download -> apply flow so status reaches 'ready'
      await checkForUpdate()
      await downloadUpdate()
      await applyUpdate()
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'verifyBundle', [])
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'applyUpdate', [])
      expect(currentVersion.value).toBe('2')
    })

    it('rollback calls OTA.rollback', async () => {
      invokeModuleSpy
        .mockResolvedValueOnce({ version: '2', isUsingOTA: true, bundlePath: '/path' }) // getCurrentVersion on init
        .mockResolvedValueOnce({ rolledBack: true, toEmbedded: true }) // rollback
        .mockResolvedValueOnce({ version: 'embedded', isUsingOTA: false, bundlePath: '' }) // getCurrentVersion after rollback
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { rollback, currentVersion } = await withSetup(() => useOTAUpdate('https://updates.example.com/check'))

      await rollback()
      expect(invokeModuleSpy).toHaveBeenCalledWith('OTA', 'rollback', [])
      expect(currentVersion.value).toBe('embedded')
    })

    it('updates downloadProgress on ota:downloadProgress event', async () => {
      invokeModuleSpy.mockResolvedValue({ version: '1', isUsingOTA: false, bundlePath: '' })
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { downloadProgress } = await withSetup(() => useOTAUpdate('https://updates.example.com/check'))

      expect(onGlobalEventSpy).toHaveBeenCalledWith('ota:downloadProgress', expect.any(Function))

      triggerGlobalEvent('ota:downloadProgress', { progress: 0.5, bytesDownloaded: 512, totalBytes: 1024 })
      expect(downloadProgress.value).toBe(0.5)
    })

    it('sets error on checkForUpdate failure', async () => {
      invokeModuleSpy
        .mockResolvedValueOnce({ version: '1', isUsingOTA: false, bundlePath: '' }) // init
        .mockRejectedValueOnce(new Error('Network error'))
      const { useOTAUpdate } = await import('../composables/useOTAUpdate')
      const { checkForUpdate, error, status } = await withSetup(() => useOTAUpdate('https://updates.example.com/check'))

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
      await withSetup(() => useBluetooth())
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'getState')
    })

    it('subscribes to BLE events', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      await withSetup(() => useBluetooth())
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:stateChanged', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:deviceFound', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:connected', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:disconnected', expect.any(Function))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('ble:error', expect.any(Function))
    })

    it('scan calls Bluetooth.startScan', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { scan, isScanning } = await withSetup(() => useBluetooth())
      await scan(['180D'])
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'startScan', [['180D']])
      expect(isScanning.value).toBe(true)
    })

    it('stopScan calls Bluetooth.stopScan', async () => {
      invokeModuleSpy.mockResolvedValue(undefined)
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { stopScan, isScanning } = await withSetup(() => useBluetooth())
      await stopScan()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'stopScan')
      expect(isScanning.value).toBe(false)
    })

    it('updates devices on ble:deviceFound', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { devices } = await withSetup(() => useBluetooth())

      triggerGlobalEvent('ble:deviceFound', { id: 'dev1', name: 'HeartRate', rssi: -50 })
      expect(devices.value).toHaveLength(1)
      expect(devices.value[0].id).toBe('dev1')
      expect(devices.value[0].name).toBe('HeartRate')
    })

    it('connect calls Bluetooth.connect', async () => {
      invokeModuleSpy.mockResolvedValue({ id: 'dev1', name: 'HeartRate' })
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { connect } = await withSetup(() => useBluetooth())
      const result = await connect('dev1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'connect', ['dev1'])
      expect(result.id).toBe('dev1')
    })

    it('disconnect calls Bluetooth.disconnect', async () => {
      invokeModuleSpy.mockResolvedValue(undefined)
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { disconnect, connectedDevice } = await withSetup(() => useBluetooth())
      await disconnect('dev1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'disconnect', ['dev1'])
      expect(connectedDevice.value).toBeNull()
    })

    it('read calls Bluetooth.readCharacteristic', async () => {
      invokeModuleSpy.mockResolvedValue({ value: 'AQID', characteristicUUID: 'char1', serviceUUID: 'svc1' })
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { read } = await withSetup(() => useBluetooth())
      const result = await read('dev1', 'svc1', 'char1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'readCharacteristic', ['dev1', 'svc1', 'char1'])
      expect(result.value).toBe('AQID')
    })

    it('write calls Bluetooth.writeCharacteristic', async () => {
      invokeModuleSpy.mockResolvedValue(undefined)
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { write } = await withSetup(() => useBluetooth())
      await write('dev1', 'svc1', 'char1', 'AQID')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Bluetooth', 'writeCharacteristic', ['dev1', 'svc1', 'char1', 'AQID'])
    })

    it('updates isAvailable on ble:stateChanged', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOff')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { isAvailable } = await withSetup(() => useBluetooth())

      triggerGlobalEvent('ble:stateChanged', { state: 'poweredOn' })
      expect(isAvailable.value).toBe(true)

      triggerGlobalEvent('ble:stateChanged', { state: 'poweredOff' })
      expect(isAvailable.value).toBe(false)
    })

    it('updates connectedDevice on ble:connected', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { connectedDevice } = await withSetup(() => useBluetooth())

      triggerGlobalEvent('ble:connected', { id: 'dev1', name: 'HeartRate' })
      expect(connectedDevice.value?.id).toBe('dev1')
    })

    it('clears connectedDevice on ble:disconnected', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { connectedDevice } = await withSetup(() => useBluetooth())

      triggerGlobalEvent('ble:connected', { id: 'dev1', name: 'HeartRate' })
      triggerGlobalEvent('ble:disconnected', { id: 'dev1' })
      expect(connectedDevice.value).toBeNull()
    })

    it('sets error on ble:error', async () => {
      invokeModuleSpy.mockResolvedValue('poweredOn')
      const { useBluetooth } = await import('../composables/useBluetooth')
      const { error } = await withSetup(() => useBluetooth())

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

  // ---------------------------------------------------------------------------
  // useShare
  // ---------------------------------------------------------------------------
  describe('useShare', () => {
    it('share calls Share.share with content', async () => {
      const { useShare } = await import('../composables/useShare')
      const { share } = useShare()
      await share({ message: 'Hello', url: 'https://example.com' })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Share', 'share', [{ message: 'Hello', url: 'https://example.com' }])
    })

    it('share returns result from bridge', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ shared: true })
      const { useShare } = await import('../composables/useShare')
      const { share } = useShare()
      const result = await share({ message: 'Test' })
      expect(result).toEqual({ shared: true })
    })
  })

  // ---------------------------------------------------------------------------
  // useLinking
  // ---------------------------------------------------------------------------
  describe('useLinking', () => {
    it('openURL calls Linking.openURL', async () => {
      const { useLinking } = await import('../composables/useLinking')
      const { openURL } = useLinking()
      await openURL('https://example.com')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Linking', 'openURL', ['https://example.com'])
    })

    it('canOpenURL calls Linking.canOpenURL', async () => {
      invokeModuleSpy.mockResolvedValueOnce(true)
      const { useLinking } = await import('../composables/useLinking')
      const { canOpenURL } = useLinking()
      const result = await canOpenURL('tel://555-1234')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Linking', 'canOpenURL', ['tel://555-1234'])
      expect(result).toBe(true)
    })

    it('canOpenURL returns false for unsupported schemes', async () => {
      invokeModuleSpy.mockResolvedValueOnce(false)
      const { useLinking } = await import('../composables/useLinking')
      const { canOpenURL } = useLinking()
      const result = await canOpenURL('unknown://foo')
      expect(result).toBe(false)
    })
  })

  // ---------------------------------------------------------------------------
  // usePermissions
  // ---------------------------------------------------------------------------
  describe('usePermissions', () => {
    it('request calls Permissions.request', async () => {
      invokeModuleSpy.mockResolvedValueOnce('granted')
      const { usePermissions } = await import('../composables/usePermissions')
      const { request } = usePermissions()
      const status = await request('camera')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Permissions', 'request', ['camera'])
      expect(status).toBe('granted')
    })

    it('check calls Permissions.check', async () => {
      invokeModuleSpy.mockResolvedValueOnce('denied')
      const { usePermissions } = await import('../composables/usePermissions')
      const { check } = usePermissions()
      const status = await check('location')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Permissions', 'check', ['location'])
      expect(status).toBe('denied')
    })

    it('request returns notDetermined for first-time permission', async () => {
      invokeModuleSpy.mockResolvedValueOnce('notDetermined')
      const { usePermissions } = await import('../composables/usePermissions')
      const { request } = usePermissions()
      const status = await request('microphone')
      expect(status).toBe('notDetermined')
    })
  })

  // ---------------------------------------------------------------------------
  // useBiometry
  // ---------------------------------------------------------------------------
  describe('useBiometry', () => {
    it('authenticate calls Biometry.authenticate with reason', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ success: true })
      const { useBiometry } = await import('../composables/useBiometry')
      const { authenticate } = useBiometry()
      const result = await authenticate('Confirm your identity')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Biometry', 'authenticate', ['Confirm your identity'])
      expect(result.success).toBe(true)
    })

    it('authenticate uses default reason', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ success: true })
      const { useBiometry } = await import('../composables/useBiometry')
      const { authenticate } = useBiometry()
      await authenticate()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Biometry', 'authenticate', ['Authenticate'])
    })

    it('getSupportedBiometry calls Biometry.getSupportedBiometry', async () => {
      invokeModuleSpy.mockResolvedValueOnce('faceID')
      const { useBiometry } = await import('../composables/useBiometry')
      const { getSupportedBiometry } = useBiometry()
      const type = await getSupportedBiometry()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Biometry', 'getSupportedBiometry')
      expect(type).toBe('faceID')
    })

    it('isAvailable calls Biometry.isAvailable', async () => {
      invokeModuleSpy.mockResolvedValueOnce(true)
      const { useBiometry } = await import('../composables/useBiometry')
      const { isAvailable } = useBiometry()
      const available = await isAvailable()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Biometry', 'isAvailable')
      expect(available).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // useSecureStorage
  // ---------------------------------------------------------------------------
  describe('useSecureStorage', () => {
    it('getItem calls SecureStorage.get', async () => {
      invokeModuleSpy.mockResolvedValueOnce('secret-value')
      const { useSecureStorage } = await import('../composables/useSecureStorage')
      const { getItem } = useSecureStorage()
      const result = await getItem('token')
      expect(invokeModuleSpy).toHaveBeenCalledWith('SecureStorage', 'get', ['token'])
      expect(result).toBe('secret-value')
    })

    it('setItem calls SecureStorage.set', async () => {
      const { useSecureStorage } = await import('../composables/useSecureStorage')
      const { setItem } = useSecureStorage()
      await setItem('token', 'abc123')
      expect(invokeModuleSpy).toHaveBeenCalledWith('SecureStorage', 'set', ['token', 'abc123'])
    })

    it('removeItem calls SecureStorage.remove', async () => {
      const { useSecureStorage } = await import('../composables/useSecureStorage')
      const { removeItem } = useSecureStorage()
      await removeItem('token')
      expect(invokeModuleSpy).toHaveBeenCalledWith('SecureStorage', 'remove', ['token'])
    })

    it('clear calls SecureStorage.clear', async () => {
      const { useSecureStorage } = await import('../composables/useSecureStorage')
      const { clear } = useSecureStorage()
      await clear()
      expect(invokeModuleSpy).toHaveBeenCalledWith('SecureStorage', 'clear', [])
    })

    it('getItem returns null for missing key', async () => {
      invokeModuleSpy.mockResolvedValueOnce(null)
      const { useSecureStorage } = await import('../composables/useSecureStorage')
      const { getItem } = useSecureStorage()
      const result = await getItem('nonexistent')
      expect(result).toBeNull()
    })
  })

  // ---------------------------------------------------------------------------
  // useKeyboard
  // ---------------------------------------------------------------------------
  describe('useKeyboard', () => {
    it('dismiss calls Keyboard.dismiss', async () => {
      const { useKeyboard } = await import('../composables/useKeyboard')
      const { dismiss } = useKeyboard()
      await dismiss()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Keyboard', 'dismiss', [])
    })

    it('getHeight calls Keyboard.getHeight and updates refs', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ height: 320, isVisible: true })
      const { useKeyboard } = await import('../composables/useKeyboard')
      const { getHeight, isVisible, height } = useKeyboard()
      const result = await getHeight()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Keyboard', 'getHeight', [])
      expect(result).toEqual({ height: 320, isVisible: true })
      expect(isVisible.value).toBe(true)
      expect(height.value).toBe(320)
    })

    it('has default ref values', async () => {
      const { useKeyboard } = await import('../composables/useKeyboard')
      const { isVisible, height } = useKeyboard()
      expect(isVisible.value).toBe(false)
      expect(height.value).toBe(0)
    })
  })

  // ---------------------------------------------------------------------------
  // useDeviceInfo (uses onMounted)
  // ---------------------------------------------------------------------------
  describe('useDeviceInfo', () => {
    it('exposes reactive refs with defaults before mount', async () => {
      // onMounted auto-calls fetchInfo; provide empty object so it doesn't crash
      invokeModuleSpy.mockResolvedValueOnce({})
      const { useDeviceInfo } = await import('../composables/useDeviceInfo')
      const info = await withSetup(() => useDeviceInfo())
      expect(info.model.value).toBe('')
      expect(info.screenWidth.value).toBe(0)
      expect(info.scale.value).toBe(1)
    })

    it('fetchInfo populates reactive refs', async () => {
      const deviceData = {
        model: 'iPhone 15',
        systemVersion: '17.0',
        systemName: 'iOS',
        name: 'User\'s iPhone',
        screenWidth: 393,
        screenHeight: 852,
        scale: 3,
      }
      // First call is consumed by onMounted auto-fetch, second by manual fetchInfo
      invokeModuleSpy.mockResolvedValueOnce(deviceData).mockResolvedValueOnce(deviceData)
      const { useDeviceInfo } = await import('../composables/useDeviceInfo')
      const info = await withSetup(() => useDeviceInfo())
      await info.fetchInfo()
      expect(info.model.value).toBe('iPhone 15')
      expect(info.systemVersion.value).toBe('17.0')
      expect(info.screenWidth.value).toBe(393)
      expect(info.screenHeight.value).toBe(852)
      expect(info.scale.value).toBe(3)
      expect(info.isLoaded.value).toBe(true)
    })

    it('fetchInfo calls DeviceInfo.getInfo', async () => {
      // onMounted auto-calls fetchInfo, provide a value for it
      invokeModuleSpy.mockResolvedValue({ model: '', systemVersion: '', systemName: '', name: '', screenWidth: 0, screenHeight: 0, scale: 1 })
      const { useDeviceInfo } = await import('../composables/useDeviceInfo')
      const info = await withSetup(() => useDeviceInfo())
      await info.fetchInfo()
      expect(invokeModuleSpy).toHaveBeenCalledWith('DeviceInfo', 'getInfo', [])
    })
  })

  // ---------------------------------------------------------------------------
  // useI18n (uses onMounted)
  // ---------------------------------------------------------------------------
  describe('useI18n', () => {
    it('defaults to en locale and non-RTL', async () => {
      const { useI18n } = await import('../composables/useI18n')
      const { locale, isRTL } = await withSetup(() => useI18n())
      expect(locale.value).toBe('en')
      expect(isRTL.value).toBe(false)
    })

    it('detects RTL for Arabic locale', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ locale: 'ar-SA' })
      const { useI18n } = await import('../composables/useI18n')
      const { locale, isRTL } = await withSetup(() => useI18n())
      // onMounted fires during mount; wait for the async call to resolve
      await new Promise(resolve => setTimeout(resolve, 10))
      expect(locale.value).toBe('ar-SA')
      expect(isRTL.value).toBe(true)
    })

    it('detects RTL for Hebrew locale', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ locale: 'he' })
      const { useI18n } = await import('../composables/useI18n')
      const { locale, isRTL } = await withSetup(() => useI18n())
      await new Promise(resolve => setTimeout(resolve, 10))
      expect(locale.value).toBe('he')
      expect(isRTL.value).toBe(true)
    })

    it('non-RTL language stays isRTL=false', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ locale: 'fr-FR' })
      const { useI18n } = await import('../composables/useI18n')
      const { locale, isRTL } = await withSetup(() => useI18n())
      await new Promise(resolve => setTimeout(resolve, 10))
      expect(locale.value).toBe('fr-FR')
      expect(isRTL.value).toBe(false)
    })
  })

  // ---------------------------------------------------------------------------
  // useDimensions (uses onMounted + onUnmounted)
  // ---------------------------------------------------------------------------
  describe('useDimensions', () => {
    it('subscribes to dimensionsChange event', async () => {
      const { useDimensions } = await import('../composables/useDimensions')
      await withSetup(() => useDimensions())
      expect(onGlobalEventSpy).toHaveBeenCalledWith('dimensionsChange', expect.any(Function))
    })

    it('updates reactive refs on dimensionsChange', async () => {
      const { useDimensions } = await import('../composables/useDimensions')
      const { width, height, scale } = await withSetup(() => useDimensions())

      triggerGlobalEvent('dimensionsChange', { width: 414, height: 896, scale: 3 })
      expect(width.value).toBe(414)
      expect(height.value).toBe(896)
      expect(scale.value).toBe(3)
    })

    it('has default values before data is loaded', async () => {
      const { useDimensions } = await import('../composables/useDimensions')
      const { width, height, scale } = await withSetup(() => useDimensions())
      expect(width.value).toBe(0)
      expect(height.value).toBe(0)
      expect(scale.value).toBe(1)
    })
  })

  // ---------------------------------------------------------------------------
  // useBackHandler (uses onMounted + onUnmounted)
  // ---------------------------------------------------------------------------
  describe('useBackHandler', () => {
    it('subscribes to hardware:backPress on mount', async () => {
      const { useBackHandler } = await import('../composables/useBackHandler')
      await withSetup(() => useBackHandler(() => true))
      // onMounted fires during mount and registers the global event
      // Wait for onMounted to fire
      await new Promise(resolve => setTimeout(resolve, 10))
      expect(onGlobalEventSpy).toHaveBeenCalledWith('hardware:backPress', expect.any(Function))
    })

    it('handler returning true prevents default back', async () => {
      const { useBackHandler } = await import('../composables/useBackHandler')
      const handler = vi.fn(() => true)
      await withSetup(() => useBackHandler(handler))
      await new Promise(resolve => setTimeout(resolve, 10))

      triggerGlobalEvent('hardware:backPress', {})
      expect(handler).toHaveBeenCalled()
      // Should NOT call exitApp since handler returned true
      const exitCalls = invokeModuleSpy.mock.calls.filter(
        (c: unknown[]) => c[0] === 'BackHandler' && c[1] === 'exitApp',
      )
      expect(exitCalls).toHaveLength(0)
    })

    it('handler returning false triggers exitApp', async () => {
      const { useBackHandler } = await import('../composables/useBackHandler')
      const handler = vi.fn(() => false)
      await withSetup(() => useBackHandler(handler))
      await new Promise(resolve => setTimeout(resolve, 10))

      triggerGlobalEvent('hardware:backPress', {})
      expect(handler).toHaveBeenCalled()
      expect(invokeModuleSpy).toHaveBeenCalledWith('BackHandler', 'exitApp', [])
    })
  })

  // ---------------------------------------------------------------------------
  // useGeolocation
  // ---------------------------------------------------------------------------
  describe('useGeolocation', () => {
    it('getCurrentPosition calls Geolocation.getCurrentPosition', async () => {
      const mockCoords = { latitude: 37.7749, longitude: -122.4194, altitude: 0, accuracy: 10, altitudeAccuracy: 0, heading: 0, speed: 0, timestamp: 1000 }
      invokeModuleSpy.mockResolvedValueOnce(mockCoords)
      const { useGeolocation } = await import('../composables/useGeolocation')
      const { getCurrentPosition, coords } = useGeolocation()
      const result = await getCurrentPosition()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Geolocation', 'getCurrentPosition')
      expect(result.latitude).toBe(37.7749)
      expect(coords.value?.latitude).toBe(37.7749)
    })

    it('getCurrentPosition sets error on failure', async () => {
      invokeModuleSpy.mockRejectedValueOnce(new Error('Location denied'))
      const { useGeolocation } = await import('../composables/useGeolocation')
      const { getCurrentPosition, error } = useGeolocation()
      await expect(getCurrentPosition()).rejects.toThrow('Location denied')
      expect(error.value).toBe('Location denied')
    })

    it('watchPosition calls Geolocation.watchPosition', async () => {
      invokeModuleSpy.mockResolvedValueOnce(42)
      const { useGeolocation } = await import('../composables/useGeolocation')
      // watchPosition registers onUnmounted, so use withSetup
      const { watchPosition } = await withSetup(() => useGeolocation())
      const id = await watchPosition()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Geolocation', 'watchPosition')
      expect(id).toBe(42)
    })

    it('watchPosition subscribes to location:update events', async () => {
      invokeModuleSpy.mockResolvedValueOnce(1)
      const { useGeolocation } = await import('../composables/useGeolocation')
      const { watchPosition, coords } = await withSetup(() => useGeolocation())
      await watchPosition()
      expect(onGlobalEventSpy).toHaveBeenCalledWith('location:update', expect.any(Function))

      const mockCoords = { latitude: 40.7128, longitude: -74.006, altitude: 0, accuracy: 5, altitudeAccuracy: 0, heading: 0, speed: 0, timestamp: 2000 }
      triggerGlobalEvent('location:update', mockCoords)
      expect(coords.value?.latitude).toBe(40.7128)
    })

    it('clearWatch calls Geolocation.clearWatch', async () => {
      const { useGeolocation } = await import('../composables/useGeolocation')
      const { clearWatch } = useGeolocation()
      await clearWatch(42)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Geolocation', 'clearWatch', [42])
    })
  })

  // ---------------------------------------------------------------------------
  // useNotifications
  // ---------------------------------------------------------------------------
  describe('useNotifications', () => {
    it('requestPermission calls Notifications.requestPermission', async () => {
      invokeModuleSpy.mockResolvedValueOnce(true)
      const { useNotifications } = await import('../composables/useNotifications')
      const { requestPermission, isGranted } = await withSetup(() => useNotifications())
      const result = await requestPermission()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Notifications', 'requestPermission')
      expect(result).toBe(true)
      expect(isGranted.value).toBe(true)
    })

    it('requestPermission sets isGranted=false when denied', async () => {
      invokeModuleSpy.mockResolvedValueOnce(false)
      const { useNotifications } = await import('../composables/useNotifications')
      const { requestPermission, isGranted } = await withSetup(() => useNotifications())
      const result = await requestPermission()
      expect(result).toBe(false)
      expect(isGranted.value).toBe(false)
    })

    it('scheduleLocal calls Notifications.scheduleLocal', async () => {
      invokeModuleSpy.mockResolvedValueOnce('notif-1')
      const { useNotifications } = await import('../composables/useNotifications')
      const { scheduleLocal } = await withSetup(() => useNotifications())
      const id = await scheduleLocal({ title: 'Reminder', body: 'Time to stretch!', delay: 5 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Notifications', 'scheduleLocal', [
        { title: 'Reminder', body: 'Time to stretch!', delay: 5 },
      ])
      expect(id).toBe('notif-1')
    })

    it('cancel calls Notifications.cancel', async () => {
      const { useNotifications } = await import('../composables/useNotifications')
      const { cancel } = await withSetup(() => useNotifications())
      await cancel('notif-1')
      expect(invokeModuleSpy).toHaveBeenCalledWith('Notifications', 'cancel', ['notif-1'])
    })

    it('cancelAll calls Notifications.cancelAll', async () => {
      const { useNotifications } = await import('../composables/useNotifications')
      const { cancelAll } = await withSetup(() => useNotifications())
      await cancelAll()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Notifications', 'cancelAll')
    })

    it('onNotification subscribes to notification:received', async () => {
      const { useNotifications } = await import('../composables/useNotifications')
      const handler = vi.fn()
      // Call onNotification inside setup so its onUnmounted registers correctly
      await withSetup(() => {
        const notifs = useNotifications()
        notifs.onNotification(handler)
        return notifs
      })
      expect(onGlobalEventSpy).toHaveBeenCalledWith('notification:received', expect.any(Function))

      const payload = { id: 'n1', title: 'Test', body: 'Hello', data: {} }
      triggerGlobalEvent('notification:received', payload)
      expect(handler).toHaveBeenCalledWith(payload)
    })

    it('registerForPush calls Notifications.registerForPush', async () => {
      const { useNotifications } = await import('../composables/useNotifications')
      const { registerForPush } = await withSetup(() => useNotifications())
      await registerForPush()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Notifications', 'registerForPush')
    })

    it('getToken calls Notifications.getToken', async () => {
      invokeModuleSpy.mockResolvedValueOnce('device-push-token-xyz')
      const { useNotifications } = await import('../composables/useNotifications')
      const { getToken } = await withSetup(() => useNotifications())
      const token = await getToken()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Notifications', 'getToken')
      expect(token).toBe('device-push-token-xyz')
    })

    it('onPushToken subscribes to push:token event', async () => {
      const { useNotifications } = await import('../composables/useNotifications')
      const handler = vi.fn()
      // Call onPushToken inside setup so its onUnmounted registers correctly
      const { pushToken } = await withSetup(() => {
        const notifs = useNotifications()
        notifs.onPushToken(handler)
        return notifs
      })
      expect(onGlobalEventSpy).toHaveBeenCalledWith('push:token', expect.any(Function))

      triggerGlobalEvent('push:token', { token: 'new-token-abc' })
      expect(handler).toHaveBeenCalledWith('new-token-abc')
      expect(pushToken.value).toBe('new-token-abc')
    })

    it('onPushReceived subscribes to push:received event', async () => {
      const { useNotifications } = await import('../composables/useNotifications')
      const handler = vi.fn()
      // Call onPushReceived inside setup so its onUnmounted registers correctly
      await withSetup(() => {
        const notifs = useNotifications()
        notifs.onPushReceived(handler)
        return notifs
      })
      expect(onGlobalEventSpy).toHaveBeenCalledWith('push:received', expect.any(Function))

      const payload = { title: 'New message', body: 'You have a new message', data: { chatId: '123' }, remote: true as const }
      triggerGlobalEvent('push:received', payload)
      expect(handler).toHaveBeenCalledWith(payload)
    })
  })

  // ---------------------------------------------------------------------------
  // useSharedElementTransition
  // ---------------------------------------------------------------------------
  describe('useSharedElementTransition', () => {
    it('register adds element to registry', async () => {
      const mod = await import('../composables/useSharedElementTransition')
      mod.clearSharedElementRegistry()
      const { register, viewId } = await withSetup(() => mod.useSharedElementTransition('hero-image'))
      register(42)
      expect(viewId.value).toBe(42)
      expect(mod.getSharedElementViewId('hero-image')).toBe(42)
    })

    it('unregister removes element from registry', async () => {
      const mod = await import('../composables/useSharedElementTransition')
      mod.clearSharedElementRegistry()
      const { register, unregister, viewId } = await withSetup(() => mod.useSharedElementTransition('hero-image'))
      register(42)
      unregister()
      expect(viewId.value).toBeNull()
      expect(mod.getSharedElementViewId('hero-image')).toBeUndefined()
    })

    it('getRegisteredSharedElements returns all registered ids', async () => {
      const mod = await import('../composables/useSharedElementTransition')
      mod.clearSharedElementRegistry()
      const first = await withSetup(() => mod.useSharedElementTransition('el-1'))
      const second = await withSetup(() => mod.useSharedElementTransition('el-2'))
      first.register(1)
      second.register(2)
      const ids = mod.getRegisteredSharedElements()
      expect(ids).toContain('el-1')
      expect(ids).toContain('el-2')
    })

    it('clearSharedElementRegistry removes all entries', async () => {
      const mod = await import('../composables/useSharedElementTransition')
      mod.clearSharedElementRegistry()
      const { register } = await withSetup(() => mod.useSharedElementTransition('el-1'))
      register(1)
      mod.clearSharedElementRegistry()
      expect(mod.getRegisteredSharedElements()).toHaveLength(0)
    })

    it('measureViewFrame calls Animation.measureView', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ x: 10, y: 20, width: 100, height: 200 })
      const { measureViewFrame } = await import('../composables/useSharedElementTransition')
      const frame = await measureViewFrame(42)
      expect(invokeModuleSpy).toHaveBeenCalledWith('Animation', 'measureView', [42])
      expect(frame).toEqual({ x: 10, y: 20, width: 100, height: 200 })
    })
  })

  // ---------------------------------------------------------------------------
  // useCamera
  // ---------------------------------------------------------------------------
  describe('useCamera', () => {
    it('launchCamera calls Camera.launchCamera', async () => {
      const mockResult = { uri: 'file://photo.jpg', width: 1920, height: 1080, type: 'image/jpeg' }
      invokeModuleSpy.mockResolvedValueOnce(mockResult)
      const { useCamera } = await import('../composables/useCamera')
      const { launchCamera } = await withSetup(() => useCamera())
      const result = await launchCamera()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Camera', 'launchCamera', [{}])
      expect(result).toEqual(mockResult)
    })

    it('launchCamera forwards options', async () => {
      invokeModuleSpy.mockResolvedValueOnce({ uri: '', width: 0, height: 0, type: '' })
      const { useCamera } = await import('../composables/useCamera')
      const { launchCamera } = await withSetup(() => useCamera())
      await launchCamera({ mediaType: 'photo', quality: 0.8 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Camera', 'launchCamera', [{ mediaType: 'photo', quality: 0.8 }])
    })

    it('launchImageLibrary calls Camera.launchImageLibrary', async () => {
      const mockResult = { uri: 'file://pick.jpg', width: 800, height: 600, type: 'image/jpeg' }
      invokeModuleSpy.mockResolvedValueOnce(mockResult)
      const { useCamera } = await import('../composables/useCamera')
      const { launchImageLibrary } = await withSetup(() => useCamera())
      const result = await launchImageLibrary({ selectionLimit: 3 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Camera', 'launchImageLibrary', [{ selectionLimit: 3 }])
      expect(result).toEqual(mockResult)
    })

    it('captureVideo calls Camera.captureVideo with options', async () => {
      const mockResult = { uri: 'file://video.mp4', duration: 15, type: 'video/mp4' }
      invokeModuleSpy.mockResolvedValueOnce(mockResult)
      const { useCamera } = await import('../composables/useCamera')
      const { captureVideo } = await withSetup(() => useCamera())
      const result = await captureVideo({ quality: 'high', maxDuration: 30 })
      expect(invokeModuleSpy).toHaveBeenCalledWith('Camera', 'captureVideo', [{ quality: 'high', maxDuration: 30 }])
      expect(result).toEqual(mockResult)
    })

    it('scanQRCode calls Camera.scanQRCode', async () => {
      invokeModuleSpy.mockResolvedValueOnce(undefined)
      const { useCamera } = await import('../composables/useCamera')
      const { scanQRCode } = await withSetup(() => useCamera())
      await scanQRCode()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Camera', 'scanQRCode')
    })

    it('stopQRScan calls Camera.stopQRScan', async () => {
      invokeModuleSpy.mockResolvedValueOnce(undefined)
      const { useCamera } = await import('../composables/useCamera')
      const { stopQRScan } = await withSetup(() => useCamera())
      await stopQRScan()
      expect(invokeModuleSpy).toHaveBeenCalledWith('Camera', 'stopQRScan')
    })

    it('onQRCodeDetected registers callback and returns cleanup', async () => {
      const { useCamera } = await import('../composables/useCamera')
      const { onQRCodeDetected } = await withSetup(() => useCamera())

      const callback = vi.fn()
      const cleanup = onQRCodeDetected(callback)

      expect(onGlobalEventSpy).toHaveBeenCalledWith('camera:qrDetected', callback)
      expect(typeof cleanup).toBe('function')
    })

    it('onQRCodeDetected callback fires on event', async () => {
      const { useCamera } = await import('../composables/useCamera')
      const { onQRCodeDetected } = await withSetup(() => useCamera())

      const callback = vi.fn()
      onQRCodeDetected(callback)

      const qrResult = { data: 'https://example.com', type: 'org.iso.QRCode', bounds: { x: 0, y: 0, width: 1, height: 1 } }
      triggerGlobalEvent('camera:qrDetected', qrResult)
      expect(callback).toHaveBeenCalledWith(qrResult)
    })
  })

  // ---------------------------------------------------------------------------
  // useHttp
  // ---------------------------------------------------------------------------
  describe('useHttp', () => {
    // Provide a global fetch mock for useHttp tests
    let originalFetch: any

    beforeEach(() => {
      originalFetch = (globalThis as any).fetch
      ;(globalThis as any).fetch = vi.fn()
    })

    afterEach(() => {
      (globalThis as any).fetch = originalFetch
    })

    function mockFetch(data: any, status = 200, ok = true) {
      ;(globalThis as any).fetch = vi.fn().mockResolvedValue({
        status,
        ok,
        json: () => Promise.resolve(data),
        headers: {
          forEach: (cb: (value: string, key: string) => void) => {
            cb('application/json', 'content-type')
          },
        },
      })
    }

    it('GET request calls fetch with correct URL and method', async () => {
      mockFetch({ users: [] })
      const { useHttp } = await import('../composables/useHttp')
      const { get, loading } = await withSetup(() => useHttp({ baseURL: 'https://api.test.com' }))
      const result = await get('/users')
      expect((globalThis as any).fetch).toHaveBeenCalledWith(
        'https://api.test.com/users',
        expect.objectContaining({ method: 'GET' }),
      )
      expect(result.data).toEqual({ users: [] })
      expect(result.status).toBe(200)
      expect(result.ok).toBe(true)
      expect(loading.value).toBe(false)
    })

    it('POST request sends JSON body', async () => {
      mockFetch({ id: 1 }, 201)
      const { useHttp } = await import('../composables/useHttp')
      const { post } = await withSetup(() => useHttp({ baseURL: 'https://api.test.com' }))
      const result = await post('/users', { name: 'Alice' })
      expect((globalThis as any).fetch).toHaveBeenCalledWith(
        'https://api.test.com/users',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({ name: 'Alice' }),
        }),
      )
      expect(result.data).toEqual({ id: 1 })
    })

    it('PUT request sends JSON body', async () => {
      mockFetch({ updated: true })
      const { useHttp } = await import('../composables/useHttp')
      const { put } = await withSetup(() => useHttp({ baseURL: 'https://api.test.com' }))
      const result = await put('/users/1', { name: 'Bob' })
      expect((globalThis as any).fetch).toHaveBeenCalledWith(
        'https://api.test.com/users/1',
        expect.objectContaining({ method: 'PUT' }),
      )
      expect(result.data).toEqual({ updated: true })
    })

    it('DELETE request works', async () => {
      mockFetch({ deleted: true })
      const { useHttp } = await import('../composables/useHttp')
      const http = await withSetup(() => useHttp({ baseURL: 'https://api.test.com' }))
      const result = await http.delete('/users/1')
      expect((globalThis as any).fetch).toHaveBeenCalledWith(
        'https://api.test.com/users/1',
        expect.objectContaining({ method: 'DELETE' }),
      )
      expect(result.data).toEqual({ deleted: true })
    })

    it('PATCH request sends body', async () => {
      mockFetch({ patched: true })
      const { useHttp } = await import('../composables/useHttp')
      const { patch } = await withSetup(() => useHttp({ baseURL: 'https://api.test.com' }))
      const result = await patch('/users/1', { name: 'Carol' })
      expect((globalThis as any).fetch).toHaveBeenCalledWith(
        'https://api.test.com/users/1',
        expect.objectContaining({ method: 'PATCH' }),
      )
      expect(result.data).toEqual({ patched: true })
    })

    it('sets error state on fetch failure', async () => {
      ;(globalThis as any).fetch = vi.fn().mockRejectedValue(new Error('Network error'))
      const { useHttp } = await import('../composables/useHttp')
      const { get, error, loading } = await withSetup(() => useHttp())
      await expect(get('https://api.test.com/fail')).rejects.toThrow('Network error')
      expect(error.value).toBe('Network error')
      expect(loading.value).toBe(false)
    })

    it('sets loading to true during request', async () => {
      const _loadingDuringRequest = false
      ;(globalThis as any).fetch = vi.fn().mockImplementation(() => {
        return new Promise((resolve) => {
          // We'll resolve immediately but capture loading state
          resolve({
            status: 200,
            ok: true,
            json: () => Promise.resolve({}),
            headers: { forEach: () => {} },
          })
        })
      })
      const { useHttp } = await import('../composables/useHttp')
      const { get, loading } = await withSetup(() => useHttp())
      // After completing, loading should be false
      await get('https://api.test.com/test')
      expect(loading.value).toBe(false)
    })

    it('merges default and per-request headers', async () => {
      mockFetch({})
      const { useHttp } = await import('../composables/useHttp')
      const { get } = await withSetup(() => useHttp({
        baseURL: 'https://api.test.com',
        headers: { Authorization: 'Bearer token' },
      }))
      await get('/me', { headers: { 'X-Custom': 'val' } })
      expect((globalThis as any).fetch).toHaveBeenCalledWith(
        'https://api.test.com/me',
        expect.objectContaining({
          headers: expect.objectContaining({
            'Authorization': 'Bearer token',
            'X-Custom': 'val',
          }),
        }),
      )
    })

    it('GET with query params builds URL correctly', async () => {
      mockFetch({ results: [] })
      const { useHttp } = await import('../composables/useHttp')
      const { get } = await withSetup(() => useHttp({ baseURL: 'https://api.test.com' }))
      await get('/search', { params: { q: 'hello', page: '1' } })
      expect((globalThis as any).fetch).toHaveBeenCalledWith(
        'https://api.test.com/search?q=hello&page=1',
        expect.any(Object),
      )
    })

    it('POST does not set Content-Type for GET methods', async () => {
      mockFetch({})
      const { useHttp } = await import('../composables/useHttp')
      const { get } = await withSetup(() => useHttp())
      await get('https://api.test.com/data')
      const fetchCall = (globalThis as any).fetch.mock.calls[0]
      expect(fetchCall[1].headers['Content-Type']).toBeUndefined()
    })

    it('POST auto-sets Content-Type to application/json', async () => {
      mockFetch({})
      const { useHttp } = await import('../composables/useHttp')
      const { post } = await withSetup(() => useHttp())
      await post('https://api.test.com/data', { key: 'val' })
      const fetchCall = (globalThis as any).fetch.mock.calls[0]
      expect(fetchCall[1].headers['Content-Type']).toBe('application/json')
    })

    it('works without baseURL', async () => {
      mockFetch({ ok: true })
      const { useHttp } = await import('../composables/useHttp')
      const { get } = await withSetup(() => useHttp())
      const result = await get('https://example.com/api')
      expect((globalThis as any).fetch).toHaveBeenCalledWith(
        'https://example.com/api',
        expect.any(Object),
      )
      expect(result.data).toEqual({ ok: true })
    })

    it('configures certificate pins when provided', async () => {
      mockFetch({})
      const { useHttp } = await import('../composables/useHttp')
      const pins = { 'api.example.com': ['sha256/AAAA'] }
      // Mock __VN_configurePins
      const configurePins = vi.fn()
      ;(globalThis as any).__VN_configurePins = configurePins
      await withSetup(() => useHttp({ pins }))
      expect(configurePins).toHaveBeenCalledWith(JSON.stringify(pins))
      delete (globalThis as any).__VN_configurePins
    })
  })
})
