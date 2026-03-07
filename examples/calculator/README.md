# Calculator

A fully functional calculator demonstrating layout, state management, and computed properties.

## What It Demonstrates

- **Components:** VView, VText, VButton, VScrollView
- **Composables:** `useHaptics` for button press feedback
- **Patterns:** 
  - Grid layout with flexbox
  - Reactive state with `ref` and `computed`
  - Event handling with `@press`
  - String manipulation for expression evaluation

## Key Features

- Clean calculator UI with grid layout
- Full arithmetic operations (+, -, ×, ÷)
- Clear (C) and equals (=) functions
- Haptic feedback on button press
- Responsive button styling

## Screenshots

| iOS | Android |
|-----|---------|
| Run on iOS simulator to see | Run on Android emulator to see |

## How to Run

```bash
cd examples/calculator
bun install
bun vue-native dev
```

Then open:
- **iOS:** `native/ios/Calculator.xcodeproj` in Xcode
- **Android:** `native/android` in Android Studio

## Key Concepts

### Grid Layout

Uses flexbox with `flexDirection: 'row'` for button rows:

```typescript
const styles = createStyleSheet({
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
})
```

### State Management

Uses `ref` for current expression and `computed` for result:

```typescript
const expression = ref('')

const result = computed(() => {
  try {
    return evaluate(expression.value)
  } catch {
    return 'Error'
  }
})
```

### Event Handling

Button presses handled with `@press`:

```vue
<VButton 
  title="7" 
  @press="() => append('7')" 
/>
```

## File Structure

```
examples/calculator/
├── app/
│   ├── main.ts          # Entry point
│   ├── App.vue          # Root component
│   └── Calculator.vue   # Main calculator component
├── native/              # Native iOS/Android projects
└── package.json
```

## Learn More

- [VView Component](../../docs/src/components/VView.md)
- [VButton Component](../../docs/src/components/VButton.md)
- [Reactivity Fundamentals](../../docs/src/guide/components.md)
- [Styling with createStyleSheet](../../docs/src/guide/styling.md)

## Try This

Experiment with:
1. Adding a decimal point button
2. Implementing percentage calculation
3. Adding keyboard support for desktop
4. Implementing history tape
