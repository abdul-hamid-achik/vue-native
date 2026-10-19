# useAudio

Audio playback and recording composable. Provides a complete API for playing audio files from local or remote URIs, recording audio from the device microphone, and tracking playback progress in real time. Automatically cleans up resources when the component unmounts.

## Usage

```vue
<script setup>
import { useAudio } from '@thelacanians/vue-native-runtime'

const {
  play,
  pause,
  resume,
  stop,
  seek,
  setVolume,
  startRecording,
  stopRecording,
  duration,
  position,
  isPlaying,
  isRecording,
  error
} = useAudio()
</script>

<template>
  <VView>
    <VText>{{ isPlaying ? 'Playing' : 'Stopped' }}</VText>
    <VText>{{ Math.floor(position) }}s / {{ Math.floor(duration) }}s</VText>
    <VButton :title="isPlaying ? 'Pause' : 'Play'" @press="isPlaying ? pause() : play('https://example.com/song.mp3')" />
    <VButton title="Record" @press="isRecording ? stopRecording() : startRecording()" />
  </VView>
</template>
```

## API

```ts
useAudio(): {
  play: (uri: string, options?: AudioPlayOptions) => Promise<void>,
  pause: () => Promise<void>,
  resume: () => Promise<void>,
  stop: () => Promise<void>,
  seek: (positionSec: number) => Promise<void>,
  setVolume: (volume: number) => Promise<void>,
  startRecording: (options?: AudioRecordOptions) => Promise<string>,
  stopRecording: () => Promise<AudioRecordResult>,
  pauseRecording: () => Promise<void>,
  resumeRecording: () => Promise<void>,
  onRecordingLevel: (handler: (level: RecordingLevel) => void) => () => void,
  duration: Ref<number>,
  position: Ref<number>,
  isPlaying: Ref<boolean>,
  isRecording: Ref<boolean>,
  recordingLevel: Ref<number>,
  error: Ref<string | null>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `play` | `(uri: string, options?: AudioPlayOptions) => Promise<void>` | Start playing audio from a local or remote URI. |
| `pause` | `() => Promise<void>` | Pause the current playback. |
| `resume` | `() => Promise<void>` | Resume paused playback. |
| `stop` | `() => Promise<void>` | Stop playback and reset position to the beginning. |
| `seek` | `(positionSec: number) => Promise<void>` | Seek to a specific position in seconds. |
| `setVolume` | `(volume: number) => Promise<void>` | Set playback volume (0.0 to 1.0). |
| `startRecording` | `(options?: AudioRecordOptions) => Promise<string>` | Start recording audio from the device microphone; resolves with the file URI once the recorder runs. iOS asks for microphone access first if the user was never asked, and rejects with a message starting with `permission_denied` when access is denied. See [Recording errors](#recording-errors). |
| `stopRecording` | `() => Promise<AudioRecordResult>` | Stop recording and return the recorded file info. |
| `pauseRecording` | `() => Promise<void>` | Pause the current recording session. |
| `resumeRecording` | `() => Promise<void>` | Resume a paused recording session. |
| `onRecordingLevel` | `(handler) => () => void` | iOS: called about 12 times a second with the input level while recording with `metering: true`. Returns an unsubscribe function. |
| `duration` | `Ref<number>` | Total duration of the current audio in seconds. |
| `position` | `Ref<number>` | Current playback position in seconds. |
| `isPlaying` | `Ref<boolean>` | Whether audio is currently playing. |
| `isRecording` | `Ref<boolean>` | Whether audio is currently being recorded. |
| `recordingLevel` | `Ref<number>` | iOS: input level from 0 (silence) to 1 while recording with `metering: true`; use it to show that the microphone hears the user. |
| `error` | `Ref<string \| null>` | The last error message, or `null` if no error. |

### Types

```ts
interface AudioPlayOptions {
  /** Playback volume from 0.0 (silent) to 1.0 (full). Default: 1.0 */
  volume?: number
  /** Whether to loop playback continuously. Default: false */
  loop?: boolean
  /** Playback speed from 0.5 to 2.0 (clamped). Default: 1.0. iOS only for now. */
  rate?: number
}

