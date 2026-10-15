---
"@thelacanians/vue-native-cli": patch
---

`useAudio`: `startRecording({ metering: true })` reports the microphone input level on iOS (`recordingLevel` ref, `onRecordingLevel(handler)`, event `audio:recordingLevel`). Recording no longer leaves later playback on the quiet earpiece route: the session uses `defaultToSpeaker` while recording and returns to playback when it stops.
