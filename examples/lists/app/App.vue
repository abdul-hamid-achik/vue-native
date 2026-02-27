<script setup lang="ts">
import { ref, computed, h } from 'vue'
import { createStyleSheet, useHaptics } from '@thelacanians/vue-native-runtime'
import type { FlatListRenderItemInfo } from '@thelacanians/vue-native-runtime'

// ─── Data ────────────────────────────────────────────────────────────────────

interface Contact {
  id: number
  name: string
  phone: string
  avatar: string
}

const allContacts: Contact[] = Array.from({ length: 500 }, (_, i) => ({
  id: i,
  name: `Contact ${i + 1}`,
  phone: `+1 (555) ${String(i).padStart(3, '0')}-${String(i * 7 % 10000).padStart(4, '0')}`,
  avatar: String.fromCodePoint(0x1F600 + (i % 20)),
}))

// Group contacts by first letter for section list
const sections = computed(() => {
  const groups: Record<string, Contact[]> = {}
  for (const c of allContacts) {
    const letter = c.name[0].toUpperCase()
    if (!groups[letter]) groups[letter] = []
    groups[letter].push(c)
  }
  return Object.entries(groups)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([title, data]) => ({ title, data }))
})

// ─── State ───────────────────────────────────────────────────────────────────

const activeTab = ref<'flat' | 'section' | 'basic'>('flat')
const isRefreshing = ref(false)
const flatListData = ref(allContacts.slice(0, 50))

const haptics = useHaptics()

// ─── Actions ─────────────────────────────────────────────────────────────────

function handleRefresh() {
  isRefreshing.value = true
  haptics.impact('medium')
  // Simulate a network refresh
  setTimeout(() => {
    isRefreshing.value = false
  }, 1500)
}

function loadMore() {
  const current = flatListData.value.length
  if (current >= allContacts.length) return
  const next = allContacts.slice(current, current + 50)
  flatListData.value = [...flatListData.value, ...next]
}

// ─── VFlatList render function ───────────────────────────────────────────────

function renderItem({ item, index }: FlatListRenderItemInfo<Contact>) {
  return h('VView', {
    style: {
      flexDirection: 'row',
      alignItems: 'center',
      paddingHorizontal: 16,
      paddingVertical: 8,
      backgroundColor: index % 2 === 0 ? '#FFFFFF' : '#F9F9FB',
    },
  }, [
    h('VText', { style: { fontSize: 28, marginRight: 12 } }, item.avatar),
    h('VView', { style: { flex: 1 } }, [
      h('VText', { style: { fontSize: 16, fontWeight: '500', color: '#1C1C1E' } }, item.name),
      h('VText', { style: { fontSize: 13, color: '#8E8E93', marginTop: 2 } }, item.phone),
    ]),
  ])
}

// Basic list data
const basicItems = ref([
  'Inbox — 3 new messages',
  'Sent — 12 items',
  'Drafts — 1 item',
  'Trash — empty',
  'Starred — 5 items',
])

// ─── Styles ──────────────────────────────────────────────────────────────────

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  header: {
    paddingTop: 56,
    paddingHorizontal: 20,
    paddingBottom: 12,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1C1C1E',
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
    backgroundColor: '#E5E5EA',
  },
  tabActive: {
    backgroundColor: '#007AFF',
  },
  tabText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#1C1C1E',
  },
  tabTextActive: {
    color: '#FFFFFF',
  },
  listContainer: {
    flex: 1,
  },
  sectionHeader: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    backgroundColor: '#F2F2F7',
  },
  sectionHeaderText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#8E8E93',
    textTransform: 'uppercase',
  },
  sectionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#F2F2F7',
  },
  sectionAvatar: {
    fontSize: 24,
    marginRight: 12,
  },
  sectionName: {
    fontSize: 16,
    color: '#1C1C1E',
  },
  sectionPhone: {
    fontSize: 13,
    color: '#8E8E93',
    marginTop: 2,
  },
  basicItem: {
    paddingHorizontal: 16,
    paddingVertical: 14,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#F2F2F7',
  },
  basicItemText: {
    fontSize: 16,
    color: '#1C1C1E',
  },
  counter: {
    textAlign: 'center',
    fontSize: 13,
    color: '#8E8E93',
    paddingVertical: 12,
  },
})
</script>

<template>
  <VView :style="styles.container">
    <!-- Header with tab bar -->
    <VView :style="styles.header">
      <VText :style="styles.title">Lists</VText>
      <VView :style="styles.tabBar">
        <VButton
          v-for="tab in (['flat', 'section', 'basic'] as const)"
          :key="tab"
          :style="[styles.tab, activeTab === tab && styles.tabActive]"
          :on-press="() => activeTab = tab"
        >
          <VText :style="[styles.tabText, activeTab === tab && styles.tabTextActive]">
            {{ tab === 'flat' ? 'VFlatList' : tab === 'section' ? 'VSectionList' : 'VList' }}
          </VText>
        </VButton>
      </VView>
    </VView>

    <!-- VFlatList — Virtualized, 500 items -->
    <VView v-if="activeTab === 'flat'" :style="styles.listContainer">
      <VFlatList
        :data="flatListData"
        :render-item="renderItem"
        :item-height="56"
        :style="{ flex: 1 }"
        @end-reached="loadMore"
      >
        <template #header>
          <VView :style="{ padding: 16, backgroundColor: '#F2F2F7' }">
            <VText :style="{ fontSize: 13, color: '#8E8E93' }">
              Showing {{ flatListData.length }} of {{ allContacts.length }} contacts (virtualized)
            </VText>
          </VView>
        </template>
      </VFlatList>
    </VView>

    <!-- VSectionList — Grouped contacts with pull-to-refresh -->
    <VView v-else-if="activeTab === 'section'" :style="styles.listContainer">
      <VScrollView :style="{ flex: 1 }">
        <VRefreshControl
          :refreshing="isRefreshing"
          :on-refresh="handleRefresh"
          tint-color="#007AFF"
          title="Pull to refresh..."
        />
        <VSectionList
          :sections="sections"
          :estimated-item-height="48"
          :style="{ flex: 1 }"
        >
          <template #sectionHeader="{ section }">
            <VView :style="styles.sectionHeader">
              <VText :style="styles.sectionHeaderText">{{ section.title }}</VText>
            </VView>
          </template>
          <template #item="{ item }">
            <VView :style="styles.sectionItem">
              <VText :style="styles.sectionAvatar">{{ (item as Contact).avatar }}</VText>
              <VView>
                <VText :style="styles.sectionName">{{ (item as Contact).name }}</VText>
                <VText :style="styles.sectionPhone">{{ (item as Contact).phone }}</VText>
              </VView>
            </VView>
          </template>
        </VSectionList>
      </VScrollView>
    </VView>

    <!-- VList — Basic list -->
    <VView v-else :style="styles.listContainer">
      <VScrollView :style="{ flex: 1 }">
        <VRefreshControl
          :refreshing="isRefreshing"
          :on-refresh="handleRefresh"
          tint-color="#007AFF"
        />
        <VList :style="{ flex: 1 }">
          <VView
            v-for="(item, idx) in basicItems"
            :key="idx"
            :style="styles.basicItem"
          >
            <VText :style="styles.basicItemText">{{ item }}</VText>
          </VView>
        </VList>
        <VText :style="styles.counter">{{ basicItems.length }} items</VText>
      </VScrollView>
    </VView>
  </VView>
</template>
