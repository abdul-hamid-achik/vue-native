<script setup lang="ts">
import { ref } from 'vue'
import {
  createDynamicStyleSheet,
  ErrorBoundary,
  useColorScheme,
  useI18n,
} from '@thelacanians/vue-native-runtime'
import { useTheme } from './theme'

// ─── Theme ───────────────────────────────────────────────────────────────────

const { theme, colorScheme, toggleColorScheme } = useTheme()

// ─── System color scheme sync ────────────────────────────────────────────────

const systemScheme = useColorScheme()
const i18n = useI18n()

// ─── Error Boundary demo ────────────────────────────────────────────────────

const crashCount = ref(0)
const shouldCrash = ref(false)

function triggerError() {
  shouldCrash.value = true
}

function handleReset() {
  shouldCrash.value = false
  crashCount.value++
}

// If shouldCrash is true, ErrorBoundary's child will throw
// We simulate this with a v-if guard — the actual crash component will throw on render

// ─── Accessibility demo state ────────────────────────────────────────────────

const notificationsEnabled = ref(true)
const fontSize = ref(16)

// ─── Dynamic styles ──────────────────────────────────────────────────────────

const styles = createDynamicStyleSheet(theme, t => ({
  container: {
    flex: 1,
    backgroundColor: t.colors.background,
  },
  scrollContent: {
    padding: t.spacing.lg,
    paddingBottom: 40,
  },
  title: {
    fontSize: t.fontSize.heading,
    fontWeight: 'bold' as const,
    color: t.colors.text,
    marginBottom: t.spacing.xs,
  },
  subtitle: {
    fontSize: t.fontSize.body - 1,
    color: t.colors.textSecondary,
    marginBottom: t.spacing.lg,
  },
  section: {
    backgroundColor: t.colors.surface,
    borderRadius: t.borderRadius.lg,
    padding: t.spacing.md,
    marginBottom: t.spacing.md,
  },
  sectionTitle: {
    fontSize: t.fontSize.caption + 1,
    fontWeight: '600' as const,
    color: t.colors.textSecondary,
    textTransform: 'uppercase' as const,
    marginBottom: t.spacing.sm,
  },
  row: {
    flexDirection: 'row' as const,
    justifyContent: 'space-between' as const,
    alignItems: 'center' as const,
    paddingVertical: t.spacing.sm,
  },
  label: {
    fontSize: t.fontSize.body,
    color: t.colors.text,
  },
  badge: {
    paddingHorizontal: t.spacing.sm,
    paddingVertical: t.spacing.xs,
    borderRadius: t.borderRadius.sm,
    backgroundColor: t.colors.primary,
  },
  badgeText: {
    fontSize: t.fontSize.caption,
    color: t.colors.primaryText,
    fontWeight: '600' as const,
  },
  colorSwatches: {
    flexDirection: 'row' as const,
    flexWrap: 'wrap' as const,
    gap: t.spacing.sm,
    marginTop: t.spacing.sm,
  },
  swatch: {
    width: 48,
    height: 48,
    borderRadius: t.borderRadius.md,
    borderWidth: 1,
    borderColor: t.colors.border,
  },
  swatchLabel: {
    fontSize: t.fontSize.caption - 2,
    color: t.colors.textSecondary,
    marginTop: 2,
    textAlign: 'center' as const,
  },
  toggleButton: {
    backgroundColor: t.colors.primary,
    paddingVertical: t.spacing.sm + 4,
    paddingHorizontal: t.spacing.lg,
    borderRadius: t.borderRadius.md,
    alignItems: 'center' as const,
  },
  toggleText: {
    color: t.colors.primaryText,
    fontSize: t.fontSize.body,
    fontWeight: '600' as const,
  },
  errorSection: {
    backgroundColor: t.colors.surface,
    borderRadius: t.borderRadius.lg,
    padding: t.spacing.md,
    marginBottom: t.spacing.md,
  },
  errorFallback: {
    padding: t.spacing.md,
    backgroundColor: t.colors.error + '20',
    borderRadius: t.borderRadius.md,
    borderWidth: 1,
    borderColor: t.colors.error,
  },
  errorTitle: {
    fontSize: t.fontSize.body,
    fontWeight: '600' as const,
    color: t.colors.error,
    marginBottom: t.spacing.sm,
  },
  errorMessage: {
    fontSize: t.fontSize.caption,
    color: t.colors.textSecondary,
    marginBottom: t.spacing.sm,
  },
  retryButton: {
    backgroundColor: t.colors.error,
    paddingVertical: t.spacing.sm,
    paddingHorizontal: t.spacing.md,
    borderRadius: t.borderRadius.sm,
    alignSelf: 'flex-start' as const,
  },
  retryText: {
    color: '#FFFFFF',
    fontSize: t.fontSize.caption,
    fontWeight: '600' as const,
  },
  crashButton: {
    backgroundColor: t.colors.warning,
    paddingVertical: t.spacing.sm + 4,
    paddingHorizontal: t.spacing.lg,
    borderRadius: t.borderRadius.md,
    alignItems: 'center' as const,
  },
  crashText: {
    color: '#FFFFFF',
    fontSize: t.fontSize.body,
    fontWeight: '600' as const,
  },
  infoText: {
    fontSize: t.fontSize.caption,
    color: t.colors.textSecondary,
    marginTop: t.spacing.sm,
  },
  sliderRow: {
    marginTop: t.spacing.sm,
  },
  rtlButton: {
    backgroundColor: t.colors.surfaceSecondary,
    paddingVertical: t.spacing.sm,
    paddingHorizontal: t.spacing.md,
    borderRadius: t.borderRadius.sm,
  },
  rtlButtonText: {
    fontSize: t.fontSize.caption,
    color: t.colors.text,
    fontWeight: '500' as const,
  },
  separator: {
    height: 1,
    backgroundColor: t.colors.separator,
    marginVertical: t.spacing.sm,
  },
}))
</script>

