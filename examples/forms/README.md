# Forms

Complete form handling example with validation, error handling, and submission.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VSwitch, VPicker, VActivityIndicator
- **Composables:** `useHttp` for submission, `useHaptics` for feedback
- **Patterns:**
  - Form validation
  - Error handling
  - Loading states
  - Success/error feedback

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
bun vue-native dev
```

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
