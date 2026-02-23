<script setup lang="ts">
import { ref, computed } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const postsCount = ref(142)
const followersCount = ref(3847)
const followingCount = ref(291)

const bio = ref('Building cool things with Vue Native 🚀\nMobile dev by day, hacker by night.')
const profileImageUrl = 'https://picsum.photos/seed/profile_main/200/200'

interface StatItem {
  label: string
  value: number
}

const stats = computed<StatItem[]>(() => [
  { label: 'Posts', value: postsCount.value },
  { label: 'Followers', value: followersCount.value },
  { label: 'Following', value: followingCount.value },
])

// Skills shown as progress bars
const skills = [
  { label: 'Vue.js', progress: 0.95 },
  { label: 'iOS Development', progress: 0.72 },
  { label: 'TypeScript', progress: 0.88 },
  { label: 'Swift', progress: 0.61 },
  { label: 'Yoga / FlexBox', progress: 0.80 },
]

const following = ref(false)

const styles = createStyleSheet({
  container: { flex: 1, backgroundColor: '#F2F2F7' },
  header: {
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  headerTitle: { fontSize: 28, fontWeight: 'bold', color: '#1C1C1E' },
  profileCard: {
    backgroundColor: '#FFFFFF',
    marginTop: 0,
    paddingHorizontal: 16,
    paddingVertical: 20,
    alignItems: 'center',
    gap: 12,
  },
  avatar: { width: 96, height: 96, borderRadius: 48, borderWidth: 3, borderColor: '#007AFF' },
  name: { fontSize: 22, fontWeight: 'bold', color: '#1C1C1E' },
  handle: { fontSize: 14, color: '#8E8E93' },
  bio: { fontSize: 14, color: '#3C3C43', textAlign: 'center', lineHeight: 20 },
  statsRow: { flexDirection: 'row', gap: 0, marginTop: 4 },
  statCell: { flex: 1, alignItems: 'center', paddingVertical: 8 },
  statValue: { fontSize: 20, fontWeight: 'bold', color: '#1C1C1E' },
  statLabel: { fontSize: 12, color: '#8E8E93', marginTop: 2 },
  statDivider: { width: 1, backgroundColor: '#E5E5EA', marginVertical: 8 },
  followButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 32,
    paddingVertical: 10,
    borderRadius: 10,
    marginTop: 4,
  },
  followButtonFollowing: { backgroundColor: '#FFFFFF', borderWidth: 1, borderColor: '#007AFF' },
  followButtonText: { color: '#FFFFFF', fontWeight: '600', fontSize: 15 },
  followButtonTextFollowing: { color: '#007AFF' },
  section: {
    backgroundColor: '#FFFFFF',
    marginTop: 12,
    marginHorizontal: 0,
  },
  sectionHeader: {
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#F2F2F7',
  },
  sectionTitle: { fontSize: 17, fontWeight: '600', color: '#1C1C1E' },
  skillRow: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    gap: 6,
    borderTopWidth: 1,
    borderTopColor: '#F2F2F7',
  },
  skillHeader: { flexDirection: 'row', justifyContent: 'space-between' },
  skillLabel: { fontSize: 14, color: '#1C1C1E' },
  skillPct: { fontSize: 13, color: '#8E8E93' },
  progressBar: { height: 6, borderRadius: 3, backgroundColor: '#F2F2F7' },
  progressFill: { height: '100%', borderRadius: 3, backgroundColor: '#007AFF' },
})
</script>

<template>
  <VScrollView :style="styles.container" :showsVerticalScrollIndicator="false">
    <VView :style="styles.header">
      <VText :style="styles.headerTitle">Profile</VText>
    </VView>

    <!-- Profile card -->
    <VView :style="styles.profileCard">
      <VImage :source="{ uri: profileImageUrl }" :style="styles.avatar" resizeMode="cover" />
      <VText :style="styles.name">Alex Johnson</VText>
      <VText :style="styles.handle">@alexj</VText>
      <VText :style="styles.bio">{{ bio }}</VText>

      <!-- Stats -->
      <VView :style="styles.statsRow">
        <VView v-for="(stat, i) in stats" :key="stat.label" :style="styles.statCell">
          <VText :style="styles.statValue">{{ stat.value.toLocaleString() }}</VText>
          <VText :style="styles.statLabel">{{ stat.label }}</VText>
        </VView>
      </VView>

      <!-- Follow button -->
      <VButton
        :style="[styles.followButton, following && styles.followButtonFollowing]"
        :onPress="() => following = !following"
      >
        <VText :style="[styles.followButtonText, following && styles.followButtonTextFollowing]">
          {{ following ? 'Following' : 'Follow' }}
        </VText>
      </VButton>
    </VView>

    <!-- Skills section with VProgressBar -->
    <VView :style="styles.section">
      <VView :style="styles.sectionHeader">
        <VText :style="styles.sectionTitle">Skills</VText>
      </VView>
      <VView v-for="skill in skills" :key="skill.label" :style="styles.skillRow">
        <VView :style="styles.skillHeader">
          <VText :style="styles.skillLabel">{{ skill.label }}</VText>
          <VText :style="styles.skillPct">{{ Math.round(skill.progress * 100) }}%</VText>
        </VView>
        <VProgressBar
          :progress="skill.progress"
          progressTintColor="#007AFF"
          trackTintColor="#F2F2F7"
          :style="{ marginTop: 4 }"
        />
      </VView>
    </VView>
  </VScrollView>
</template>
