# Accessibility

Vue Native maps accessibility props directly to the native accessibility APIs on each platform — **UIAccessibility** on iOS and **AccessibilityNodeInfo** on Android. This means screen readers like VoiceOver and TalkBack work with your app out of the box, as long as you provide the right metadata.

## Accessibility Props

Most Vue Native components accept the following accessibility props:

| Prop                  | Type     | Description                                                        |
| --------------------- | -------- | ------------------------------------------------------------------ |
| `accessibilityLabel`  | `string` | The primary text read by VoiceOver/TalkBack. Describes what the element is. |
| `accessibilityHint`   | `string` | Additional context about what will happen when the user interacts with the element. |
| `accessibilityRole`   | `string` | Semantic role that tells the screen reader what kind of element this is. |
| `accessibilityState`  | `object` | Dynamic state flags: `{ disabled, selected, checked, expanded }`.  |

### accessibilityLabel

The most important prop. It replaces the visible text as the screen reader announcement. Use it whenever the visual content alone does not convey the element's purpose — for example, icon-only buttons.

```vue
<VButton
  :onPress="toggleFavorite"
  accessibilityLabel="Add to favorites"
>
  <VText>❤️</VText>
</VButton>
```

Without the label, a screen reader would either skip this button or announce something meaningless. With the label, VoiceOver announces "Add to favorites, button".

### accessibilityHint

Provides a secondary description of what happens when the element is activated. Screen readers typically announce it after a short pause.

```vue
<VButton
  :onPress="deleteAccount"
  accessibilityLabel="Delete account"
  accessibilityHint="Permanently removes your account and all data"
>
  <VText :style="{ color: 'red' }">Delete Account</VText>
</VButton>
```

VoiceOver announces: "Delete account, button. Permanently removes your account and all data."

### accessibilityRole

Tells the screen reader the semantic type of the element. This affects how the element is announced and how users can interact with it.

| Role          | Description                                | iOS Trait                          | Android Role                  |
| ------------- | ------------------------------------------ | ---------------------------------- | ----------------------------- |
| `"button"`    | A tappable control                         | `.button`                          | `AccessibilityNodeInfo.ACTION_CLICK` |
| `"header"`    | A section heading                          | `.header`                          | `heading = true`              |
| `"image"`     | An image                                   | `.image`                           | `className = ImageView`       |
| `"link"`      | A link that navigates somewhere            | `.link`                            | `className = Link`            |
| `"text"`      | Static text                                | `.staticText`                      | `className = TextView`        |
| `"search"`    | A search field                             | `.searchField`                     | `className = EditText`        |
| `"adjustable"`| A slider or adjustable control             | `.adjustable`                      | `rangeInfo`                   |
| `"switch"`    | A toggle switch                            | `.toggleButton`                    | `className = Switch`          |
| `"none"`      | Element is not accessible                  | `isAccessibilityElement = false`   | `importantForAccessibility = no` |

```vue
<VText
  accessibilityRole="header"
  :style="{ fontSize: 28, fontWeight: 'bold' }"
>
  Settings
</VText>
```

### accessibilityState

Communicates dynamic state to the screen reader. Pass an object with any combination of the following keys:

| Key        | Type                          | Description                              |
| ---------- | ----------------------------- | ---------------------------------------- |
| `disabled` | `boolean`                     | The element is not interactive.          |
| `selected` | `boolean`                     | The element is currently selected.       |
| `checked`  | `boolean \| 'mixed'`         | Checkbox or toggle state.                |
| `expanded` | `boolean`                     | Whether a collapsible section is open.   |

```vue
<script setup>
import { ref } from 'vue'
import { VButton, VText, VView } from '@thelacanians/vue-native-runtime'

const isExpanded = ref(false)
</script>

<template>
  <VButton
    :onPress="() => (isExpanded = !isExpanded)"
    accessibilityLabel="Notifications"
    accessibilityHint="Expand to see notification preferences"
    :accessibilityState="{ expanded: isExpanded }"
  >
    <VText>Notifications {{ isExpanded ? '▲' : '▼' }}</VText>
  </VButton>

  <VView v-if="isExpanded">
    <!-- notification settings -->
  </VView>
</template>
```

VoiceOver announces: "Notifications, collapsed, button. Double-tap to expand."

## Platform Mapping

Vue Native translates the cross-platform accessibility props into native API calls on each platform.

### iOS (UIAccessibility)

