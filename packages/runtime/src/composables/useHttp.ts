import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// fetch and RequestInit are not in ES2020 lib (no DOM). Declare them here so
// TypeScript is satisfied; the actual implementation is provided at runtime
// by the native fetch polyfill injected into JSC.
interface RequestInit {
  method?: string
  headers?: Record<string, string>
  body?: string
  signal?: unknown
}

interface FetchHeaders {
  entries?(): Iterable<[string, string]>
  forEach?(callback: (value: string, key: string) => void): void
  [key: string]: unknown
}

interface FetchResponse {
  status: number
  ok: boolean
  json(): Promise<unknown>
  text?(): Promise<string>
  headers?: FetchHeaders
}

interface AbortControllerLike {
  readonly signal: unknown
  abort(): void
}

interface HttpGlobals {
  AbortController?: new () => AbortControllerLike
}

declare function fetch(
  input: string,
  init?: RequestInit,
): Promise<FetchResponse>

declare global {
  var __VN_configurePins: ((pinsJson: string) => void) | undefined
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

export interface HttpResponse<T = unknown> {
  data: T
  status: number
  ok: boolean
  headers: Record<string, string>
}

interface RequestOptions {
  body?: unknown
  headers?: Record<string, string>
}

interface QueryRequestOptions {
  params?: Record<string, string>
  headers?: Record<string, string>
}

function isQueryRequestOptions(
  value: QueryRequestOptions | Record<string, string>,
): value is QueryRequestOptions {
  return 'params' in value || 'headers' in value
}

function getHeader(headers: Record<string, string>, name: string): string | undefined {
  const expected = name.toLowerCase()
  return Object.entries(headers).find(([key]) => key.toLowerCase() === expected)?.[1]
}

async function parseResponseBody<T>(
  response: FetchResponse,
  headers: Record<string, string>,
): Promise<T> {
  // RFC-compatible empty-response statuses do not have a JSON body. Returning
  // undefined keeps GET/POST typing flexible without making 204 a rejection.
  if (response.status === 204 || response.status === 205) return undefined as T

  const contentType = getHeader(headers, 'content-type')?.toLowerCase() ?? ''
  // Preserve the existing JSON-first behavior when a lightweight/native
  // response does not expose headers at all.
  const expectsJson = contentType === '' || contentType.includes('json') || contentType.includes('+json')

  if (!expectsJson && typeof response.text === 'function') {
    return await response.text() as T
  }

  return await response.json() as T
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
  let configurePinsPromise: Promise<unknown> | undefined

  // Configure certificate pins on the native side if provided.
  // iOS: uses __VN_configurePins (registered in JSPolyfills.registerFetch).
  // Android: uses Http module's configurePins method via the bridge.
  if (config.pins && Object.keys(config.pins).length > 0) {
    const configurePins = globalThis.__VN_configurePins
    if (typeof configurePins === 'function') {
      configurePins(JSON.stringify(config.pins))
      configurePinsPromise = Promise.resolve()
    } else {
      configurePinsPromise = NativeBridge.invokeNativeModule('Http', 'configurePins', [config.pins])
    }
  }

  const loading = ref(false)
  const error = ref<string | null>(null)
  let activeRequestCount = 0

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

  async function request<T = unknown>(
    method: string,
    url: string,
    options: RequestOptions = {},
  ): Promise<HttpResponse<T>> {
    const fullUrl = config.baseURL ? `${config.baseURL}${url}` : url
    activeRequestCount++
    loading.value = true
    error.value = null

    // Native JSC/J2V8 fetch implementations do not always expose
    // AbortController. Use it when present, while racing the response with a
    // timer so callers still get a reliable timeout without it.
    const AbortControllerCtor = (globalThis as typeof globalThis & HttpGlobals).AbortController
    const controller = config.timeout && config.timeout > 0 && typeof AbortControllerCtor === 'function'
      ? new AbortControllerCtor()
      : undefined
    let timeoutId: ReturnType<typeof setTimeout> | undefined

    try {
      if (configurePinsPromise) {
        await configurePinsPromise
      }

      const upperMethod = method.toUpperCase()

      const mergedHeaders: Record<string, string> = {
        ...(config.headers ?? {}),
        ...(options.headers ?? {}),
      }

      // Only set JSON content type when the caller has not supplied one. Header
      // names are case-insensitive, and a string body should remain raw rather
      // than being JSON-encoded a second time.
      const hasContentType = getHeader(mergedHeaders, 'content-type') !== undefined
      if (
        BODY_METHODS.has(upperMethod)
        && !hasContentType
        && (options.body === undefined || typeof options.body !== 'string')
      ) {
        mergedHeaders['Content-Type'] = 'application/json'
      }

      const fetchOptions: RequestInit = {
        method: upperMethod,
        headers: mergedHeaders,
      }

      if (controller) {
        fetchOptions.signal = controller.signal
      }

      if (options.body !== undefined) {
        fetchOptions.body = typeof options.body === 'string'
          ? options.body
          : JSON.stringify(options.body)
      }

      const fetchPromise = fetch(fullUrl, fetchOptions)
      const response = config.timeout && config.timeout > 0
        ? await Promise.race([
            fetchPromise,
            new Promise<FetchResponse>((_resolve, reject) => {
              timeoutId = setTimeout(() => {
                controller?.abort()
                reject(new Error(`[VueNative] ${upperMethod} ${fullUrl} timed out after ${config.timeout}ms`))
              }, config.timeout)
            }),
          ])
        : await fetchPromise
      const responseHeaders = parseResponseHeaders(response)
      const data = await parseResponseBody<T>(response, responseHeaders)

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
      activeRequestCount = Math.max(0, activeRequestCount - 1)
      if (isMounted) {
        loading.value = activeRequestCount > 0
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
    get: <T = unknown>(url: string, options?: QueryRequestOptions | Record<string, string>) => {
      const normalizedOptions = options
        ? (isQueryRequestOptions(options) ? options : { headers: options })
        : undefined
      return request<T>('GET', buildUrl(url, normalizedOptions?.params), { headers: normalizedOptions?.headers })
    },
    post: <T = unknown>(url: string, body?: unknown, headers?: Record<string, string>) =>
      request<T>('POST', url, { body, headers }),
    put: <T = unknown>(url: string, body?: unknown, headers?: Record<string, string>) =>
      request<T>('PUT', url, { body, headers }),
    patch: <T = unknown>(url: string, body?: unknown, headers?: Record<string, string>) =>
      request<T>('PATCH', url, { body, headers }),
    delete: <T = unknown>(url: string, options?: QueryRequestOptions | Record<string, string>) => {
      const normalizedOptions = options
        ? (isQueryRequestOptions(options) ? options : { headers: options })
        : undefined
      return request<T>('DELETE', buildUrl(url, normalizedOptions?.params), { headers: normalizedOptions?.headers })
    },
  }
}
