# Social

A social feed demonstrating infinite scroll, image loading, and interactions.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VImage, VProgressBar, VScrollView
- **Composables:** `useColorScheme`, `useHaptics`, `useNetwork`
- **Navigation:** `createTabNavigator`
- **Patterns:**
  - Tab-based app structure, with the tab config in `app/navigation.ts` so the entry module and root component do not import each other
  - Network-state awareness via `useNetwork`
  - Dark mode via `useColorScheme`
  - Like / comment interactions with haptic feedback

The feed is local mock data — there is no HTTP layer or share sheet here.

## Key Features

- Three-tab app (Feed / Explore / Profile)
- Like and comment interactions with haptic feedback
- Network connectivity banner via `useNetwork`
- Dark mode via `useColorScheme`
- Locally generated mock feed data

## How to Run

```bash
cd examples/social
bun install
bun run dev:ios
# or: bun run dev:android
# or: bun run dev:macos
```

This directory contains Vue source only. Copy it into a generated project with
the corresponding native host before launching it.

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
