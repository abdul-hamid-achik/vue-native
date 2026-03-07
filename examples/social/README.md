# Social

A social feed demonstrating infinite scroll, image loading, and interactions.

## What It Demonstrates

- **Components:** VList, VImage, VButton, VText, VView, VInput
- **Composables:** `useHttp`, `useHaptics`, `useShare`
- **Patterns:**
  - Infinite scrolling
  - Image lazy loading
  - Like/comment interactions
  - Share functionality

## Key Features

- Social feed
- Like posts
- Comment on posts
- Share posts
- Infinite scroll

## How to Run

```bash
cd examples/social
bun install
bun vue-native dev
```

## Key Concepts

### Feed Loading

```typescript
const posts = ref([])
const page = ref(1)

async function loadFeed() {
  const response = await useHttp().get(`/posts?page=${page.value}`)
  posts.value.push(...response.data)
}
```

### Interactions

```typescript
async function like(postId: string) {
  await useHttp().post(`/posts/${postId}/like`)
  haptics.selection()
}

async function share(post: Post) {
  await useShare().share({
    title: post.title,
    text: post.content,
    url: post.url,
  })
}
```

## Learn More

- [useHttp](../../docs/src/composables/useHttp.md)
- [useShare](../../docs/src/composables/useShare.md)
- [VImage Component](../../docs/src/components/VImage.md)
