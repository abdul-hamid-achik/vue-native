<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet, useCamera, usePermissions } from '@thelacanians/vue-native-runtime'

interface Photo {
  id: number
  uri: string
  timestamp: number
}

let nextId = 1
const { launchCamera, launchImageLibrary } = useCamera()
const { request, check } = usePermissions()

const photos = ref<Photo[]>([])
const selectedPhoto = ref<Photo | null>(null)
const permissionGranted = ref(false)
const permissionChecked = ref(false)
const loading = ref(false)

async function checkPermission() {
  try {
    const status = await check('camera')
    permissionGranted.value = status === 'granted'
    permissionChecked.value = true
    if (!permissionGranted.value) {
      await requestPermission()
    }
  } catch {
    permissionChecked.value = true
  }
}

async function requestPermission() {
  try {
    const status = await request('camera')
    permissionGranted.value = status === 'granted'
  } catch {
    // Permission request failed
  }
}

async function takePhoto() {
  if (!permissionGranted.value) {
    await requestPermission()
    if (!permissionGranted.value) return
  }

  loading.value = true
  try {
    const result = await launchCamera({ quality: 0.8 })
    if (result?.uri) {
      const photo: Photo = {
        id: nextId++,
        uri: result.uri,
        timestamp: Date.now(),
      }
      photos.value = [photo, ...photos.value]
      selectedPhoto.value = photo
    }
  } catch {
    // Camera cancelled or failed
  } finally {
    loading.value = false
  }
}

async function pickFromLibrary() {
  loading.value = true
  try {
    const result = await launchImageLibrary({ quality: 0.8 })
    if (result?.uri) {
      const photo: Photo = {
        id: nextId++,
        uri: result.uri,
        timestamp: Date.now(),
      }
      photos.value = [photo, ...photos.value]
      selectedPhoto.value = photo
    }
  } catch {
    // Picker cancelled or failed
  } finally {
    loading.value = false
  }
}

function selectPhoto(photo: Photo) {
  selectedPhoto.value = photo
}

function clearSelection() {
  selectedPhoto.value = null
}

function formatDate(ts: number): string {
  const d = new Date(ts)
  return d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
}

