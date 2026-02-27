# useHttp

HTTP client composable with reactive loading and error state. Provides `get`, `post`, `put`, `patch`, and `delete` methods backed by the native `fetch` polyfill.

## Usage

```vue
<script setup>
import { useHttp } from '@thelacanians/vue-native-runtime'

const http = useHttp({ baseURL: 'https://api.example.com' })

async function fetchUsers() {
  const response = await http.get('/users')
  console.log(response.data)
}
</script>
```

## API

```ts
useHttp(config?: HttpRequestConfig): {
  loading: Ref<boolean>
  error: Ref<string | null>
  get: <T>(url: string, options?: { params?: Record<string, string>, headers?: Record<string, string> }) => Promise<HttpResponse<T>>
  post: <T>(url: string, body?: any, headers?: Record<string, string>) => Promise<HttpResponse<T>>
  put: <T>(url: string, body?: any, headers?: Record<string, string>) => Promise<HttpResponse<T>>
  patch: <T>(url: string, body?: any, headers?: Record<string, string>) => Promise<HttpResponse<T>>
  delete: <T>(url: string, options?: { params?: Record<string, string>, headers?: Record<string, string> }) => Promise<HttpResponse<T>>
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `config` | `HttpRequestConfig?` | Optional configuration applied to all requests. |

**HttpRequestConfig:**

| Property | Type | Description |
|----------|------|-------------|
| `baseURL` | `string?` | Base URL prepended to all request paths. |
| `headers` | `Record<string, string>?` | Default headers merged into every request. |
| `timeout` | `number?` | Request timeout in milliseconds. |
| `pins` | `Record<string, string[]>?` | Certificate pinning configuration. Maps domain names to arrays of SHA-256 pin hashes. |

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `loading` | `Ref<boolean>` | `true` while a request is in progress. |
| `error` | `Ref<string \| null>` | Error message from the last failed request, or `null` if the last request succeeded. |
| `get` | `<T>(url, options?) => Promise<HttpResponse<T>>` | Perform a GET request. Options: `params`, `headers`. |
| `post` | `<T>(url, body?, headers?) => Promise<HttpResponse<T>>` | Perform a POST request. The body is JSON-serialized automatically. |
| `put` | `<T>(url, body?, headers?) => Promise<HttpResponse<T>>` | Perform a PUT request. |
| `patch` | `<T>(url, body?, headers?) => Promise<HttpResponse<T>>` | Perform a PATCH request. |
| `delete` | `<T>(url, options?) => Promise<HttpResponse<T>>` | Perform a DELETE request. Options: `params`, `headers`. |

**HttpResponse\<T\>:**

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T` | Parsed JSON response body. |
| `status` | `number` | HTTP status code. |
| `ok` | `boolean` | `true` if the status is in the 200-299 range. |
| `headers` | `Record<string, string>` | Response headers. |

## Query Parameters

The `get` and `delete` methods accept a `params` option that is automatically serialized as a query string:

```ts
const http = useHttp({ baseURL: 'https://api.example.com' })

// These are equivalent:
await http.get('/users?page=2&limit=10')
await http.get('/users', { params: { page: '2', limit: '10' } })

// Combine with headers:
await http.get('/users', {
  params: { page: '2' },
  headers: { 'X-Custom': 'value' },
})
```

Values are automatically URL-encoded. If the URL already contains a query string, params are appended with `&`.

## Certificate Pinning

Pin specific domains to their expected certificate hashes to prevent MITM attacks:

```ts
const http = useHttp({
  baseURL: 'https://api.example.com',
  pins: {
    'api.example.com': [
      'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
    ],
  },
})
```

Each pin must be in the format `sha256/<base64-encoded-hash>`. Provide multiple pins to support certificate rotation. On iOS this uses `URLSession` with a custom delegate; on Android it uses OkHttp's `CertificatePinner`.

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses the native `fetch` polyfill backed by `URLSession`. |
| Android | Uses the native `fetch` polyfill backed by `OkHttp`. |

## Example

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useHttp } from '@thelacanians/vue-native-runtime'

const { loading, error, get, post: postRequest } = useHttp({
  baseURL: 'https://jsonplaceholder.typicode.com',
  headers: { 'Accept': 'application/json' },
})

const posts = ref([])

onMounted(async () => {
  try {
    const response = await get('/posts', {
      params: { _limit: '10' },
    })
    posts.value = response.data
  } catch (e) {
    console.log('Request failed:', error.value)
  }
})

async function createPost() {
  const response = await postRequest('/posts', {
    title: 'New Post',
    body: 'Created with Vue Native',
    userId: 1,
  })
  console.log('Created post:', response.data)
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText v-if="loading">Loading...</VText>
    <VText v-if="error" :style="{ color: 'red' }">
      Error: {{ error }}
    </VText>

    <VButton :onPress="createPost"><VText>Create Post</VText></VButton>

    <VView v-for="post in posts" :key="post.id" :style="{ marginTop: 12 }">
      <VText :style="{ fontWeight: 'bold' }">{{ post.title }}</VText>
      <VText>{{ post.body }}</VText>
    </VView>
  </VView>
</template>
```

## Notes

- The `Content-Type` header defaults to `application/json` for all requests. Override it by passing custom headers.
- Request bodies are automatically JSON-serialized via `JSON.stringify`.
- The `loading` ref is shared across all requests from the same `useHttp` instance. If you need independent loading states, create separate `useHttp` instances.
- On error, the promise is rejected and `error.value` is set to the error message. The `loading` ref is always reset to `false` in the `finally` block.
- The `headers` property in `HttpResponse` is currently an empty object. Full response header parsing is planned for a future release.
- For backward compatibility, `get` and `delete` also accept a plain `Record<string, string>` as the second argument, which is treated as headers.
