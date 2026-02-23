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
  get: <T>(url: string, headers?: Record<string, string>) => Promise<HttpResponse<T>>
  post: <T>(url: string, body?: any, headers?: Record<string, string>) => Promise<HttpResponse<T>>
  put: <T>(url: string, body?: any, headers?: Record<string, string>) => Promise<HttpResponse<T>>
  patch: <T>(url: string, body?: any, headers?: Record<string, string>) => Promise<HttpResponse<T>>
  delete: <T>(url: string, headers?: Record<string, string>) => Promise<HttpResponse<T>>
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

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `loading` | `Ref<boolean>` | `true` while a request is in progress. |
| `error` | `Ref<string \| null>` | Error message from the last failed request, or `null` if the last request succeeded. |
| `get` | `<T>(url, headers?) => Promise<HttpResponse<T>>` | Perform a GET request. |
| `post` | `<T>(url, body?, headers?) => Promise<HttpResponse<T>>` | Perform a POST request. The body is JSON-serialized automatically. |
| `put` | `<T>(url, body?, headers?) => Promise<HttpResponse<T>>` | Perform a PUT request. |
| `patch` | `<T>(url, body?, headers?) => Promise<HttpResponse<T>>` | Perform a PATCH request. |
| `delete` | `<T>(url, headers?) => Promise<HttpResponse<T>>` | Perform a DELETE request. |

**HttpResponse\<T\>:**

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T` | Parsed JSON response body. |
| `status` | `number` | HTTP status code. |
| `ok` | `boolean` | `true` if the status is in the 200-299 range. |
| `headers` | `Record<string, string>` | Response headers. |

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

const http = useHttp({
  baseURL: 'https://jsonplaceholder.typicode.com',
  headers: { 'Accept': 'application/json' }
})

const posts = ref([])

onMounted(async () => {
  try {
    const response = await http.get('/posts?_limit=10')
    posts.value = response.data
  } catch (e) {
    console.log('Request failed:', http.error.value)
  }
})

async function createPost() {
  const response = await http.post('/posts', {
    title: 'New Post',
    body: 'Created with Vue Native',
    userId: 1,
  })
  console.log('Created post:', response.data)
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText v-if="http.loading.value">Loading...</VText>
    <VText v-if="http.error.value" :style="{ color: 'red' }">
      Error: {{ http.error.value }}
    </VText>

    <VButton title="Create Post" :onPress="createPost" />

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
