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
  startRecording: (options?: AudioRecordOptions) => Promise<void>,
  stopRecording: () => Promise<AudioRecordResult>,
  pauseRecording: () => Promise<void>,
  resumeRecording: () => Promise<void>,
  duration: Ref<number>,
  position: Ref<number>,
  isPlaying: Ref<boolean>,
  isRecording: Ref<boolean>,
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
| `startRecording` | `(options?: AudioRecordOptions) => Promise<void>` | Start recording audio from the device microphone. |
| `stopRecording` | `() => Promise<AudioRecordResult>` | Stop recording and return the recorded file info. |
| `pauseRecording` | `() => Promise<void>` | Pause the current recording session. |
| `resumeRecording` | `() => Promise<void>` | Resume a paused recording session. |
| `duration` | `Ref<number>` | Total duration of the current audio in seconds. |
| `position` | `Ref<number>` | Current playback position in seconds. |
| `isPlaying` | `Ref<boolean>` | Whether audio is currently playing. |
| `isRecording` | `Ref<boolean>` | Whether audio is currently being recorded. |
| `error` | `Ref<string \| null>` | The last error message, or `null` if no error. |

### Types

```ts
interface AudioPlayOptions {
  /** Playback volume from 0.0 (silent) to 1.0 (full). Default: 1.0 */
  volume?: number
  /** Whether to loop playback continuously. Default: false */
  loop?: boolean
}

interface AudioRecordOptions {
  /** Recording quality preset. Default: 'medium' */
  quality?: 'low' | 'medium' | 'high'
  /** Output file format. Default: 'm4a' */
  format?: 'm4a' | 'wav'
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
| iOS | Uses `AVAudioPlayer` for playback and `AVAudioRecorder` for recording. Requires microphone permission for recording. |
| Android | Uses `MediaPlayer` for playback and `MediaRecorder` for recording. Requires `RECORD_AUDIO` permission for recording. |

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
- The `position` ref updates in real time during playback via progress events from the native layer.
- Recording requires the appropriate microphone permission on each platform. Use `usePermissions` to request access before calling `startRecording`.
- Remote audio URIs are streamed — the file does not need to be fully downloaded before playback begins.
- Calling `play()` while audio is already playing will stop the current track and start the new one.
