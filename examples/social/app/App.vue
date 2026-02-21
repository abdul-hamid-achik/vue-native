<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet } from '@vue-native/runtime'
import FeedScreen from './screens/FeedScreen.vue'
import ExploreScreen from './screens/ExploreScreen.vue'
import ProfileScreen from './screens/ProfileScreen.vue'

const activeTab = ref<'feed' | 'explore' | 'profile'>('feed')

const tabs = [
  { key: 'feed', label: 'Feed', icon: '🏠' },
  { key: 'explore', label: 'Explore', icon: '🔍' },
  { key: 'profile', label: 'Profile', icon: '👤' },
] as const

const styles = createStyleSheet({
  container: { flex: 1, backgroundColor: '#F2F2F7' },
  screen: { flex: 1 },
  tabBar: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    borderTopWidth: 1,
    borderTopColor: '#E5E5EA',
    paddingBottom: 20,
    paddingTop: 8,
  },
  tab: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 4,
  },
  tabIcon: { fontSize: 22 },
  tabLabel: { fontSize: 10, marginTop: 2, color: '#8E8E93' },
  tabLabelActive: { color: '#007AFF' },
})
</script>

<template>
  <VView :style="styles.container">
    <VView :style="styles.screen">
      <FeedScreen v-if="activeTab === 'feed'" />
      <ExploreScreen v-else-if="activeTab === 'explore'" />
      <ProfileScreen v-else />
    </VView>
    <VView :style="styles.tabBar">
      <VButton
        v-for="tab in tabs"
        :key="tab.key"
        :style="styles.tab"
        :onPress="() => activeTab = tab.key"
      >
        <VText :style="styles.tabIcon">{{ tab.icon }}</VText>
        <VText :style="[styles.tabLabel, activeTab === tab.key && styles.tabLabelActive]">
          {{ tab.label }}
        </VText>
      </VButton>
    </VView>
  </VView>
</template>
