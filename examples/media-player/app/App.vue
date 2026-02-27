<script setup lang="ts">
import { ref, computed } from 'vue'
import { createStyleSheet, useAudio, useDimensions } from '@thelacanians/vue-native-runtime'

// ─── State ───────────────────────────────────────────────────────────────────

const activeTab = ref<'video' | 'audio' | 'web'>('video')
const videoMuted = ref(false)
const videoPaused = ref(false)
const webUrl = ref('https://vuejs.org')

// ─── Audio ───────────────────────────────────────────────────────────────────

const audio = useAudio()
const dimensions = useDimensions()

const audioTracks = [
  { title: 'Sample Track 1', uri: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3' },
  { title: 'Sample Track 2', uri: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3' },
  { title: 'Sample Track 3', uri: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3' },
]

const currentTrackIndex = ref(0)
const currentTrack = computed(() => audioTracks[currentTrackIndex.value])
const audioVolume = ref(80)

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m}:${String(s).padStart(2, '0')}`
}

const progressPercent = computed(() => {
  if (audio.duration.value <= 0) return 0
  return (audio.position.value / audio.duration.value) * 100
})

async function playTrack(index: number) {
  currentTrackIndex.value = index
  await audio.play(audioTracks[index].uri, { volume: audioVolume.value / 100 })
}

async function toggleAudioPlayback() {
  if (audio.isPlaying.value) {
    await audio.pause()
  } else if (audio.position.value > 0) {
    await audio.resume()
  } else {
    await playTrack(currentTrackIndex.value)
  }
}

async function nextTrack() {
  const next = (currentTrackIndex.value + 1) % audioTracks.length
  await playTrack(next)
}

async function prevTrack() {
  const prev = (currentTrackIndex.value - 1 + audioTracks.length) % audioTracks.length
  await playTrack(prev)
}

function onVolumeChange(val: number) {
  audioVolume.value = val
  audio.setVolume(val / 100)
}

// ─── Video ───────────────────────────────────────────────────────────────────

const videoProgress = ref({ currentTime: 0, duration: 0 })

function onVideoProgress(event: any) {
  videoProgress.value = {
    currentTime: event.currentTime ?? 0,
    duration: event.duration ?? 0,
  }
}

const videoWidth = computed(() => Math.min(dimensions.window.value.width - 40, 400))

// ─── Styles ──────────────────────────────────────────────────────────────────

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#1C1C1E',
  },
  header: {
    paddingTop: 56,
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 12,
  },
  tabBar: {
    flexDirection: 'row',
    gap: 8,
  },
  tab: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 16,
    backgroundColor: '#2C2C2E',
  },
  tabActive: {
    backgroundColor: '#007AFF',
  },
  tabText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#8E8E93',
  },
  tabTextActive: {
    color: '#FFFFFF',
  },
  content: {
    flex: 1,
    padding: 20,
  },
  // Video
  videoContainer: {
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#000000',
    marginBottom: 16,
  },
  videoControls: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 16,
    marginBottom: 16,
  },
  controlButton: {
    backgroundColor: '#2C2C2E',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
  },
  controlText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '500',
  },
  videoTime: {
    textAlign: 'center',
    color: '#8E8E93',
    fontSize: 13,
    marginBottom: 8,
  },
  // Audio
  trackList: {
    marginBottom: 24,
  },
  track: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#2C2C2E',
    borderRadius: 10,
    marginBottom: 8,
  },
  trackActive: {
    backgroundColor: '#1A3A5C',
    borderWidth: 1,
    borderColor: '#007AFF',
  },
  trackNumber: {
    fontSize: 14,
    color: '#8E8E93',
    width: 24,
  },
  trackTitle: {
    fontSize: 16,
    color: '#FFFFFF',
    flex: 1,
  },
  trackTitleActive: {
    color: '#007AFF',
  },
  nowPlaying: {
    backgroundColor: '#2C2C2E',
    borderRadius: 12,
    padding: 20,
  },
  nowPlayingTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#FFFFFF',
    textAlign: 'center',
    marginBottom: 16,
  },
  progressBar: {
    height: 4,
    backgroundColor: '#3A3A3C',
    borderRadius: 2,
    marginBottom: 8,
    overflow: 'hidden',
  },
  progressFill: {
    height: 4,
    backgroundColor: '#007AFF',
    borderRadius: 2,
  },
  timeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 20,
  },
  timeText: {
    fontSize: 12,
    color: '#8E8E93',
  },
  audioControls: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 24,
    marginBottom: 20,
  },
  skipButton: {
    padding: 8,
  },
  skipText: {
    fontSize: 24,
    color: '#FFFFFF',
  },
  playButton: {
    backgroundColor: '#007AFF',
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  playText: {
    fontSize: 24,
    color: '#FFFFFF',
  },
  volumeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  volumeIcon: {
    fontSize: 16,
    color: '#8E8E93',
  },
  volumeSlider: {
    flex: 1,
  },
  errorText: {
    color: '#FF3B30',
    fontSize: 13,
    textAlign: 'center',
    marginTop: 8,
  },
  // WebView
  webBar: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 12,
  },
  webInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#3A3A3C',
    borderRadius: 8,
    padding: 10,
    fontSize: 14,
    color: '#FFFFFF',
    backgroundColor: '#2C2C2E',
  },
  webGoButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 16,
    borderRadius: 8,
    justifyContent: 'center',
  },
  webGoText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  webView: {
    flex: 1,
    borderRadius: 8,
    overflow: 'hidden',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VView :style="styles.header">
      <VText :style="styles.title">Media Player</VText>
      <VView :style="styles.tabBar">
        <VButton
          v-for="tab in (['video', 'audio', 'web'] as const)"
          :key="tab"
          :style="[styles.tab, activeTab === tab && styles.tabActive]"
          :on-press="() => activeTab = tab"
        >
          <VText :style="[styles.tabText, activeTab === tab && styles.tabTextActive]">
            {{ tab === 'video' ? 'Video' : tab === 'audio' ? 'Audio' : 'Web' }}
          </VText>
        </VButton>
      </VView>
    </VView>

    <VScrollView :style="styles.content">
      <!-- ─── Video Tab ───────────────────────────────────────────── -->
      <VView v-if="activeTab === 'video'">
        <VView :style="styles.videoContainer">
          <VVideo
            :source="{ uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4' }"
            :autoplay="false"
            :muted="videoMuted"
            :paused="videoPaused"
            :controls="false"
            resize-mode="contain"
            :style="{ width: videoWidth, height: videoWidth * 9 / 16 }"
            @progress="onVideoProgress"
          />
        </VView>

        <VText :style="styles.videoTime">
          {{ formatTime(videoProgress.currentTime) }} / {{ formatTime(videoProgress.duration) }}
        </VText>

        <VView :style="styles.videoControls">
          <VButton
            :style="styles.controlButton"
            :on-press="() => videoPaused = !videoPaused"
          >
            <VText :style="styles.controlText">
              {{ videoPaused ? 'Play' : 'Pause' }}
            </VText>
          </VButton>
          <VButton
            :style="styles.controlButton"
            :on-press="() => videoMuted = !videoMuted"
          >
            <VText :style="styles.controlText">
              {{ videoMuted ? 'Unmute' : 'Mute' }}
            </VText>
          </VButton>
        </VView>
      </VView>

      <!-- ─── Audio Tab ───────────────────────────────────────────── -->
      <VView v-else-if="activeTab === 'audio'">
        <VView :style="styles.trackList">
          <VButton
            v-for="(track, idx) in audioTracks"
            :key="idx"
            :style="[styles.track, idx === currentTrackIndex && styles.trackActive]"
            :on-press="() => playTrack(idx)"
          >
            <VText :style="styles.trackNumber">{{ idx + 1 }}</VText>
            <VText :style="[styles.trackTitle, idx === currentTrackIndex && styles.trackTitleActive]">
              {{ track.title }}
            </VText>
          </VButton>
        </VView>

        <VView :style="styles.nowPlaying">
          <VText :style="styles.nowPlayingTitle">{{ currentTrack.title }}</VText>

          <!-- Progress bar -->
          <VView :style="styles.progressBar">
            <VView :style="[styles.progressFill, { width: `${progressPercent}%` }]" />
          </VView>
          <VView :style="styles.timeRow">
            <VText :style="styles.timeText">{{ formatTime(audio.position.value) }}</VText>
            <VText :style="styles.timeText">{{ formatTime(audio.duration.value) }}</VText>
          </VView>

          <!-- Playback controls -->
          <VView :style="styles.audioControls">
            <VButton :style="styles.skipButton" :on-press="prevTrack">
              <VText :style="styles.skipText">⏮</VText>
            </VButton>
            <VButton :style="styles.playButton" :on-press="toggleAudioPlayback">
              <VText :style="styles.playText">{{ audio.isPlaying.value ? '⏸' : '▶' }}</VText>
            </VButton>
            <VButton :style="styles.skipButton" :on-press="nextTrack">
              <VText :style="styles.skipText">⏭</VText>
            </VButton>
          </VView>

          <!-- Volume -->
          <VView :style="styles.volumeRow">
            <VText :style="styles.volumeIcon">🔈</VText>
            <VSlider
              :model-value="audioVolume"
              :minimum-value="0"
              :maximum-value="100"
              :step="1"
              :style="styles.volumeSlider"
              @update:model-value="onVolumeChange"
            />
            <VText :style="styles.volumeIcon">🔊</VText>
          </VView>

          <VText v-if="audio.error.value" :style="styles.errorText">
            {{ audio.error.value }}
          </VText>
        </VView>
      </VView>

      <!-- ─── Web Tab ─────────────────────────────────────────────── -->
      <VView v-else :style="{ flex: 1, minHeight: 500 }">
        <VView :style="styles.webBar">
          <VInput
            v-model="webUrl"
            placeholder="Enter URL..."
            :style="styles.webInput"
            auto-capitalize="none"
          />
          <VButton :style="styles.webGoButton" :on-press="() => webUrl = webUrl">
            <VText :style="styles.webGoText">Go</VText>
          </VButton>
        </VView>

        <VWebView
          :source="{ uri: webUrl }"
          :style="styles.webView"
          accessibility-label="Embedded web browser"
        />
      </VView>
    </VScrollView>
  </VView>
</template>