<template>
  <VView :style="styles.container">
    <VScrollView :style="styles.scrollContent">
      <VText :style="styles.title">Theming</VText>
      <VText :style="styles.subtitle">
        {{ colorScheme === 'dark' ? 'Dark' : 'Light' }} mode active
      </VText>

      <!-- Theme Toggle -->
      <VView :style="styles.section">
        <VText :style="styles.sectionTitle">Appearance</VText>

        <VView :style="styles.row">
          <VText :style="styles.label">Current Mode</VText>
          <VView :style="styles.badge">
            <VText :style="styles.badgeText">
              {{ colorScheme }}
            </VText>
          </VView>
        </VView>

        <VView :style="styles.row">
          <VText :style="styles.label">System Preference</VText>
          <VView :style="styles.badge">
            <VText :style="styles.badgeText">
              {{ systemScheme.colorScheme.value }}
            </VText>
          </VView>
        </VView>

        <VButton :style="styles.toggleButton" :on-press="toggleColorScheme">
          <VText :style="styles.toggleText">
            Switch to {{ colorScheme === 'light' ? 'Dark' : 'Light' }}
          </VText>
        </VButton>
      </VView>

      <!-- Color Swatches -->
      <VView :style="styles.section">
        <VText :style="styles.sectionTitle">Color Palette</VText>
        <VView :style="styles.colorSwatches">
          <VView v-for="[name, color] in Object.entries(theme.colors)" :key="name">
            <VView :style="[styles.swatch, { backgroundColor: color }]" />
            <VText :style="styles.swatchLabel">{{ name }}</VText>
          </VView>
        </VView>
      </VView>

      <!-- Accessibility -->
      <VView :style="styles.section">
        <VText :style="styles.sectionTitle">Accessibility</VText>

        <VView :style="styles.row">
          <VText :style="styles.label">Notifications</VText>
          <VSwitch
            v-model="notificationsEnabled"
            accessibility-label="Toggle notifications"
            accessibility-role="switch"
            :accessibility-state="{ checked: notificationsEnabled }"
          />
        </VView>

        <VView :style="styles.separator" />

        <VView :style="styles.sliderRow">
          <VView :style="styles.row">
            <VText :style="styles.label">Font Size</VText>
            <VText :style="styles.label">{{ fontSize }}pt</VText>
          </VView>
          <VSlider
            v-model="fontSize"
            :minimum-value="12"
            :maximum-value="24"
            :step="1"
            accessibility-label="Adjust font size"
            accessibility-role="adjustable"
          />
        </VView>

        <VView :style="styles.separator" />

        <VText
          :style="[styles.label, { fontSize }]"
          accessibility-role="text"
        >
          Preview text at {{ fontSize }}pt
        </VText>
      </VView>

      <!-- RTL -->
      <VView :style="styles.section">
        <VText :style="styles.sectionTitle">Layout Direction</VText>

        <VView :style="styles.row">
          <VText :style="styles.label">RTL Mode</VText>
          <VView :style="styles.badge">
            <VText :style="styles.badgeText">
              {{ i18n.isRTL.value ? 'RTL' : 'LTR' }}
            </VText>
          </VView>
        </VView>

        <VView :style="{ flexDirection: 'row', gap: 8, marginTop: 8 }">
          <VButton
            :style="styles.rtlButton"
            :on-press="() => i18n.setLocale('en')"
            accessibility-label="Set English locale"
          >
            <VText :style="styles.rtlButtonText">English (LTR)</VText>
          </VButton>
          <VButton
            :style="styles.rtlButton"
            :on-press="() => i18n.setLocale('ar')"
            accessibility-label="Set Arabic locale"
          >
            <VText :style="styles.rtlButtonText">Arabic (RTL)</VText>
          </VButton>
        </VView>
      </VView>

      <!-- Error Boundary -->
      <VView :style="styles.errorSection">
        <VText :style="styles.sectionTitle">Error Boundary</VText>

        <ErrorBoundary :reset-keys="[crashCount]">
          <template #default>
            <VView v-if="shouldCrash">
              <!-- This will trigger an error boundary catch -->
              <VText>{{ (undefined as any).crash }}</VText>
            </VView>
            <VView v-else>
              <VText :style="styles.label">Component is healthy</VText>
              <VText :style="styles.infoText">
                Recovered {{ crashCount }} time(s)
              </VText>
              <VButton
                :style="[styles.crashButton, { marginTop: 12 }]"
                :on-press="triggerError"
                accessibility-label="Trigger error for testing"
              >
                <VText :style="styles.crashText">Trigger Error</VText>
              </VButton>
            </VView>
          </template>

          <template #fallback="{ error, reset }">
            <VView :style="styles.errorFallback">
              <VText :style="styles.errorTitle">Something went wrong</VText>
              <VText :style="styles.errorMessage">
                {{ error?.message ?? 'Unknown error' }}
              </VText>
              <VButton
                :style="styles.retryButton"
                :on-press="() => { handleReset(); reset() }"
              >
                <VText :style="styles.retryText">Retry</VText>
              </VButton>
            </VView>
          </template>
        </ErrorBoundary>
      </VView>
    </VScrollView>
  </VView>
</template>
