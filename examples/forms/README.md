# Forms Example

Demonstrates form components and validation in Vue Native.

## Components Used

- **VInput** — Text input with keyboard type and auto-capitalize
- **VSwitch** — Toggle switches for boolean settings
- **VCheckbox** — Checkbox for terms agreement
- **VRadio** — Radio group for priority selection
- **VDropdown** — Dropdown picker for category
- **VSlider** — Slider for volume control
- **VKeyboardAvoiding** — Automatic keyboard avoidance
- **VScrollView** — Scrollable form content

## Composables Used

- **useHaptics** — Haptic feedback on submit/reset
- **useKeyboard** — Keyboard visibility tracking and dismiss

## Features

- Form validation with computed properties
- Email format validation
- Disabled submit button when form is invalid
- Reset functionality
- Accessibility labels on all interactive elements

## Running

```bash
bun run dev    # Watch mode
bun run build  # Production build
```
