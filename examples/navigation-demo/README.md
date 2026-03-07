# Navigation Demo

Comprehensive navigation example demonstrating stack navigation, params, and guards.

## What It Demonstrates

- **Components:** VView, VText, VButton, VNavigationBar
- **Navigation:** 
  - Stack navigation
  - Route params
  - Navigation guards
  - Programmatic navigation
- **Composables:** `useRouter`, `useRoute`, `useBackHandler`

## Key Features

- Multi-screen navigation
- Pass parameters between screens
- Navigation guards (beforeEach)
- Back button handling
- Nested navigation

## Screenshots

| Home Screen | Detail Screen | Settings |
|-------------|---------------|----------|
| Run on iOS to see | Run on iOS to see | Run on iOS to see |

## How to Run

```bash
cd examples/navigation-demo
bun install
bun vue-native dev
```

Then open in Xcode or Android Studio.

## Key Concepts

### Router Setup

```typescript
import { createRouter } from '@thelacanians/vue-native-navigation'

const router = createRouter([
  { name: 'home', component: HomeView },
  { name: 'detail', component: DetailView },
  { name: 'settings', component: SettingsView },
])
```

### Navigation with Params

```typescript
const router = useRouter()

// Navigate with params
router.push('detail', { id: 42, name: 'John' })

// Go back
router.pop()

// Replace current screen
router.replace('home')
```

### Accessing Route Params

```typescript
const route = useRoute()

// Access params
const id = route.value.params.id
const name = route.value.params.name
```

### Navigation Guards

```typescript
router.beforeEach((to, from, next) => {
  console.log(`Navigating from ${from.name} to ${to.name}`)
  
  // Can prevent navigation
  if (to.name === 'admin' && !isLoggedIn) {
    next(false)
  } else {
    next()
  }
})
```

### Back Button Handling

```typescript
const { onBackPress } = useBackHandler()

onBackPress(() => {
  console.log('Back button pressed')
  // Return true to prevent default behavior
  return false
})
```

## File Structure

```
examples/navigation-demo/
├── app/
│   ├── main.ts
│   ├── App.vue
│   ├── router.ts
│   └── views/
│       ├── HomeView.vue
│       ├── DetailView.vue
│       └── SettingsView.vue
├── native/
└── package.json
```

## Learn More

- [Navigation Guide](../../docs/src/navigation/README.md)
- [useRouter](../../docs/src/navigation/params.md)
- [Navigation Guards](../../docs/src/navigation/guards.md)
- [Screen Lifecycle](../../docs/src/navigation/screen-lifecycle.md)

## Try This

Experiment with:
1. Add tab navigation
2. Implement drawer navigation
3. Add deep linking
4. Implement nested navigation
5. Add transition animations
