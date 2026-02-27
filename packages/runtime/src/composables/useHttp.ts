import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// fetch and RequestInit are not in ES2020 lib (no DOM). Declare them here so
// TypeScript is satisfied; the actual implementation is provided at runtime
// by the native fetch polyfill injected into JSC.
interface RequestInit {
  method?: string
  headers?: Record<string, string>
  body?: string
}

interface FetchHeaders {
  entries?(): Iterable<[string, string]>
  forEach?(callback: (value: string, key: string) => void): void
  [key: string]: any
}

interface FetchResponse {
  status: number
  ok: boolean
  json(): Promise<any>
  headers?: FetchHeaders
}

declare function fetch(
  input: string,
  init?: RequestInit,
): Promise<FetchResponse>

// AbortController may be available in newer JSC runtimes (iOS 15+).
// Declare it here since the ES2020 lib doesn't include it.
declare class AbortController {
  readonly signal: any
  abort(): void
}

export interface HttpRequestConfig {
  baseURL?: string
  headers?: Record<string, string>
  timeout?: number
  /**
   * Certificate pinning configuration.
   * Maps domain names to arrays of SHA-256 pin hashes.
   * Each pin must be in the format "sha256/<base64-encoded-hash>".
   *
   * @example
   * pins: {
   *   'api.example.com': ['sha256/AAAAAAA...', 'sha256/BBBBBBB...'],
   * }
   */
  pins?: Record<string, string[]>
}

export interface HttpResponse<T = any> {
  data: T
  status: number
  ok: boolean
  headers: Record<string, string>
}

/**
 * HTTP client composable with reactive loading/error state.
 * Uses the native fetch polyfill under the hood.
 *
 * @example
 * const http = useHttp({ baseURL: 'https://api.example.com' })
 * const users = await http.get<User[]>('/users')
 */
export function useHttp(config: HttpRequestConfig = {}) {
  // Configure certificate pins on the native side if provided.
  // iOS: uses __VN_configurePins (registered in JSPolyfills.registerFetch).
  // Android: uses Http module's configurePins method via the bridge.
  if (config.pins && Object.keys(config.pins).length > 0) {
    const configurePins = (globalThis as any).__VN_configurePins
    if (typeof configurePins === 'function') {
      configurePins(JSON.stringify(config.pins))
    } else {
      NativeBridge.invokeNativeModule('Http', 'configurePins', [config.pins])
    }
  }

  const loading = ref(false)
  const error = ref<string | null>(null)

  // Guard against updating reactive state after the owning component unmounts.
  let isMounted = true
  onUnmounted(() => {
    isMounted = false
  })

  /** Methods that typically carry a request body */
  const BODY_METHODS = new Set(['POST', 'PUT', 'PATCH'])

  /** Parse response headers from a fetch Response into a plain object */
  function parseResponseHeaders(response: FetchResponse): Record<string, string> {
    const result: Record<string, string> = {}
    if (!response.headers) return result
    try {
      if (typeof response.headers.forEach === 'function') {
        response.headers.forEach((value: string, key: string) => {
          result[key] = value
        })
      } else if (typeof response.headers.entries === 'function') {
        for (const [key, value] of response.headers.entries()) {
          result[key] = value
        }
      }
    } catch {
      // Gracefully fall back to empty headers
    }
    return result
  }

  async function request<T = any>(
    method: string,
    url: string,
    options: { body?: any, headers?: Record<string, string> } = {},
  ): Promise<HttpResponse<T>> {
    const fullUrl = config.baseURL ? `${config.baseURL}${url}` : url
    loading.value = true
    error.value = null

    // Set up AbortController for timeout if configured
    let controller: AbortController | undefined
    let timeoutId: ReturnType<typeof setTimeout> | undefined
    if (config.timeout && config.timeout > 0 && typeof AbortController !== 'undefined') {
      controller = new AbortController()
      timeoutId = setTimeout(() => controller!.abort(), config.timeout)
    }

    try {
      const upperMethod = method.toUpperCase()

      const mergedHeaders: Record<string, string> = {
        ...(config.headers ?? {}),
        ...(options.headers ?? {}),
      }

      // Only set Content-Type: application/json for methods that carry a body
      if (BODY_METHODS.has(upperMethod) && !mergedHeaders['Content-Type']) {
        mergedHeaders['Content-Type'] = 'application/json'
      }

      const fetchOptions: RequestInit = {
        method: upperMethod,
        headers: mergedHeaders,
      }

      if (controller) {
        (fetchOptions as any).signal = controller.signal
      }

      if (options.body !== undefined) {
        fetchOptions.body = JSON.stringify(options.body)
      }

      const response = await fetch(fullUrl, fetchOptions)
      const data: T = await response.json()
      const responseHeaders = parseResponseHeaders(response)

      if (!isMounted) {
        return { data, status: response.status, ok: response.ok, headers: responseHeaders }
      }

      return {
        data,
        status: response.status,
        ok: response.ok,
        headers: responseHeaders,
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e)
      if (isMounted) {
        error.value = msg
      }
      throw e
    } finally {
      if (timeoutId !== undefined) {
        clearTimeout(timeoutId)
      }
      if (isMounted) {
        loading.value = false
      }
    }
  }

  function buildUrl(url: string, params?: Record<string, string>): string {
    if (!params || Object.keys(params).length === 0) return url
    const qs = Object.entries(params)
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join('&')
    return url.includes('?') ? `${url}&${qs}` : `${url}?${qs}`
  }

  return {
    loading,
    error,
    get: <T = any>(url: string, options?: { params?: Record<string, string>, headers?: Record<string, string> } | Record<string, string>) => {
      // Backward compat: if second arg looks like plain headers (no params/headers keys), treat as headers
      if (options && !('params' in options) && !('headers' in options)) {
        return request<T>('GET', url, { headers: options as Record<string, string> })
      }
      const opts = options as { params?: Record<string, string>, headers?: Record<string, string> } | undefined
      return request<T>('GET', buildUrl(url, opts?.params), { headers: opts?.headers })
    },
    post: <T = any>(url: string, body?: any, headers?: Record<string, string>) =>
      request<T>('POST', url, { body, headers }),
    put: <T = any>(url: string, body?: any, headers?: Record<string, string>) =>
      request<T>('PUT', url, { body, headers }),
    patch: <T = any>(url: string, body?: any, headers?: Record<string, string>) =>
      request<T>('PATCH', url, { body, headers }),
    delete: <T = any>(url: string, options?: { params?: Record<string, string>, headers?: Record<string, string> } | Record<string, string>) => {
      if (options && !('params' in options) && !('headers' in options)) {
        return request<T>('DELETE', url, { headers: options as Record<string, string> })
      }
      const opts = options as { params?: Record<string, string>, headers?: Record<string, string> } | undefined
      return request<T>('DELETE', buildUrl(url, opts?.params), { headers: opts?.headers })
    },
  }
}
