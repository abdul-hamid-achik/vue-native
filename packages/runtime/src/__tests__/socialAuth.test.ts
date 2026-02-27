/**
 * Social Auth tests — verifies that useAppleSignIn and useGoogleSignIn
 * composables call the correct NativeBridge module/method and handle
 * reactive state, errors, and credential events.
 */
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { installMockBridge, withSetup } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')

let invokeModuleSpy: ReturnType<typeof vi.spyOn>
let onGlobalEventSpy: ReturnType<typeof vi.spyOn>

const globalEventHandlers: Map<string, Array<(payload: any) => void>> = new Map()

function triggerGlobalEvent(event: string, payload: any) {
  const handlers = globalEventHandlers.get(event) ?? []
  for (const handler of handlers) {
    handler(payload)
  }
}

describe('Social Auth', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    globalEventHandlers.clear()

    invokeModuleSpy = vi.spyOn(NativeBridge, 'invokeNativeModule').mockImplementation(
      () => Promise.resolve(undefined as any),
    )

    onGlobalEventSpy = vi.spyOn(NativeBridge, 'onGlobalEvent').mockImplementation(
      (event: string, handler: (payload: any) => void) => {
        if (!globalEventHandlers.has(event)) {
          globalEventHandlers.set(event, [])
        }
        globalEventHandlers.get(event)!.push(handler)
        return () => {
          const handlers = globalEventHandlers.get(event)
          if (handlers) {
            const idx = handlers.indexOf(handler)
            if (idx > -1) handlers.splice(idx, 1)
          }
        }
      },
    )
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  // ---------------------------------------------------------------------------
  // useAppleSignIn
  // ---------------------------------------------------------------------------
  describe('useAppleSignIn', () => {
    it('checks for existing session on creation', async () => {
      const { useAppleSignIn } = await import('../composables/useAppleSignIn')
      await withSetup(() => useAppleSignIn())
      expect(invokeModuleSpy).toHaveBeenCalledWith('SocialAuth', 'getCurrentUser', ['apple'])
    })

    it('subscribes to auth:appleCredentialRevoked event', async () => {
      const { useAppleSignIn } = await import('../composables/useAppleSignIn')
      await withSetup(() => useAppleSignIn())
      expect(onGlobalEventSpy).toHaveBeenCalledWith('auth:appleCredentialRevoked', expect.any(Function))
    })

    it('signIn calls SocialAuth.signInWithApple and sets user', async () => {
      const mockUser = {
        userId: 'apple-user-123',
        email: 'user@example.com',
        fullName: 'John Doe',
        identityToken: 'token-abc',
      }
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (module === 'SocialAuth' && method === 'signInWithApple') return Promise.resolve(mockUser)
        return Promise.resolve(undefined as any)
      })

      const { useAppleSignIn } = await import('../composables/useAppleSignIn')
      const { signIn, user, isAuthenticated } = await withSetup(() => useAppleSignIn())
      const result = await signIn()

      expect(invokeModuleSpy).toHaveBeenCalledWith('SocialAuth', 'signInWithApple')
      expect(result.success).toBe(true)
      expect(result.user).toEqual({ ...mockUser, provider: 'apple' })
      expect(user.value).toEqual({ ...mockUser, provider: 'apple' })
      expect(isAuthenticated.value).toBe(true)
    })

    it('signIn sets error on failure', async () => {
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (module === 'SocialAuth' && method === 'signInWithApple') {
          return Promise.reject('user cancelled')
        }
        return Promise.resolve(undefined as any)
      })

      const { useAppleSignIn } = await import('../composables/useAppleSignIn')
      const { signIn, error, isAuthenticated } = await withSetup(() => useAppleSignIn())
      const result = await signIn()

      expect(result.success).toBe(false)
      expect(result.error).toBe('user cancelled')
      expect(error.value).toBe('user cancelled')
      expect(isAuthenticated.value).toBe(false)
    })

    it('signOut calls SocialAuth.signOut and clears state', async () => {
      const mockUser = { userId: 'apple-user-123' }
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (method === 'signInWithApple') return Promise.resolve(mockUser)
        return Promise.resolve(undefined as any)
      })

      const { useAppleSignIn } = await import('../composables/useAppleSignIn')
      const { signIn, signOut, user, isAuthenticated } = await withSetup(() => useAppleSignIn())
      await signIn()
      expect(isAuthenticated.value).toBe(true)

      await signOut()
      expect(invokeModuleSpy).toHaveBeenCalledWith('SocialAuth', 'signOut', ['apple'])
      expect(user.value).toBeNull()
      expect(isAuthenticated.value).toBe(false)
    })

    it('clears state on auth:appleCredentialRevoked event', async () => {
      const mockUser = { userId: 'apple-user-123' }
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (method === 'signInWithApple') return Promise.resolve(mockUser)
        return Promise.resolve(undefined as any)
      })

      const { useAppleSignIn } = await import('../composables/useAppleSignIn')
      const { signIn, user, isAuthenticated } = await withSetup(() => useAppleSignIn())
      await signIn()
      expect(isAuthenticated.value).toBe(true)

      triggerGlobalEvent('auth:appleCredentialRevoked', {})
      expect(user.value).toBeNull()
      expect(isAuthenticated.value).toBe(false)
    })

    it('restores existing session on creation', async () => {
      const existingUser = { userId: 'apple-existing', email: 'existing@example.com' }
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (method === 'getCurrentUser') return Promise.resolve(existingUser)
        return Promise.resolve(undefined as any)
      })

      const { useAppleSignIn } = await import('../composables/useAppleSignIn')
      const { user, isAuthenticated } = await withSetup(() => useAppleSignIn())

      // Wait for async init
      await Promise.resolve()
      await Promise.resolve()
      expect(user.value).toEqual({ ...existingUser, provider: 'apple' })
      expect(isAuthenticated.value).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // useGoogleSignIn
  // ---------------------------------------------------------------------------
  describe('useGoogleSignIn', () => {
    const CLIENT_ID = 'test-client-id.apps.googleusercontent.com'

    it('checks for existing session on creation', async () => {
      const { useGoogleSignIn } = await import('../composables/useGoogleSignIn')
      await withSetup(() => useGoogleSignIn(CLIENT_ID))
      expect(invokeModuleSpy).toHaveBeenCalledWith('SocialAuth', 'getCurrentUser', ['google'])
    })

    it('signIn calls SocialAuth.signInWithGoogle with clientId', async () => {
      const mockUser = {
        userId: 'google-user-456',
        email: 'user@gmail.com',
        fullName: 'Jane Doe',
        identityToken: 'google-token',
      }
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (module === 'SocialAuth' && method === 'signInWithGoogle') return Promise.resolve(mockUser)
        return Promise.resolve(undefined as any)
      })

      const { useGoogleSignIn } = await import('../composables/useGoogleSignIn')
      const { signIn, user, isAuthenticated } = await withSetup(() => useGoogleSignIn(CLIENT_ID))
      const result = await signIn()

      expect(invokeModuleSpy).toHaveBeenCalledWith('SocialAuth', 'signInWithGoogle', [CLIENT_ID])
      expect(result.success).toBe(true)
      expect(result.user).toEqual({ ...mockUser, provider: 'google' })
      expect(user.value).toEqual({ ...mockUser, provider: 'google' })
      expect(isAuthenticated.value).toBe(true)
    })

    it('signIn sets error on failure', async () => {
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (module === 'SocialAuth' && method === 'signInWithGoogle') {
          return Promise.reject('network error')
        }
        return Promise.resolve(undefined as any)
      })

      const { useGoogleSignIn } = await import('../composables/useGoogleSignIn')
      const { signIn, error, isAuthenticated } = await withSetup(() => useGoogleSignIn(CLIENT_ID))
      const result = await signIn()

      expect(result.success).toBe(false)
      expect(result.error).toBe('network error')
      expect(error.value).toBe('network error')
      expect(isAuthenticated.value).toBe(false)
    })

    it('signOut calls SocialAuth.signOut with google provider', async () => {
      const mockUser = { userId: 'google-user-456' }
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (method === 'signInWithGoogle') return Promise.resolve(mockUser)
        return Promise.resolve(undefined as any)
      })

      const { useGoogleSignIn } = await import('../composables/useGoogleSignIn')
      const { signIn, signOut, user, isAuthenticated } = await withSetup(() => useGoogleSignIn(CLIENT_ID))
      await signIn()
      expect(isAuthenticated.value).toBe(true)

      await signOut()
      expect(invokeModuleSpy).toHaveBeenCalledWith('SocialAuth', 'signOut', ['google'])
      expect(user.value).toBeNull()
      expect(isAuthenticated.value).toBe(false)
    })

    it('restores existing Google session on creation', async () => {
      const existingUser = { userId: 'google-existing', email: 'existing@gmail.com' }
      invokeModuleSpy.mockImplementation((module: string, method: string) => {
        if (method === 'getCurrentUser') return Promise.resolve(existingUser)
        return Promise.resolve(undefined as any)
      })

      const { useGoogleSignIn } = await import('../composables/useGoogleSignIn')
      const { user, isAuthenticated } = await withSetup(() => useGoogleSignIn(CLIENT_ID))

      await Promise.resolve()
      await Promise.resolve()
      expect(user.value).toEqual({ ...existingUser, provider: 'google' })
      expect(isAuthenticated.value).toBe(true)
    })
  })
})
