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

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error) {
    const message = (error as { message?: unknown }).message
    if (typeof message === 'string') return message
  }
  return String(error)
}

function normalizeSocialUser(value: unknown, provider: SocialUser['provider']): SocialUser | null {
  if (typeof value !== 'object' || value === null) return null
  const payload = value as Record<string, unknown>
  if (typeof payload.userId !== 'string') return null
  return {
    userId: payload.userId,
    email: typeof payload.email === 'string' ? payload.email : undefined,
    fullName: typeof payload.fullName === 'string' ? payload.fullName : undefined,
    identityToken: typeof payload.identityToken === 'string' ? payload.identityToken : undefined,
    authorizationCode: typeof payload.authorizationCode === 'string' ? payload.authorizationCode : undefined,
    provider,
  }
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
    .then((result) => {
      const currentUser = normalizeSocialUser(result, 'apple')
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
      const result = await NativeBridge.invokeNativeModule('SocialAuth', 'signInWithApple')
      const socialUser = normalizeSocialUser(result, 'apple')
      if (!socialUser) {
        throw new Error('Invalid Apple Sign In response.')
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
      await NativeBridge.invokeNativeModule('SocialAuth', 'signOut', ['apple'])
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
