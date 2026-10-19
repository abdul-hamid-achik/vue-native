import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface AudioPlayOptions {
  /** Volume 0.0–1.0. Default 1.0. */
  volume?: number
  /** Loop playback. Default false. */
  loop?: boolean
  /**
   * Playback speed, 0.5–2.0 (clamped). Default 1.0 (normal speed).
   * iOS only; Android and macOS ignore it for now.
   */
  rate?: number
}

export interface AudioRecordOptions {
  /** Recording quality. Default "medium". */
  quality?: 'low' | 'medium' | 'high'
  /** Output format. Default "m4a". */
  format?: 'm4a' | 'wav'
  /**
   * iOS: report the input level while recording (`recordingLevel`, `onRecordingLevel`),
   * about 12 times a second, e.g. to show that the microphone hears the user.
   */
  metering?: boolean
}

export interface RecordingLevel {
  /** 0 (silence, −50 dBFS or less) … 1 (0 dBFS). */
  level: number
  /** Average power in dBFS. */
  power: number
  /** Seconds recorded so far. */
  currentTime: number
}

export interface AudioRecordResult {
  uri: string
  duration: number
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null ? value as Record<string, unknown> : null
}

function getNumberProp(record: Record<string, unknown> | null, key: string): number | undefined {
  const value = record?.[key]
  return typeof value === 'number' ? value : undefined
}

function getStringProp(record: Record<string, unknown> | null, key: string): string | undefined {
  const value = record?.[key]
  return typeof value === 'string' ? value : undefined
}

// ─── useAudio composable ─────────────────────────────────────────────────

/**
 * Audio playback and recording composable.
 *
 * @example
 * ```ts
 * const { play, pause, stop, seek, duration, position, isPlaying } = useAudio()
 *
 * // Play a remote file
 * await play('https://example.com/song.mp3')
 *
 * // Seek to 30 seconds
 * await seek(30)
 *
 * // Record audio
 * const { startRecording, stopRecording, isRecording } = useAudio()
 * await startRecording({ quality: 'high' })
 * const result = await stopRecording() // { uri, duration }
 * ```
 */
export function useAudio() {
  const duration = ref(0)
  const position = ref(0)
  const isPlaying = ref(false)
  const isRecording = ref(false)
  const error = ref<string | null>(null)
  /** Input level 0…1 while recording with `metering: true` (iOS); 0 otherwise. */
  const recordingLevel = ref(0)
  const levelHandlers = new Set<(l: RecordingLevel) => void>()

  const unsubLevel = NativeBridge.onGlobalEvent<RecordingLevel>('audio:recordingLevel', (payload) => {
    recordingLevel.value = payload.level ?? 0
    levelHandlers.forEach(fn => fn(payload))
  })

  // Subscribe to progress events
  const unsubProgress = NativeBridge.onGlobalEvent<{ currentTime?: number, duration?: number }>('audio:progress', (payload) => {
    position.value = payload.currentTime ?? 0
    duration.value = payload.duration ?? 0
  })

  const unsubComplete = NativeBridge.onGlobalEvent('audio:complete', () => {
    isPlaying.value = false
    position.value = 0
  })

  const unsubError = NativeBridge.onGlobalEvent<{ message?: string }>('audio:error', (payload) => {
    error.value = payload.message ?? 'Unknown audio error'
    isPlaying.value = false
  })

  // Auto-cleanup on component unmount
  onUnmounted(() => {
    unsubProgress()
    unsubComplete()
    unsubError()
    unsubLevel()
    levelHandlers.clear()
    // Stop playback and recording to free resources
    NativeBridge.invokeNativeModule('Audio', 'stop', []).catch((err: unknown) => {
      if (__DEV__) console.warn('[vue-native] Audio.stop failed:', err)
    })
    if (isRecording.value) {
      NativeBridge.invokeNativeModule('Audio', 'stopRecording', []).catch((err: unknown) => {
        if (__DEV__) console.warn('[vue-native] Audio.stopRecording failed:', err)
      })
    }
  })

  async function play(uri: string, options: AudioPlayOptions = {}): Promise<void> {
    error.value = null
    const result = asRecord(await NativeBridge.invokeNativeModule('Audio', 'play', [uri, options]))
    // iOS resolves `{ cancelled: true }` when a later play()/stop() superseded this
    // call before the clip (e.g. a remote download) started: leave the state alone.
    if (result?.cancelled === true) return
    const audioDuration = getNumberProp(result, 'duration')
    if (audioDuration !== undefined) {
      duration.value = audioDuration
    }
    isPlaying.value = true
  }

  async function pause(): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'pause', [])
    isPlaying.value = false
  }

  async function resume(): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'resume', [])
    isPlaying.value = true
  }

  async function stop(): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'stop', [])
    isPlaying.value = false
    position.value = 0
    duration.value = 0
  }

  async function seek(positionSec: number): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'seek', [positionSec])
  }

  async function setVolume(volume: number): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'setVolume', [volume])
  }

  async function startRecording(options: AudioRecordOptions = {}): Promise<string> {
    error.value = null
    const result = asRecord(await NativeBridge.invokeNativeModule('Audio', 'startRecording', [options]))
    isRecording.value = true
    return getStringProp(result, 'uri') ?? ''
  }

  async function stopRecording(): Promise<AudioRecordResult> {
    const result = asRecord(await NativeBridge.invokeNativeModule('Audio', 'stopRecording', []))
    isRecording.value = false
    recordingLevel.value = 0
    return {
      uri: getStringProp(result, 'uri') ?? '',
      duration: getNumberProp(result, 'duration') ?? 0,
    }
  }

  async function pauseRecording(): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'pauseRecording', [])
  }

  async function resumeRecording(): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'resumeRecording', [])
  }

  /** Called with every level sample while recording with `metering: true`. Returns an unsubscribe. */
  function onRecordingLevel(handler: (level: RecordingLevel) => void): () => void {
    levelHandlers.add(handler)
    return () => levelHandlers.delete(handler)
  }

  return {
    // Playback
    play,
    pause,
    resume,
    stop,
    seek,
    setVolume,

    // Recording
    startRecording,
    stopRecording,
    pauseRecording,
    resumeRecording,
    onRecordingLevel,

    // Reactive state
    duration,
    position,
    isPlaying,
    isRecording,
    recordingLevel,
    error,
  }
}
