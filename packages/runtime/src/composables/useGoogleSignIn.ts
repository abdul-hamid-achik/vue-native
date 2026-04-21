import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'
import type { SocialUser, AuthResult } from './useAppleSignIn'

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error) {
    const message = (error as { message?: unknown }).message
    if (typeof message === 'string') return message
  }
  return String(error)
}

function normalizeSocialUser(value: unknown): SocialUser | null {
  if (typeof value !== 'object' || value === null) return null
  const payload = value as Record<string, unknown>
  if (typeof payload.userId !== 'string') return null
  return {
    userId: payload.userId,
    email: typeof payload.email === 'string' ? payload.email : undefined,
    fullName: typeof payload.fullName === 'string' ? payload.fullName : undefined,
    identityToken: typeof payload.identityToken === 'string' ? payload.identityToken : undefined,
    authorizationCode: typeof payload.authorizationCode === 'string' ? payload.authorizationCode : undefined,
    provider: 'google',
  }
}

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
    .then((result) => {
      const currentUser = normalizeSocialUser(result)
      if (currentUser) {
        user.value = currentUser
        isAuthenticated.value = true
      }
    })
    .catch((err: unknown) => {
      if (__DEV__) console.warn('[vue-native] SocialAuth.getCurrentUser failed:', err)
    })

  async function signIn(): Promise<AuthResult> {
    error.value = null
    try {
      const result = await NativeBridge.invokeNativeModule('SocialAuth', 'signInWithGoogle', [clientId])
      const socialUser = normalizeSocialUser(result)
      if (!socialUser) {
        throw new Error('Invalid Google Sign In response.')
      }
      user.value = socialUser
      isAuthenticated.value = true
      return { success: true, user: socialUser }
    } catch (err: unknown) {
      const message = getErrorMessage(err)
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
    } catch (err: unknown) {
      error.value = getErrorMessage(err)
    }
  }

  onUnmounted(() => {
    cleanups.forEach(fn => fn())
    cleanups.length = 0
  })

  return { signIn, signOut, user, isAuthenticated, error }
}
