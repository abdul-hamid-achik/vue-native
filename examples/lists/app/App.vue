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
  haptics.vibrate('medium')
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
    paddingTop: 16,
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
  // Shared #header for all three lists. Kept at ~50pt tall so it matches the
  // :header-height VFlatList needs (its header is absolutely positioned).
  listHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
    paddingHorizontal: 16,
    paddingVertical: 16,
    backgroundColor: '#F2F2F7',
  },
  listHeaderText: {
    fontSize: 13,
    color: '#8E8E93',
    flexShrink: 1,
  },
  refreshButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
    backgroundColor: '#007AFF',
    flexShrink: 0,
  },
  refreshButtonText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#FFFFFF',
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
})
</script>

<template>
  <VSafeArea :style="styles.container">
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

    <!--
      Each list below is the scrolling root (flex: 1). VFlatList, VSectionList
      and VList are all UITableView/RecyclerView-backed, so wrapping one in a
      VScrollView defeats virtualization and risks the re-entrant layout loop
      described in AGENTS.md. Header content goes through the list's own
      #header slot instead of an outer scroll view.
    -->

    <!-- VFlatList — Virtualized, 500 items -->
    <VFlatList
      v-if="activeTab === 'flat'"
      :data="flatListData"
      :render-item="renderItem"
      :item-height="56"
      :header-height="50"
      :style="{ flex: 1 }"
      @end-reached="loadMore"
    >
      <!-- #header is absolutely positioned, so :header-height must match the
           header's real height or it overlays the first rows. -->
      <template #header>
        <VView :style="styles.listHeader">
          <VText :style="styles.listHeaderText">
            Showing {{ flatListData.length }} of {{ allContacts.length }} contacts (virtualized)
          </VText>
        </VView>
      </template>
    </VFlatList>

    <!-- VSectionList — Grouped contacts -->
    <VSectionList
      v-else-if="activeTab === 'section'"
      :sections="sections"
      :estimated-item-height="48"
      :style="{ flex: 1 }"
    >
      <template #header>
        <VView :style="styles.listHeader">
          <VText :style="styles.listHeaderText">{{ sections.length }} groups, {{ allContacts.length }} contacts</VText>
          <VButton :style="styles.refreshButton" :on-press="handleRefresh">
            <VText :style="styles.refreshButtonText">
              {{ isRefreshing ? 'Refreshing…' : 'Refresh' }}
            </VText>
          </VButton>
        </VView>
      </template>
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

    <!-- VList — Basic list. VList is data-driven: pass :data and render each row
         through #item. It has no default slot, so v-for children render nothing. -->
    <VList
      v-else
      :data="basicItems"
      :estimated-item-height="45"
      :style="{ flex: 1 }"
    >
      <template #header>
        <VView :style="styles.listHeader">
          <VText :style="styles.listHeaderText">{{ basicItems.length }} items</VText>
          <VButton :style="styles.refreshButton" :on-press="handleRefresh">
            <VText :style="styles.refreshButtonText">
              {{ isRefreshing ? 'Refreshing…' : 'Refresh' }}
            </VText>
          </VButton>
        </VView>
      </template>
      <template #item="{ item }">
        <VView :style="styles.basicItem">
          <VText :style="styles.basicItemText">{{ item }}</VText>
        </VView>
      </template>
    </VList>
  </VSafeArea>
</template>
