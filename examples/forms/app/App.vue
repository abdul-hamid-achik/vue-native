<script setup lang="ts">
import { ref, computed } from 'vue'
import { createStyleSheet, useHaptics, useKeyboard } from '@thelacanians/vue-native-runtime'
import type { RadioOption, DropdownOption } from '@thelacanians/vue-native-runtime'

// ─── Form state ──────────────────────────────────────────────────────────────

const name = ref('')
const email = ref('')
const agreeToTerms = ref(false)
const receiveNewsletter = ref(true)
const priority = ref('medium')
const category = ref('')
const volume = ref(50)
const notificationsEnabled = ref(true)

const priorityOptions: RadioOption[] = [
  { label: 'Low', value: 'low' },
  { label: 'Medium', value: 'medium' },
  { label: 'High', value: 'high' },
]

const categoryOptions: DropdownOption[] = [
  { label: 'General', value: 'general' },
  { label: 'Bug Report', value: 'bug' },
  { label: 'Feature Request', value: 'feature' },
  { label: 'Support', value: 'support' },
]

// ─── Composables ─────────────────────────────────────────────────────────────

const haptics = useHaptics()
const keyboard = useKeyboard()

// ─── Validation ──────────────────────────────────────────────────────────────

const isEmailValid = computed(() => {
  if (!email.value) return true
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value)
})

const isFormValid = computed(() => {
  return name.value.trim().length > 0
    && email.value.trim().length > 0
    && isEmailValid.value
    && agreeToTerms.value
    && category.value !== ''
})

// ─── Actions ─────────────────────────────────────────────────────────────────

function handleSubmit() {
  if (!isFormValid.value) return
  haptics.notification('success')
  keyboard.dismiss()
}

function handleReset() {
  name.value = ''
  email.value = ''
  agreeToTerms.value = false
  receiveNewsletter.value = true
  priority.value = 'medium'
  category.value = ''
  volume.value = 50
  notificationsEnabled.value = true
  haptics.impact('light')
}

// ─── Styles ──────────────────────────────────────────────────────────────────

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  scrollContent: {
    padding: 20,
    paddingBottom: 40,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1C1C1E',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 15,
    color: '#8E8E93',
    marginBottom: 24,
  },
  section: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#8E8E93',
    textTransform: 'uppercase',
    marginBottom: 12,
  },
  label: {
    fontSize: 16,
    color: '#1C1C1E',
    marginBottom: 6,
  },
  input: {
    borderWidth: 1,
    borderColor: '#D1D1D6',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    backgroundColor: '#FAFAFA',
    marginBottom: 16,
  },
  inputError: {
    borderColor: '#FF3B30',
  },
  errorText: {
    fontSize: 13,
    color: '#FF3B30',
    marginTop: -12,
    marginBottom: 16,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  sliderRow: {
    marginBottom: 16,
  },
  sliderLabel: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  sliderValue: {
    fontSize: 14,
    color: '#007AFF',
    fontWeight: '600',
  },
  pickerLabel: {
    fontSize: 16,
    color: '#1C1C1E',
    marginBottom: 8,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 8,
  },
  submitButton: {
    flex: 1,
    backgroundColor: '#007AFF',
    paddingVertical: 14,
    borderRadius: 10,
    alignItems: 'center',
  },
  submitButtonDisabled: {
    backgroundColor: '#B0B0B0',
  },
  submitText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
  resetButton: {
    flex: 1,
    backgroundColor: '#E5E5EA',
    paddingVertical: 14,
    borderRadius: 10,
    alignItems: 'center',
  },
  resetText: {
    color: '#1C1C1E',
    fontSize: 17,
    fontWeight: '600',
  },
  keyboardStatus: {
    fontSize: 12,
    color: '#8E8E93',
    textAlign: 'center',
    marginTop: 12,
  },
})
</script>

<template>
  <VKeyboardAvoiding :style="styles.container">
    <VScrollView :style="styles.scrollContent">
      <VText :style="styles.title">Preferences</VText>
      <VText :style="styles.subtitle">Configure your app settings</VText>

      <!-- Text Inputs Section -->
      <VView :style="styles.section">
        <VText :style="styles.sectionTitle">Account</VText>

        <VText :style="styles.label">Name</VText>
        <VInput
          v-model="name"
          placeholder="Enter your name"
          :style="styles.input"
          accessibility-label="Name input"
        />

        <VText :style="styles.label">Email</VText>
        <VInput
          v-model="email"
          placeholder="email@example.com"
          keyboard-type="email-address"
          auto-capitalize="none"
          :style="[styles.input, !isEmailValid && styles.inputError]"
          accessibility-label="Email input"
        />
        <VText v-if="!isEmailValid" :style="styles.errorText">
          Please enter a valid email address
        </VText>
      </VView>

      <!-- Toggle Switches Section -->
      <VView :style="styles.section">
        <VText :style="styles.sectionTitle">Notifications</VText>

        <VView :style="styles.row">
          <VText :style="styles.label">Enable Notifications</VText>
          <VSwitch
            v-model="notificationsEnabled"
            accessibility-label="Toggle notifications"
          />
        </VView>

        <VView :style="styles.row">
          <VText :style="styles.label">Newsletter</VText>
          <VSwitch
            v-model="receiveNewsletter"
            accessibility-label="Toggle newsletter"
          />
        </VView>
      </VView>

      <!-- Radio + Dropdown Section -->
      <VView :style="styles.section">
        <VText :style="styles.sectionTitle">Details</VText>

        <VText :style="styles.pickerLabel">Priority</VText>
        <VRadio
          v-model="priority"
          :options="priorityOptions"
          accessibility-label="Select priority"
        />

        <VText :style="[styles.pickerLabel, { marginTop: 16 }]">Category</VText>
        <VDropdown
          v-model="category"
          :options="categoryOptions"
          placeholder="Select a category..."
          accessibility-label="Select category"
        />
      </VView>

      <!-- Slider + Picker Section -->
      <VView :style="styles.section">
        <VText :style="styles.sectionTitle">Preferences</VText>

        <VView :style="styles.sliderRow">
          <VView :style="styles.sliderLabel">
            <VText :style="styles.label">Volume</VText>
            <VText :style="styles.sliderValue">{{ volume }}%</VText>
          </VView>
          <VSlider
            v-model="volume"
            :minimum-value="0"
            :maximum-value="100"
            :step="1"
            accessibility-label="Volume slider"
          />
        </VView>

        <VView :style="styles.row">
          <VText :style="styles.label">Agree to Terms</VText>
          <VCheckbox
            v-model="agreeToTerms"
            accessibility-label="Agree to terms checkbox"
          />
        </VView>
      </VView>

      <!-- Submit / Reset -->
      <VView :style="styles.buttonRow">
        <VButton
          :style="[styles.resetButton]"
          :on-press="handleReset"
          accessibility-label="Reset form"
          accessibility-role="button"
        >
          <VText :style="styles.resetText">Reset</VText>
        </VButton>

        <VButton
          :style="[styles.submitButton, !isFormValid && styles.submitButtonDisabled]"
          :on-press="handleSubmit"
          :disabled="!isFormValid"
          accessibility-label="Submit form"
          accessibility-role="button"
        >
          <VText :style="styles.submitText">Submit</VText>
        </VButton>
      </VView>

      <VText :style="styles.keyboardStatus">
        Keyboard: {{ keyboard.isVisible.value ? 'visible' : 'hidden' }}
      </VText>
    </VScrollView>
  </VKeyboardAvoiding>
</template>