// Check permission on mount
checkPermission()

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  header: {
    backgroundColor: '#1C1C1E',
    paddingHorizontal: 16,
    paddingTop: 56,
    paddingBottom: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  photoCount: {
    fontSize: 13,
    color: '#8E8E93',
  },
  preview: {
    flex: 1,
    backgroundColor: '#000000',
    justifyContent: 'center',
    alignItems: 'center',
  },
  previewImage: {
    width: '100%' as any,
    height: '100%' as any,
  },
  previewPlaceholder: {
    alignItems: 'center',
    gap: 12,
  },
  placeholderIcon: {
    fontSize: 64,
  },
  placeholderText: {
    fontSize: 16,
    color: '#8E8E93',
  },
  placeholderSubtext: {
    fontSize: 13,
    color: '#636366',
    textAlign: 'center',
    paddingHorizontal: 40,
  },
  previewOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    paddingHorizontal: 16,
    paddingVertical: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  previewTime: {
    fontSize: 13,
    color: '#FFFFFF',
  },
  closePreview: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
  },
  closePreviewText: {
    fontSize: 13,
    color: '#FFFFFF',
  },
  buttonBar: {
    flexDirection: 'row',
    backgroundColor: '#1C1C1E',
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 12,
  },
  captureButton: {
    flex: 1,
    backgroundColor: '#FF9500',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  captureButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  libraryButton: {
    flex: 1,
    backgroundColor: '#2C2C2E',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  libraryButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  gallery: {
    backgroundColor: '#1C1C1E',
    paddingBottom: 28,
  },
  galleryHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  galleryTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  galleryCount: {
    fontSize: 13,
    color: '#8E8E93',
  },
  galleryScroll: {
    paddingHorizontal: 12,
  },
  galleryItem: {
    width: 72,
    height: 72,
    borderRadius: 8,
    marginHorizontal: 4,
    overflow: 'hidden',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  galleryItemSelected: {
    borderColor: '#FF9500',
  },
  galleryImage: {
    width: 72,
    height: 72,
  },
  galleryEmpty: {
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  galleryEmptyText: {
    fontSize: 13,
    color: '#636366',
    textAlign: 'center',
  },
  permissionContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#000000',
    paddingHorizontal: 32,
  },
  permissionIcon: {
    fontSize: 56,
    marginBottom: 16,
  },
  permissionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#FFFFFF',
    marginBottom: 8,
    textAlign: 'center',
  },
  permissionText: {
    fontSize: 15,
    color: '#8E8E93',
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: 24,
  },
  permissionButton: {
    backgroundColor: '#FF9500',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 12,
  },
  permissionButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  loadingOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <!-- Header -->
    <VView :style="styles.header">
      <VText :style="styles.headerTitle">Camera</VText>
      <VText :style="styles.photoCount">{{ photos.length }} photos</VText>
    </VView>

    <!-- Permission required screen -->
    <VView
      v-if="permissionChecked && !permissionGranted"
      :style="styles.permissionContainer"
    >
      <VText :style="styles.permissionIcon">📷</VText>
      <VText :style="styles.permissionTitle">Camera Access Required</VText>
      <VText :style="styles.permissionText">
        This app needs access to your camera to take photos.
        Please grant camera permission to continue.
      </VText>
      <VButton :style="styles.permissionButton" :on-press="requestPermission">
        <VText :style="styles.permissionButtonText">Grant Permission</VText>
      </VButton>
    </VView>

    <!-- Main content (permission granted or not yet checked) -->
    <VView v-else :style="{ flex: 1 }">
      <!-- Photo preview -->
      <VView :style="styles.preview">
        <VImage
          v-if="selectedPhoto"
          :source="{ uri: selectedPhoto.uri }"
          :style="styles.previewImage"
          resize-mode="contain"
        />
        <VView v-else :style="styles.previewPlaceholder">
          <VText :style="styles.placeholderIcon">📷</VText>
          <VText :style="styles.placeholderText">No photo selected</VText>
          <VText :style="styles.placeholderSubtext">
            Take a photo or pick one from your library to get started
          </VText>
        </VView>

        <!-- Preview overlay with timestamp -->
        <VView v-if="selectedPhoto" :style="styles.previewOverlay">
          <VText :style="styles.previewTime">
            {{ formatDate(selectedPhoto.timestamp) }}
          </VText>
          <VButton :style="styles.closePreview" :on-press="clearSelection">
            <VText :style="styles.closePreviewText">Close</VText>
          </VButton>
        </VView>
      </VView>

      <!-- Action buttons -->
      <VView :style="styles.buttonBar">
        <VButton :style="styles.captureButton" :on-press="takePhoto">
          <VText :style="styles.captureButtonText">Take Photo</VText>
        </VButton>
        <VButton :style="styles.libraryButton" :on-press="pickFromLibrary">
          <VText :style="styles.libraryButtonText">Library</VText>
        </VButton>
      </VView>

      <!-- Gallery strip -->
      <VView :style="styles.gallery">
        <VView :style="styles.galleryHeader">
          <VText :style="styles.galleryTitle">Gallery</VText>
          <VText :style="styles.galleryCount">
            {{ photos.length }} {{ photos.length === 1 ? 'photo' : 'photos' }}
          </VText>
        </VView>

        <VScrollView
          v-if="photos.length > 0"
          :style="styles.galleryScroll"
          horizontal
          :shows-horizontal-scroll-indicator="false"
        >
          <VButton
            v-for="photo in photos"
            :key="photo.id"
            :style="[
              styles.galleryItem,
              selectedPhoto?.id === photo.id && styles.galleryItemSelected,
            ]"
            :on-press="() => selectPhoto(photo)"
          >
            <VImage
              :source="{ uri: photo.uri }"
              :style="styles.galleryImage"
              resize-mode="cover"
            />
          </VButton>
        </VScrollView>

        <VView v-else :style="styles.galleryEmpty">
          <VText :style="styles.galleryEmptyText">
            Photos you take will appear here
          </VText>
        </VView>
      </VView>
    </VView>

    <!-- Loading overlay -->
    <VView v-if="loading" :style="styles.loadingOverlay">
      <VActivityIndicator size="large" color="#FFFFFF" />
    </VView>
  </VView>
</template>
