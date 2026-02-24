<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet, useAsyncStorage, useHaptics } from '@thelacanians/vue-native-runtime'
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()
const { setItem } = useAsyncStorage()
const { vibrate } = useHaptics()

const email = ref('')
const password = ref('')
const errorMessage = ref('')
const loading = ref(false)

async function handleLogin() {
  errorMessage.value = ''

  if (!email.value.trim()) {
    errorMessage.value = 'Please enter your email'
    vibrate('error')
    return
  }
  if (!password.value.trim()) {
    errorMessage.value = 'Please enter your password'
    vibrate('error')
    return
  }

  loading.value = true

  // Simulate API call delay
  await new Promise(resolve => setTimeout(resolve, 1000))

  // Mock authentication — accept any non-empty credentials
  const token = `token_${Date.now()}`
  try {
    await setItem('auth_token', token)
    await setItem('auth_user', JSON.stringify({ email: email.value.trim() }))
    vibrate('success')
    await router.reset('Home')
  } catch {
    errorMessage.value = 'Failed to save login state'
    vibrate('error')
  } finally {
    loading.value = false
  }
}

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  header: {
    alignItems: 'center',
    marginBottom: 40,
  },
  appIcon: {
    fontSize: 56,
    marginBottom: 12,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1C1C1E',
  },
  subtitle: {
    fontSize: 15,
    color: '#8E8E93',
    marginTop: 4,
  },
  form: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 20,
    gap: 16,
  },
  label: {
    fontSize: 13,
    fontWeight: '600',
    color: '#8E8E93',
    marginBottom: 4,
  },
  input: {
    fontSize: 16,
    color: '#1C1C1E',
    backgroundColor: '#F2F2F7',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 12,
    minHeight: 44,
  },
  loginButton: {
    backgroundColor: '#007AFF',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 24,
  },
  loginButtonDisabled: {
    opacity: 0.6,
  },
  loginButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
  errorContainer: {
    backgroundColor: '#FFEBEE',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  errorText: {
    color: '#D32F2F',
    fontSize: 14,
  },
  footer: {
    alignItems: 'center',
    marginTop: 24,
  },
  footerText: {
    fontSize: 13,
    color: '#8E8E93',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <!-- Header -->
    <VView :style="styles.header">
      <VText :style="styles.appIcon">🔐</VText>
      <VText :style="styles.title">Welcome Back</VText>
      <VText :style="styles.subtitle">Sign in to continue</VText>
    </VView>

    <!-- Form -->
    <VView :style="styles.form">
      <VView>
        <VText :style="styles.label">EMAIL</VText>
        <VInput
          v-model="email"
          placeholder="you@example.com"
          :style="styles.input"
          keyboard-type="email-address"
          auto-capitalize="none"
          return-key-type="next"
        />
      </VView>

      <VView>
        <VText :style="styles.label">PASSWORD</VText>
        <VInput
          v-model="password"
          placeholder="Enter your password"
          :style="styles.input"
          secure-text-entry
          return-key-type="done"
          @submit="handleLogin"
        />
      </VView>

      <!-- Error message -->
      <VView v-if="errorMessage" :style="styles.errorContainer">
        <VText :style="styles.errorText">{{ errorMessage }}</VText>
      </VView>
    </VView>

    <!-- Login button -->
    <VButton
      :style="[styles.loginButton, loading && styles.loginButtonDisabled]"
      :on-press="handleLogin"
    >
      <VText :style="styles.loginButtonText">
        {{ loading ? 'Signing in...' : 'Sign In' }}
      </VText>
    </VButton>

    <!-- Footer -->
    <VView :style="styles.footer">
      <VText :style="styles.footerText">
        Enter any email and password to sign in
      </VText>
    </VView>
  </VView>
</template>