| Vue Native Prop        | UIKit Property / Method                            |
| ---------------------- | -------------------------------------------------- |
| `accessibilityLabel`   | `view.accessibilityLabel`                          |
| `accessibilityHint`    | `view.accessibilityHint`                           |
| `accessibilityRole`    | `view.accessibilityTraits` (mapped to trait flags) |
| `accessibilityState.disabled` | Adds `.notEnabled` trait                    |
| `accessibilityState.selected` | `view.isAccessibilityElement` + `.selected` trait |
| Any a11y prop present  | `view.isAccessibilityElement = true`               |

### Android (Accessibility APIs)

| Vue Native Prop        | Android Property / Method                                    |
| ---------------------- | ------------------------------------------------------------ |
| `accessibilityLabel`   | `view.contentDescription`                                    |
| `accessibilityHint`    | Appended to `contentDescription` or set via `AccessibilityDelegate` |
| `accessibilityRole`    | `AccessibilityNodeInfo.className` or role-specific properties |
| `accessibilityState.disabled` | `view.isEnabled = false` + `importantForAccessibility` |
| `accessibilityState.selected` | `view.isSelected = true`                              |
| Any a11y prop present  | `view.importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES` |

## Common Patterns

### Icon-Only Buttons

Buttons that display only an icon or emoji must have an `accessibilityLabel`:

```vue
<VButton
  :onPress="goBack"
  accessibilityLabel="Go back"
  accessibilityRole="button"
  :style="{ padding: 10 }"
>
  <VText :style="{ fontSize: 20 }">←</VText>
</VButton>

<VButton
  :onPress="openSettings"
  accessibilityLabel="Settings"
  accessibilityRole="button"
  :style="{ padding: 10 }"
>
  <VImage
    source="gear-icon"
    :style="{ width: 24, height: 24 }"
    accessibilityRole="none"
  />
</VButton>
```

Note that the `VImage` inside the button uses `accessibilityRole="none"` to avoid being announced separately — the button's label is sufficient.

### Form Inputs with Labels

Pair every input with a descriptive label:

```vue
<script setup>
import { ref } from 'vue'
import { VView, VText, VInput } from '@thelacanians/vue-native-runtime'

const email = ref('')
const password = ref('')
</script>

<template>
  <VView :style="{ padding: 20, gap: 16 }">
    <VView>
      <VText
        accessibilityRole="text"
        :style="{ fontSize: 14, color: '#666', marginBottom: 4 }"
      >
        Email address
      </VText>
      <VInput
        :value="email"
        :onChangeText="(t) => (email = t)"
        placeholder="you@example.com"
        accessibilityLabel="Email address"
        accessibilityHint="Enter your email to sign in"
        :style="{
          borderWidth: 1,
          borderColor: '#ccc',
          borderRadius: 8,
          padding: 12,
          fontSize: 16,
        }"
      />
    </VView>

    <VView>
      <VText
        accessibilityRole="text"
        :style="{ fontSize: 14, color: '#666', marginBottom: 4 }"
      >
        Password
      </VText>
      <VInput
        :value="password"
        :onChangeText="(t) => (password = t)"
        secureTextEntry
        placeholder="••••••••"
        accessibilityLabel="Password"
        accessibilityHint="Enter your password to sign in"
        :style="{
          borderWidth: 1,
          borderColor: '#ccc',
          borderRadius: 8,
          padding: 12,
          fontSize: 16,
        }"
      />
    </VView>
  </VView>
</template>
```

### Images with Descriptions

Informational images should have a label. Decorative images should be hidden from the accessibility tree:

```vue
<!-- Informational image — describe what it shows -->
<VImage
  source="https://example.com/chart.png"
  accessibilityLabel="Sales chart showing 40% growth in Q4"
  accessibilityRole="image"
  :style="{ width: 300, height: 200 }"
/>

<!-- Decorative image — hide from screen reader -->
<VImage
  source="background-pattern"
  accessibilityRole="none"
  :style="{ width: '100%', height: 150 }"
/>
```

### Toggle Controls with State

```vue
<script setup>
import { ref } from 'vue'
import { VView, VText, VSwitch } from '@thelacanians/vue-native-runtime'

const darkMode = ref(false)
const notifications = ref(true)
</script>

<template>
  <VView :style="{ padding: 20, gap: 16 }">
    <VView :style="{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }">
      <VText>Dark Mode</VText>
      <VSwitch
        :value="darkMode"
        :onValueChange="(v) => (darkMode = v)"
        accessibilityLabel="Dark Mode"
        accessibilityRole="switch"
        :accessibilityState="{ checked: darkMode }"
      />
    </VView>

    <VView :style="{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }">
      <VText>Notifications</VText>
      <VSwitch
        :value="notifications"
        :onValueChange="(v) => (notifications = v)"
        accessibilityLabel="Notifications"
        accessibilityRole="switch"
        :accessibilityState="{ checked: notifications }"
      />
    </VView>
  </VView>
</template>
```

