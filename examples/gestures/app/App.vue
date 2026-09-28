<script setup lang="ts">
import { ref } from 'vue'
import {
  createStyleSheet,
  VView,
  VText,
  VPressable,
} from '@thelacanians/vue-native-runtime'
import PanDemo from './demos/PanDemo.vue'
import PinchRotateDemo from './demos/PinchRotateDemo.vue'
import SwipeDemo from './demos/SwipeDemo.vue'
import ComposedDemo from './demos/ComposedDemo.vue'
import AllGesturesDemo from './demos/AllGesturesDemo.vue'

type Tab = 'pan' | 'pinch' | 'swipe' | 'composed' | 'all'

const activeTab = ref<Tab>('pan')

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  tabBar: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  tab: {
    flex: 1,
    paddingVertical: 16,
    alignItems: 'center',
  },
  tabActive: {
    borderBottomWidth: 2,
    borderBottomColor: '#007AFF',
  },
  tabText: {
    fontSize: 14,
    color: '#666666',
  },
  tabTextActive: {
    color: '#007AFF',
    fontWeight: '600',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
})
</script>

<template>
  <VView :style="styles.container">
    <!-- Tab Bar -->
    <VView :style="styles.tabBar">
      <VPressable
        v-for="tab in (['pan', 'pinch', 'swipe', 'composed', 'all'] as Tab[])"
        :key="tab"
        :style="[styles.tab, activeTab === tab && styles.tabActive]"
        :on-press="() => activeTab = tab"
      >
        <VText :style="[styles.tabText, activeTab === tab && styles.tabTextActive]">
          {{ tab.charAt(0).toUpperCase() + tab.slice(1) }}
        </VText>
      </VPressable>
    </VView>

    <!-- Pan Gesture Demo -->
    <VView v-if="activeTab === 'pan'" :style="styles.content">
      <PanDemo />
    </VView>

    <!-- Pinch/Rotate Demo -->
    <VView v-else-if="activeTab === 'pinch'" :style="styles.content">
      <PinchRotateDemo />
    </VView>

    <!-- Swipe Demo -->
    <VView v-else-if="activeTab === 'swipe'" :style="styles.content">
      <SwipeDemo />
    </VView>

    <!-- Composed Gestures Demo -->
    <VView v-else-if="activeTab === 'composed'" :style="styles.content">
      <ComposedDemo />
    </VView>

    <!-- All Gestures Demo -->
    <VView v-else-if="activeTab === 'all'" :style="styles.content">
      <AllGesturesDemo />
    </VView>
  </VView>
</template>
