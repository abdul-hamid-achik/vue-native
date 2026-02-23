<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet, useNetwork, useHaptics } from '@thelacanians/runtime'

interface Post {
  id: number
  author: string
  handle: string
  avatarUrl: string
  content: string
  imageUrl?: string
  likes: number
  comments: number
  liked: boolean
  timeAgo: string
}

const { isConnected } = useNetwork()
const { vibrate } = useHaptics()

const refreshing = ref(false)

const posts = ref<Post[]>([
  {
    id: 1, author: 'Sarah Chen', handle: '@sarahc', timeAgo: '2m',
    avatarUrl: 'https://picsum.photos/seed/sarah/80/80',
    content: 'Just shipped a new feature using Vue Native — native iOS apps with Vue 3! 🚀',
    imageUrl: 'https://picsum.photos/seed/tech1/400/200',
    likes: 142, comments: 23, liked: false,
  },
  {
    id: 2, author: 'Marcus Rivera', handle: '@mrivera', timeAgo: '15m',
    avatarUrl: 'https://picsum.photos/seed/marcus/80/80',
    content: 'The Yoga layout engine makes building complex UIs surprisingly intuitive. FlexBox everywhere!',
    likes: 87, comments: 11, liked: true,
  },
  {
    id: 3, author: 'Ava Thompson', handle: '@avat', timeAgo: '1h',
    avatarUrl: 'https://picsum.photos/seed/ava/80/80',
    content: 'Hot reload on a native iOS app. Watching code changes appear in the simulator instantly is still magic to me 🔮',
    imageUrl: 'https://picsum.photos/seed/code1/400/220',
    likes: 256, comments: 44, liked: false,
  },
  {
    id: 4, author: 'James Park', handle: '@jpark_dev', timeAgo: '3h',
    avatarUrl: 'https://picsum.photos/seed/james/80/80',
    content: 'Writing my first Vue composable that talks to a Swift module. The bridge abstraction is clean.',
    likes: 63, comments: 8, liked: false,
  },
  {
    id: 5, author: 'Lena Müller', handle: '@lenadev', timeAgo: '5h',
    avatarUrl: 'https://picsum.photos/seed/lena/80/80',
    content: 'Dark mode support just landed. One `useColorScheme()` call and you\'re done.',
    imageUrl: 'https://picsum.photos/seed/dark1/400/200',
    likes: 198, comments: 31, liked: true,
  },
])

function toggleLike(post: Post) {
  if (!post.liked) {
    vibrate('light')
  }
  post.liked = !post.liked
  post.likes += post.liked ? 1 : -1
}

function onRefresh() {
  refreshing.value = true
  setTimeout(() => {
    // Prepend a new post
    posts.value.unshift({
      id: Date.now(), author: 'New Post', handle: '@fresh', timeAgo: 'just now',
      avatarUrl: 'https://picsum.photos/seed/new1/80/80',
      content: 'Just pulled to refresh and something new appeared! ✨',
      likes: 0, comments: 0, liked: false,
    })
    refreshing.value = false
  }, 1200)
}

const styles = createStyleSheet({
  container: { flex: 1, backgroundColor: '#F2F2F7' },
  offlineBanner: {
    backgroundColor: '#FF3B30',
    paddingVertical: 8,
    paddingHorizontal: 16,
    alignItems: 'center',
  },
  offlineText: { color: '#FFFFFF', fontSize: 13, fontWeight: '600' },
  header: {
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  headerTitle: { fontSize: 28, fontWeight: 'bold', color: '#1C1C1E' },
  card: {
    backgroundColor: '#FFFFFF',
    marginHorizontal: 0,
    marginBottom: 8,
    paddingBottom: 0,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 14,
    paddingBottom: 10,
    gap: 10,
  },
  avatar: { width: 42, height: 42, borderRadius: 21 },
  authorInfo: { flex: 1 },
  authorName: { fontSize: 15, fontWeight: '700', color: '#1C1C1E' },
  authorHandle: { fontSize: 13, color: '#8E8E93', marginTop: 1 },
  timeAgo: { fontSize: 12, color: '#C7C7CC' },
  content: {
    fontSize: 15,
    color: '#1C1C1E',
    lineHeight: 22,
    paddingHorizontal: 16,
    paddingBottom: 12,
  },
  postImage: { width: '100%', height: 200 },
  actions: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 10,
    gap: 20,
    borderTopWidth: 1,
    borderTopColor: '#F2F2F7',
  },
  actionButton: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  actionIcon: { fontSize: 16 },
  actionCount: { fontSize: 14, color: '#8E8E93' },
  actionCountLiked: { color: '#FF3B30' },
})
</script>

<template>
  <VView :style="styles.container">
    <!-- Offline banner -->
    <VView v-if="!isConnected" :style="styles.offlineBanner">
      <VText :style="styles.offlineText">No internet connection</VText>
    </VView>

    <VScrollView
      :style="styles.container"
      :showsVerticalScrollIndicator="false"
      :refreshing="refreshing"
      @refresh="onRefresh"
    >
      <!-- Header -->
      <VView :style="styles.header">
        <VText :style="styles.headerTitle">Feed</VText>
      </VView>

      <!-- Posts -->
      <VView v-for="post in posts" :key="post.id" :style="styles.card">
        <VView :style="styles.cardHeader">
          <VImage :source="{ uri: post.avatarUrl }" :style="styles.avatar" />
          <VView :style="styles.authorInfo">
            <VText :style="styles.authorName">{{ post.author }}</VText>
            <VText :style="styles.authorHandle">{{ post.handle }}</VText>
          </VView>
          <VText :style="styles.timeAgo">{{ post.timeAgo }}</VText>
        </VView>

        <VText :style="styles.content">{{ post.content }}</VText>

        <VImage
          v-if="post.imageUrl"
          :source="{ uri: post.imageUrl }"
          :style="styles.postImage"
          resizeMode="cover"
        />

        <VView :style="styles.actions">
          <VButton :style="styles.actionButton" :onPress="() => toggleLike(post)">
            <VText :style="styles.actionIcon">{{ post.liked ? '❤️' : '🤍' }}</VText>
            <VText :style="[styles.actionCount, post.liked && styles.actionCountLiked]">
              {{ post.likes }}
            </VText>
          </VButton>
          <VView :style="styles.actionButton">
            <VText :style="styles.actionIcon">💬</VText>
            <VText :style="styles.actionCount">{{ post.comments }}</VText>
          </VView>
          <VView :style="styles.actionButton">
            <VText :style="styles.actionIcon">↗️</VText>
          </VView>
        </VView>
      </VView>
    </VScrollView>
  </VView>
</template>
