<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { createStyleSheet, useAsyncStorage, useHaptics } from '@thelacanians/vue-native-runtime'
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()
const { getItem, removeItem } = useAsyncStorage()
const { vibrate } = useHaptics()

const userEmail = ref('')

onMounted(async () => {
  try {
    const stored = await getItem('auth_user')
    if (stored) {
      const user = JSON.parse(stored)
      userEmail.value = user.email || ''
    }
  } catch {
    // Storage unavailable
  }
})

async function handleLogout() {
  try {
    await removeItem('auth_token')
    await removeItem('auth_user')
    vibrate('success')
    await router.reset('Login')
  } catch {
    // Best-effort cleanup
    await router.reset('Login')
  }
}

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  header: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingTop: 60,
    paddingBottom: 32,
  },
  welcomeLabel: {
    fontSize: 15,
    color: 'rgba(255, 255, 255, 0.8)',
  },
  welcomeTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginTop: 4,
  },
  content: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 20,
    gap: 12,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 16,
    gap: 8,
  },
  cardIcon: {
    fontSize: 32,
    marginBottom: 4,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#1C1C1E',
  },
  cardDescription: {
    fontSize: 14,
    color: '#8E8E93',
    lineHeight: 20,
  },
  statusCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#34C759',
  },
  statusText: {
    fontSize: 14,
    color: '#1C1C1E',
  },
  statusEmail: {
    fontSize: 13,
    color: '#8E8E93',
    marginTop: 2,
  },
  logoutButton: {
    backgroundColor: '#FF3B30',
    marginHorizontal: 16,
    marginBottom: 40,
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  logoutButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <!-- Header -->
    <VView :style="styles.header">
      <VText :style="styles.welcomeLabel">Welcome back,</VText>
      <VText :style="styles.welcomeTitle">
        {{ userEmail || 'User' }}
      </VText>
    </VView>

    <!-- Content -->
    <VScrollView :style="styles.content" :shows-vertical-scroll-indicator="false">
      <!-- Auth status -->
      <VView :style="styles.statusCard">
        <VView :style="styles.statusDot" />
        <VView>
          <VText :style="styles.statusText">Authenticated</VText>
          <VText :style="styles.statusEmail">{{ userEmail }}</VText>
        </VView>
      </VView>

      <!-- Info cards -->
      <VView :style="styles.card">
        <VText :style="styles.cardIcon">🛡️</VText>
        <VText :style="styles.cardTitle">Navigation Guard</VText>
        <VText :style="styles.cardDescription">
          This screen is protected by a beforeEach navigation guard. If you log out
          and try to navigate here, you'll be redirected to the Login screen.
        </VText>
      </VView>

      <VView :style="styles.card">
        <VText :style="styles.cardIcon">💾</VText>
        <VText :style="styles.cardTitle">Persistent Auth</VText>
        <VText :style="styles.cardDescription">
          Your authentication token is stored in AsyncStorage. The app will remember
          your login state across restarts until you explicitly log out.
        </VText>
      </VView>

      <VView :style="styles.card">
        <VText :style="styles.cardIcon">🔄</VText>
        <VText :style="styles.cardTitle">router.reset()</VText>
        <VText :style="styles.cardDescription">
          Login and logout use router.reset() to replace the entire navigation stack,
          preventing the user from navigating back to the wrong screen.
        </VText>
      </VView>
    </VScrollView>

    <!-- Logout -->
    <VButton :style="styles.logoutButton" :on-press="handleLogout">
      <VText :style="styles.logoutButtonText">Log Out</VText>
    </VButton>
  </VView>
</template>
