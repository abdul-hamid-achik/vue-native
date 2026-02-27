# Theming Example

Demonstrates the theme system, error boundaries, accessibility, and RTL support.

## Features

### Theme System
- **createTheme** — Define light and dark theme variants with design tokens
- **ThemeProvider** — Wraps app root to provide theme context
- **useTheme** — Consume theme in any child component
- **createDynamicStyleSheet** — Computed styles that update reactively with theme changes
- Color palette visualization with swatches

### Error Boundary
- **ErrorBoundary** component with `#fallback` slot
- Trigger/recover from errors with reset keys
- Error count tracking across recoveries

### Accessibility
- `accessibilityLabel`, `accessibilityRole`, `accessibilityState` on interactive elements
- Font size adjustment slider with live preview

### RTL Support
- **useI18n** composable — locale and RTL direction
- Toggle between LTR (English) and RTL (Arabic) layouts

## Components Used

- **ThemeProvider** — Theme context provider
- **ErrorBoundary** — Error boundary with fallback UI
- **VSwitch** — Toggle with accessibility props
- **VSlider** — Adjustable font size
- **VButton** — Interactive elements with a11y labels

## Composables Used

- **useTheme** — Theme access (from createTheme)
- **useColorScheme** — System light/dark preference
- **useI18n** — Locale and RTL direction

## Running

```bash
bun run dev    # Watch mode
bun run build  # Production build
```
