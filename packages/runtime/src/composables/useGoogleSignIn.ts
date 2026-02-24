import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'
import type { SocialUser, AuthResult } from './useAppleSignIn'

// ─── useGoogleSignIn composable ──────────────────────────────────────────

/**
 * Google Sign In composable backed by Google Sign In SDK (iOS) and
 * Credential Manager API (Android).
 *
 * @param clientId - Your Google OAuth 2.0 client ID.
 *
 * @example
 * const { signIn, signOut, user, isAuthenticated, error } = useGoogleSignIn('your-client-id.apps.googleusercontent.com')
 *
 * async function handleLogin() {
 *   const result = await signIn()
 *   if (result.success) {
 *     console.log('Welcome', result.user.fullName)
 *   }
 * }
 */
export function useGoogleSignIn(clientId: string) {
  const user = ref<SocialUser | null>(null)
  const isAuthenticated = ref(false)
  const error = ref<string | null>(null)

  const cleanups: Array<() => void> = []

  // Check existing session
  NativeBridge.invokeNativeModule('SocialAuth', 'getCurrentUser', ['google'])
    .then((result: any) => {
      if (result && result.userId) {
        user.value = { ...result, provider: 'google' }
        isAuthenticated.value = true
      }
    })
    .catch(() => {})

  async function signIn(): Promise<AuthResult> {
    error.value = null
    try {
      const result = await NativeBridge.invokeNativeModule('SocialAuth', 'signInWithGoogle', [clientId])
      const socialUser: SocialUser = { ...result, provider: 'google' }
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
      await NativeBridge.invokeNativeModule('SocialAuth', 'signOut', ['google'])
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