interface AudioRecordOptions {
  /** Recording quality preset. Default: 'medium' */
  quality?: 'low' | 'medium' | 'high'
  /** Output file format. Default: 'm4a' */
  format?: 'm4a' | 'wav'
  /** iOS: report the input level while recording. Default: false */
  metering?: boolean
}

interface RecordingLevel {
  /** 0 (−50 dBFS or quieter) to 1 (0 dBFS). */
  level: number
  /** Average power in dBFS. */
  power: number
  /** Seconds recorded so far. */
  currentTime: number
}

interface AudioRecordResult {
  /** File URI of the recorded audio. */
  uri: string
  /** Duration of the recording in seconds. */
  duration: number
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `AVAudioPlayer` for playback and `AVAudioRecorder` for recording. `startRecording` requests microphone permission itself when it was never asked, and rejects with `permission_denied` when denied. |
| Android | Uses `MediaPlayer` for playback and `MediaRecorder` for recording. Requires `RECORD_AUDIO` permission for recording; it does not request it, so ask with `usePermissions` first. |
| macOS | No Audio module yet. |

## Recording errors

On iOS `startRecording` rejects, leaves `isRecording` `false` and sets `error` when:

- microphone access is denied or restricted: the message starts with `permission_denied`. Send the learner to Settings > Privacy > Microphone instead of retrying;
- the recorder cannot be created, prepared or started (for example no usable input): the message starts with `Failed to start recording`. The temporary file is removed and the session returns to playback.

```ts
try {
  await startRecording({ format: 'wav' })
} catch (e) {
  if (e instanceof Error && e.message.startsWith('permission_denied')) {
    // show "enable the microphone in Settings"
  }
}
```

## Example

```vue
<script setup>
import { useAudio } from '@thelacanians/vue-native-runtime'

const { play, stop, startRecording, stopRecording, position, duration, isPlaying, isRecording } = useAudio()

async function handleRecord() {
  if (isRecording.value) {
    const result = await stopRecording()
    // Play back the recording
    await play(result.uri)
  } else {
    await startRecording({ quality: 'high', format: 'm4a' })
  }
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 24, marginBottom: 16 }">Audio Player</VText>

    <VButton title="Play Music" @press="play('https://example.com/music.mp3', { volume: 0.8 })" />
    <VButton title="Stop" @press="stop()" />

    <VText v-if="isPlaying">
      Progress: {{ Math.floor(position) }}s / {{ Math.floor(duration) }}s
    </VText>

    <VButton
      :title="isRecording ? 'Stop Recording' : 'Start Recording'"
      @press="handleRecord"
    />
  </VView>
</template>
```

## Notes

- Automatically stops playback and recording when the component unmounts to prevent resource leaks.
- Subscribes to `audio:progress`, `audio:complete`, and `audio:error` global events from the native bridge.
- iOS: calling `play()` again, or `stop()`, cancels a remote download that is still in flight, so a clip you stopped never starts playing afterwards. The superseded `play()` resolves without touching `isPlaying`, `duration`, or `error`. A `play()` that fails (bad URI, download or decode error) after the previous clip was stopped emits `audio:error`, which resets `isPlaying`.
- The `position` ref updates in real time during playback via progress events from the native layer.
- Recording requires microphone permission on each platform. On iOS `startRecording` asks for it when the user was never asked (the call stays pending while the system prompt is up and has no timeout), so the first take no longer records silence. On Android, use `usePermissions` to request access before calling `startRecording`. On iOS, `usePermissions` first is still fine and lets you explain why you need the microphone before the system prompt appears.
- iOS: calling `play()` while a recording is running keeps the audio session in `playAndRecord` (speaker output), so the microphone keeps capturing. After `stopRecording()` the session returns to playback-only.
- Remote audio URIs are streamed — the file does not need to be fully downloaded before playback begins.
- Calling `play()` while audio is already playing will stop the current track and start the new one.
