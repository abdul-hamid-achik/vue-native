import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface AudioPlayOptions {
  /** Volume 0.0–1.0. Default 1.0. */
  volume?: number
  /** Loop playback. Default false. */
  loop?: boolean
}

export interface AudioRecordOptions {
  /** Recording quality. Default "medium". */
  quality?: 'low' | 'medium' | 'high'
  /** Output format. Default "m4a". */
  format?: 'm4a' | 'wav'
}

export interface AudioRecordResult {
  uri: string
  duration: number
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

  // Subscribe to progress events
  const unsubProgress = NativeBridge.onGlobalEvent('audio:progress', (payload: any) => {
    position.value = payload.currentTime ?? 0
    duration.value = payload.duration ?? 0
  })

  const unsubComplete = NativeBridge.onGlobalEvent('audio:complete', () => {
    isPlaying.value = false
    position.value = 0
  })

  const unsubError = NativeBridge.onGlobalEvent('audio:error', (payload: any) => {
    error.value = payload.message ?? 'Unknown audio error'
    isPlaying.value = false
  })

  // Auto-cleanup on component unmount
  onUnmounted(() => {
    unsubProgress()
    unsubComplete()
    unsubError()
    // Stop playback and recording to free resources
    NativeBridge.invokeNativeModule('Audio', 'stop', []).catch(() => {})
    if (isRecording.value) {
      NativeBridge.invokeNativeModule('Audio', 'stopRecording', []).catch(() => {})
    }
  })

  async function play(uri: string, options: AudioPlayOptions = {}): Promise<void> {
    error.value = null
    const result: any = await NativeBridge.invokeNativeModule('Audio', 'play', [uri, options])
    if (result?.duration != null) {
      duration.value = result.duration
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
    const result: any = await NativeBridge.invokeNativeModule('Audio', 'startRecording', [options])
    isRecording.value = true
    return result?.uri ?? ''
  }

  async function stopRecording(): Promise<AudioRecordResult> {
    const result: any = await NativeBridge.invokeNativeModule('Audio', 'stopRecording', [])
    isRecording.value = false
    return { uri: result?.uri ?? '', duration: result?.duration ?? 0 }
  }

  async function pauseRecording(): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'pauseRecording', [])
  }

  async function resumeRecording(): Promise<void> {
    await NativeBridge.invokeNativeModule('Audio', 'resumeRecording', [])
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

    // Reactive state
    duration,
    position,
    isPlaying,
    isRecording,
    error,
  }
}
