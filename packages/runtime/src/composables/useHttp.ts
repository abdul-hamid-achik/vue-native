import { ref } from '@vue/runtime-core'

// fetch and RequestInit are not in ES2020 lib (no DOM). Declare them here so
// TypeScript is satisfied; the actual implementation is provided at runtime
// by the native fetch polyfill injected into JSC.
interface RequestInit {
  method?: string
  headers?: Record<string, string>
  body?: string
}

declare function fetch(
  input: string,
  init?: RequestInit,
): Promise<{ status: number; ok: boolean; json(): Promise<any> }>

export interface HttpRequestConfig {
  baseURL?: string
  headers?: Record<string, string>
  timeout?: number
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
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function request<T = any>(
    method: string,
    url: string,
    options: { body?: any; headers?: Record<string, string> } = {},
  ): Promise<HttpResponse<T>> {
    const fullUrl = config.baseURL ? `${config.baseURL}${url}` : url
    loading.value = true
    error.value = null

    try {
      const mergedHeaders: Record<string, string> = {
        'Content-Type': 'application/json',
        ...(config.headers ?? {}),
        ...(options.headers ?? {}),
      }

      const fetchOptions: RequestInit = {
        method: method.toUpperCase(),
        headers: mergedHeaders,
      }

      if (options.body !== undefined) {
        fetchOptions.body = JSON.stringify(options.body)
      }

      const response = await fetch(fullUrl, fetchOptions)
      const data: T = await response.json()

      const result: HttpResponse<T> = {
        data,
        status: response.status,
        ok: response.ok,
        headers: {},
      }

      if (!response.ok) {
        const msg = `HTTP ${response.status}`
        error.value = msg
      }

      return result
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e)
      error.value = msg
      throw e
    } finally {
      loading.value = false
    }
  }

  return {
    loading,
    error,
    get: <T = any>(url: string, headers?: Record<string, string>) =>
      request<T>('GET', url, { headers }),
    post: <T = any>(url: string, body?: any, headers?: Record<string, string>) =>
      request<T>('POST', url, { body, headers }),
    put: <T = any>(url: string, body?: any, headers?: Record<string, string>) =>
      request<T>('PUT', url, { body, headers }),
    patch: <T = any>(url: string, body?: any, headers?: Record<string, string>) =>
      request<T>('PATCH', url, { body, headers }),
    delete: <T = any>(url: string, headers?: Record<string, string>) =>
      request<T>('DELETE', url, { headers }),
  }
}
