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
  <VView :style="styles.value.container">
    <VScrollView :style="styles.value.scrollContent">
      <VText :style="styles.value.title">Theming</VText>
      <VText :style="styles.value.subtitle">
        {{ colorScheme.value === 'dark' ? 'Dark' : 'Light' }} mode active
      </VText>

      <!-- Theme Toggle -->
      <VView :style="styles.value.section">
        <VText :style="styles.value.sectionTitle">Appearance</VText>

        <VView :style="styles.value.row">
          <VText :style="styles.value.label">Current Mode</VText>
          <VView :style="styles.value.badge">
            <VText :style="styles.value.badgeText">
              {{ colorScheme.value }}
            </VText>
          </VView>
        </VView>

        <VView :style="styles.value.row">
          <VText :style="styles.value.label">System Preference</VText>
          <VView :style="styles.value.badge">
            <VText :style="styles.value.badgeText">
              {{ systemScheme.colorScheme.value }}
            </VText>
          </VView>
        </VView>

        <VButton :style="styles.value.toggleButton" :on-press="toggleColorScheme">
          <VText :style="styles.value.toggleText">
            Switch to {{ colorScheme.value === 'light' ? 'Dark' : 'Light' }}
          </VText>
        </VButton>
      </VView>

      <!-- Color Swatches -->
      <VView :style="styles.value.section">
        <VText :style="styles.value.sectionTitle">Color Palette</VText>
        <VView :style="styles.value.colorSwatches">
          <VView v-for="[name, color] in Object.entries(theme.value.colors)" :key="name">
            <VView :style="[styles.value.swatch, { backgroundColor: color }]" />
            <VText :style="styles.value.swatchLabel">{{ name }}</VText>
          </VView>
        </VView>
      </VView>

      <!-- Accessibility -->
      <VView :style="styles.value.section">
        <VText :style="styles.value.sectionTitle">Accessibility</VText>

        <VView :style="styles.value.row">
          <VText :style="styles.value.label">Notifications</VText>
          <VSwitch
            v-model="notificationsEnabled"
            accessibility-label="Toggle notifications"
            accessibility-role="switch"
            :accessibility-state="{ checked: notificationsEnabled }"
          />
        </VView>

        <VView :style="styles.value.separator" />

        <VView :style="styles.value.sliderRow">
          <VView :style="styles.value.row">
            <VText :style="styles.value.label">Font Size</VText>
            <VText :style="styles.value.label">{{ fontSize }}pt</VText>
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

        <VView :style="styles.value.separator" />

        <VText
          :style="[styles.value.label, { fontSize }]"
          accessibility-role="text"
        >
          Preview text at {{ fontSize }}pt
        </VText>
      </VView>

      <!-- RTL -->
      <VView :style="styles.value.section">
        <VText :style="styles.value.sectionTitle">Layout Direction</VText>

        <VView :style="styles.value.row">
          <VText :style="styles.value.label">RTL Mode</VText>
          <VView :style="styles.value.badge">
            <VText :style="styles.value.badgeText">
              {{ i18n.isRTL.value ? 'RTL' : 'LTR' }}
            </VText>
          </VView>
        </VView>

        <VView :style="{ flexDirection: 'row', gap: 8, marginTop: 8 }">
          <VButton
            :style="styles.value.rtlButton"
            :on-press="() => i18n.setLocale('en')"
            accessibility-label="Set English locale"
          >
            <VText :style="styles.value.rtlButtonText">English (LTR)</VText>
          </VButton>
          <VButton
            :style="styles.value.rtlButton"
            :on-press="() => i18n.setLocale('ar')"
            accessibility-label="Set Arabic locale"
          >
            <VText :style="styles.value.rtlButtonText">Arabic (RTL)</VText>
          </VButton>
        </VView>
      </VView>

      <!-- Error Boundary -->
      <VView :style="styles.value.errorSection">
        <VText :style="styles.value.sectionTitle">Error Boundary</VText>

        <ErrorBoundary :reset-keys="[crashCount]">
          <template #default>
            <VView v-if="shouldCrash">
              <!-- This will trigger an error boundary catch -->
              <VText>{{ (undefined as any).crash }}</VText>
            </VView>
            <VView v-else>
              <VText :style="styles.value.label">Component is healthy</VText>
              <VText :style="styles.value.infoText">
                Recovered {{ crashCount }} time(s)
              </VText>
              <VButton
                :style="[styles.value.crashButton, { marginTop: 12 }]"
                :on-press="triggerError"
                accessibility-label="Trigger error for testing"
              >
                <VText :style="styles.value.crashText">Trigger Error</VText>
              </VButton>
            </VView>
          </template>

          <template #fallback="{ error, reset }">
            <VView :style="styles.value.errorFallback">
              <VText :style="styles.value.errorTitle">Something went wrong</VText>
              <VText :style="styles.value.errorMessage">
                {{ error?.message ?? 'Unknown error' }}
              </VText>
              <VButton
                :style="styles.value.retryButton"
                :on-press="() => { handleReset(); reset() }"
              >
                <VText :style="styles.value.retryText">Retry</VText>
              </VButton>
            </VView>
          </template>
        </ErrorBoundary>
      </VView>
    </VScrollView>
  </VView>
</template>
