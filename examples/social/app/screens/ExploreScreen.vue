<script setup lang="ts">
import { ref, computed } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

interface Photo {
  id: number
  url: string
  caption: string
}

const photos = ref<Photo[]>([
  { id: 1, url: 'https://picsum.photos/seed/a1/400/400', caption: 'Mountains' },
  { id: 2, url: 'https://picsum.photos/seed/a2/400/400', caption: 'Ocean' },
  { id: 3, url: 'https://picsum.photos/seed/a3/400/400', caption: 'Forest' },
  { id: 4, url: 'https://picsum.photos/seed/a4/400/400', caption: 'City' },
  { id: 5, url: 'https://picsum.photos/seed/a5/400/400', caption: 'Desert' },
  { id: 6, url: 'https://picsum.photos/seed/a6/400/400', caption: 'Snow' },
  { id: 7, url: 'https://picsum.photos/seed/a7/400/400', caption: 'Sunset' },
  { id: 8, url: 'https://picsum.photos/seed/a8/400/400', caption: 'Garden' },
  { id: 9, url: 'https://picsum.photos/seed/a9/400/400', caption: 'Lake' },
])

const searchText = ref('')

// Render in rows of 3 to avoid flexWrap issues in Yoga
const rows = computed(() => {
  const r: Photo[][] = []
  for (let i = 0; i < photos.value.length; i += 3) {
    r.push(photos.value.slice(i, i + 3))
  }
  return r
})

const styles = createStyleSheet({
  container: { flex: 1, backgroundColor: '#F2F2F7' },
  header: {
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
    gap: 12,
  },
  headerTitle: { fontSize: 28, fontWeight: 'bold', color: '#1C1C1E' },
  searchBar: {
    height: 36,
    backgroundColor: '#F2F2F7',
    borderRadius: 10,
    paddingHorizontal: 12,
    fontSize: 15,
    color: '#1C1C1E',
  },
  grid: {
    padding: 2,
  },
  row: {
    flexDirection: 'row',
    gap: 2,
    marginBottom: 2,
  },
  cell: { flex: 1, height: 120 },
  image: { width: '100%', height: '100%' },
  captionContainer: {
    backgroundColor: 'rgba(0,0,0,0.3)',
    paddingHorizontal: 6,
    paddingVertical: 3,
  },
  captionText: { fontSize: 10, color: '#FFFFFF', fontWeight: '500' },
})
</script>

<template>
  <VScrollView :style="styles.container" :shows-vertical-scroll-indicator="false">
    <VView :style="styles.header">
      <VText :style="styles.headerTitle">Explore</VText>
      <VInput
        v-model="searchText"
        placeholder="Search photos…"
        :style="styles.searchBar"
      />
    </VView>
    <VView :style="styles.grid">
      <VView v-for="(row, rowIndex) in rows" :key="rowIndex" :style="styles.row">
        <VView v-for="photo in row" :key="photo.id" :style="styles.cell">
          <VImage :source="{ uri: photo.url }" :style="styles.image" resize-mode="cover" />
          <VView :style="styles.captionContainer">
            <VText :style="styles.captionText">{{ photo.caption }}</VText>
          </VView>
        </VView>
      </VView>
    </VView>
  </VScrollView>
</template>
