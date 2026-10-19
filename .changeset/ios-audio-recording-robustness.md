---
"@thelacanians/vue-native-cli": patch
"@thelacanians/vue-native-runtime": patch
---

iOS `Audio.startRecording` is safe on its own: it requests microphone access when the user was never asked (the call waits for the prompt) and rejects with `permission_denied` when access is denied, instead of recording silence. It also rejects, and cleans up, when the recorder fails to prepare or start. `play()` during a recording keeps the `playAndRecord` session so the microphone is not cut mid-take. `useAudio().startRecording` has no bridge timeout (it may wait on the prompt) and sets `error` when it rejects.