### Disabled Buttons

```vue
<script setup>
import { ref, computed } from 'vue'
import { VButton, VText } from '@thelacanians/vue-native-runtime'

const formValid = ref(false)
</script>

<template>
  <VButton
    :onPress="submit"
    :disabled="!formValid"
    accessibilityLabel="Submit form"
    accessibilityHint="Fill in all required fields to enable"
    :accessibilityState="{ disabled: !formValid }"
    :style="{
      padding: 14,
      backgroundColor: formValid ? '#007AFF' : '#ccc',
      borderRadius: 8,
    }"
  >
    <VText :style="{ color: '#fff', textAlign: 'center' }">Submit</VText>
  </VButton>
</template>
```

### Section Headers

Mark headings so screen reader users can navigate between sections:

```vue
<VView :style="{ flex: 1 }">
  <VText
    accessibilityRole="header"
    :style="{ fontSize: 24, fontWeight: 'bold', padding: 16 }"
  >
    Account
  </VText>
  <!-- account settings... -->

  <VText
    accessibilityRole="header"
    :style="{ fontSize: 24, fontWeight: 'bold', padding: 16 }"
  >
    Privacy
  </VText>
  <!-- privacy settings... -->
</VView>
```

On iOS, VoiceOver users can swipe up/down with the rotor set to "Headings" to jump between these sections.

## RTL and Internationalization

Vue Native's `useI18n` composable provides an `isRTL` ref that you can use to flip layouts for right-to-left languages. Accessibility labels should also be localized:

```vue
<script setup>
import { useI18n } from '@thelacanians/vue-native-runtime'
import { VButton, VText } from '@thelacanians/vue-native-runtime'

const { t, isRTL } = useI18n()
</script>

<template>
  <VButton
    :onPress="goBack"
    :accessibilityLabel="t('common.goBack')"
    :style="{ flexDirection: isRTL ? 'row-reverse' : 'row' }"
  >
    <VText>{{ isRTL ? '→' : '←' }}</VText>
  </VButton>
</template>
```

## Testing Accessibility

### iOS — VoiceOver

1. Open **Settings > Accessibility > VoiceOver** on your device or simulator.
2. Enable VoiceOver.
3. Swipe right to move through elements. Listen for labels, roles, hints, and state.
4. Use the **Accessibility Inspector** in Xcode (Xcode > Open Developer Tool > Accessibility Inspector) to audit your views without enabling VoiceOver.

### Android — TalkBack

1. Open **Settings > Accessibility > TalkBack** on your device or emulator.
2. Enable TalkBack.
3. Swipe right to move through elements. Listen for content descriptions and roles.
4. Use **Layout Inspector** in Android Studio to verify `contentDescription` values.

### Automated Checks

During development, you can log accessibility metadata from your components:

```ts
app.config.errorHandler = (err, instance, info) => {
  // ...existing error handling
}

// In development, warn about missing accessibility labels on interactive elements
if (__DEV__) {
  console.warn('Remember to test with VoiceOver/TalkBack before releasing.')
}
```

## Best Practices

1. **Always label interactive elements.** Every button, input, switch, and link should have an `accessibilityLabel`. If the visible text is already descriptive, the screen reader will use it automatically — but verify with VoiceOver or TalkBack.

2. **Use roles for semantic meaning.** A `VView` acting as a button should have `accessibilityRole="button"` so the screen reader announces it correctly and tells the user they can double-tap to activate it.

3. **Keep labels concise.** "Delete" is better than "Tap this button to delete the current item from your list". Use `accessibilityHint` for the additional context.

4. **Update state dynamically.** When a checkbox toggles or a section expands, update `accessibilityState` so the screen reader reflects the current state.

5. **Hide decorative elements.** Background images, divider lines, and other non-informational views should use `accessibilityRole="none"` to avoid cluttering the screen reader experience.

6. **Test on real devices.** Simulators and emulators support screen readers, but the experience can differ from physical devices. Test on both platforms before shipping.

7. **Localize labels.** If your app supports multiple languages, accessibility labels must be translated along with the rest of your UI text.

8. **Group related elements.** If a card contains a title, subtitle, and action button, consider grouping them so the screen reader announces them as a single unit rather than three separate elements.
