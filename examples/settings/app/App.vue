<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

// --- State ---

const notifications = ref(true)
const darkMode = ref(false)
const hapticFeedback = ref(true)
const locationServices = ref(false)
const analyticsEnabled = ref(true)
const autoUpdate = ref(true)
const faceID = ref(false)
const emailDigest = ref(true)
const betaFeatures = ref(false)

const isLoading = ref(false)
const savedMessage = ref('')

function save() {
  isLoading.value = true
  savedMessage.value = ''
  // Simulate async save
  setTimeout(() => {
    isLoading.value = false
    savedMessage.value = 'Preferences saved!'
    setTimeout(() => { savedMessage.value = '' }, 2000)
  }, 1200)
}

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  header: {
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 12,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1C1C1E',
  },
  sectionContainer: {
    marginTop: 20,
    marginHorizontal: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    overflow: 'hidden',
  },
  sectionHeader: {
    paddingHorizontal: 16,
    paddingTop: 14,
    paddingBottom: 6,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#8E8E93',
    textTransform: 'uppercase' as any,
    letterSpacing: 0.5,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    minHeight: 50,
    borderTopWidth: 1,
    borderTopColor: '#F2F2F7',
  },
  rowFirst: {
    borderTopWidth: 0,
  },
  rowIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  rowLabel: {
    flex: 1,
    fontSize: 17,
    color: '#1C1C1E',
  },
  rowSubtitle: {
    fontSize: 13,
    color: '#8E8E93',
    marginTop: 1,
  },
  labelGroup: {
    flex: 1,
  },
  saveArea: {
    marginHorizontal: 16,
    marginTop: 24,
    marginBottom: 16,
  },
  saveButton: {
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 8,
  },
  saveButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
  successMessage: {
    alignItems: 'center',
    marginTop: 12,
  },
  successText: {
    fontSize: 14,
    color: '#34C759',
    fontWeight: '500',
  },
})

type SectionItem = {
  label: string
  subtitle?: string
  iconBg: string
  iconText: string
  model: ReturnType<typeof ref<boolean>>
  first?: boolean
}

type Section = {
  title: string
  items: SectionItem[]
}

const sections: Section[] = [
  {
    title: 'Notifications',
    items: [
      { label: 'Push Notifications', subtitle: 'Alerts, badges, sounds', iconBg: '#FF3B30', iconText: '🔔', model: notifications, first: true },
      { label: 'Email Digest', subtitle: 'Weekly summary', iconBg: '#007AFF', iconText: '✉️', model: emailDigest },
    ],
  },
  {
    title: 'Privacy & Security',
    items: [
      { label: 'Face ID', subtitle: 'Authenticate with Face ID', iconBg: '#5856D6', iconText: '🔒', model: faceID, first: true },
      { label: 'Location Services', iconBg: '#34C759', iconText: '📍', model: locationServices },
      { label: 'Analytics', subtitle: 'Help improve the app', iconBg: '#FF9500', iconText: '📊', model: analyticsEnabled },
    ],
  },
  {
    title: 'Appearance & Behavior',
    items: [
      { label: 'Dark Mode', iconBg: '#1C1C1E', iconText: '🌙', model: darkMode, first: true },
      { label: 'Haptic Feedback', iconBg: '#FF2D55', iconText: '📳', model: hapticFeedback },
      { label: 'Auto Update', iconBg: '#5AC8FA', iconText: '🔄', model: autoUpdate },
    ],
  },
  {
    title: 'Advanced',
    items: [
      { label: 'Beta Features', subtitle: 'Access experimental features', iconBg: '#AF52DE', iconText: '🧪', model: betaFeatures, first: true },
    ],
  },
]
</script>

<template>
  <VScrollView
    :style="styles.container"
    :showsVerticalScrollIndicator="false"
  >
    <!-- Header -->
    <VView :style="styles.header">
      <VText :style="styles.headerTitle">Settings</VText>
    </VView>

    <!-- Sections -->
    <VView v-for="section in sections" :key="section.title">
      <!-- Section header -->
      <VView :style="styles.sectionHeader">
        <VText :style="styles.sectionTitle">{{ section.title }}</VText>
      </VView>

      <!-- Section card -->
      <VView :style="styles.sectionContainer">
        <VView
          v-for="item in section.items"
          :key="item.label"
          :style="[styles.row, item.first && styles.rowFirst]"
        >
          <!-- Icon -->
          <VView :style="[styles.rowIcon, { backgroundColor: item.iconBg }]">
            <VText :style="{ fontSize: 18 }">{{ item.iconText }}</VText>
          </VView>

          <!-- Label group -->
          <VView :style="styles.labelGroup">
            <VText :style="styles.rowLabel">{{ item.label }}</VText>
            <VText v-if="item.subtitle" :style="styles.rowSubtitle">{{ item.subtitle }}</VText>
          </VView>

          <!-- Toggle -->
          <VSwitch
            v-model="item.model.value"
            :onTintColor="'#34C759'"
          />
        </VView>
      </VView>
    </VView>

    <!-- Save button -->
    <VView :style="styles.saveArea">
      <VButton :style="styles.saveButton" :onPress="save" :disabled="isLoading">
        <VActivityIndicator
          v-if="isLoading"
          :animating="true"
          color="#FFFFFF"
          size="small"
        />
        <VText :style="styles.saveButtonText">
          {{ isLoading ? 'Saving…' : 'Save Preferences' }}
        </VText>
      </VButton>

      <VView v-if="savedMessage" :style="styles.successMessage">
        <VText :style="styles.successText">{{ savedMessage }}</VText>
      </VView>
    </VView>
  </VScrollView>
</template>
