# Forms

Complete form handling example with validation, error handling, and submission.

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

- **Components:** VView, VText, VButton, VInput, VSwitch, VCheckbox, VRadio, VDropdown, VSlider, VScrollView, VKeyboardAvoiding
- **Composables:** `useHaptics`, `useKeyboard`
- **Patterns:**
  - Every input control in one screen
  - Real-time validation driven by `computed`
  - Inline error messages and a disabled submit state
  - Keyboard dismissal on submit
  - Haptic feedback on submit and reset

## Key Features

- Multiple input types
- Real-time validation
- Error messages
- Loading indicators
- Success confirmation

## How to Run

```bash
cd examples/forms
bun install
bun run dev:ios
# or: bun run dev:android
```

This directory contains Vue source only. Copy it into a generated project with
an iOS or Android native host before launching it.

## Key Concepts

### Form Validation

```typescript
const errors = ref({})

function validate() {
  errors.value = {}
  if (!email.value) errors.value.email = 'Email required'
  if (!password.value) errors.value.password = 'Password required'
  return Object.keys(errors.value).length === 0
}
```

### Loading State

```typescript
const loading = ref(false)

async function submit() {
  loading.value = true
  try {
    await api.submit(form.value)
  } finally {
    loading.value = false
  }
}
```

## Learn More

- [VInput Component](../../docs/src/components/VInput.md)
- [Form Handling Guide](../../docs/src/guide/forms.md)
- [Error Handling](../../docs/src/guide/error-handling.md)
