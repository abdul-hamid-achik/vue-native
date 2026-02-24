import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface SocialUser {
  userId: string
  email?: string
  fullName?: string
  identityToken?: string
  authorizationCode?: string
  provider: 'apple' | 'google'
}

export interface AuthResult {
  success: boolean
  user?: SocialUser
  error?: string
}

// ─── useAppleSignIn composable ───────────────────────────────────────────

/**
 * Apple Sign In composable backed by ASAuthorizationAppleIDProvider (iOS).
 *
 * @example
 * const { signIn, signOut, user, isAuthenticated, error } = useAppleSignIn()
 *
 * async function handleLogin() {
 *   const result = await signIn()
 *   if (result.success) {
 *     console.log('Welcome', result.user.fullName)
 *   }
 * }
 */
export function useAppleSignIn() {
  const user = ref<SocialUser | null>(null)
  const isAuthenticated = ref(false)
  const error = ref<string | null>(null)

  const cleanups: Array<() => void> = []

  // Listen for credential revocation
  const unsubscribe = NativeBridge.onGlobalEvent('auth:appleCredentialRevoked', () => {
    user.value = null
    isAuthenticated.value = false
  })
  cleanups.push(unsubscribe)

  // Check existing session
  NativeBridge.invokeNativeModule('SocialAuth', 'getCurrentUser', ['apple'])
    .then((result: any) => {
      if (result && result.userId) {
        user.value = { ...result, provider: 'apple' }
        isAuthenticated.value = true
      }
    })
    .catch(() => {})

  async function signIn(): Promise<AuthResult> {
    error.value = null
    try {
      const result = await NativeBridge.invokeNativeModule('SocialAuth', 'signInWithApple')
      const socialUser: SocialUser = { ...result, provider: 'apple' }
      user.value = socialUser
      isAuthenticated.value = true
      return { success: true, user: socialUser }
    } catch (err: any) {
      const message = String(err)
      error.value = message
      return { success: false, error: message }
    }
  }

  async function signOut(): Promise<void> {
    error.value = null
    try {
      await NativeBridge.invokeNativeModule('SocialAuth', 'signOut', ['apple'])
      user.value = null
      isAuthenticated.value = false
    } catch (err: any) {
      error.value = String(err)
    }
  }

  onUnmounted(() => {
    cleanups.forEach(fn => fn())
    cleanups.length = 0
  })

  return { signIn, signOut, user, isAuthenticated, error }
}
