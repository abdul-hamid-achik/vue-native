# Forms and v-model

Vue Native provides comprehensive form handling with the `v-model` directive for two-way data binding.

## Basic Usage

The `v-model` directive works on native input components:

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const text = ref('')
const number = ref(0)
const enabled = ref(false)
</script>

<template>
  <VView>
    <VInput v-model="text" placeholder="Enter text" />
    <VText>{{ text }}</VText>
    
    <VInput 
      v-model.number="number" 
      keyboardType="numeric" 
      placeholder="Enter number"
    />
    
    <VSwitch v-model="enabled" />
  </VView>
</template>
```

## Supported Components

`v-model` works with these native components:

- `VInput` - Text input
- `VSwitch` - Toggle switch
- `VSlider` - Range slider
- `VCheckbox` - Checkbox
- `VRadio` - Radio button
- `VDropdown` - Dropdown picker
- `VSegmentedControl` - Segmented control
- `VPicker` - Date/time picker

## Modifiers

### `.lazy`

Sync after `change` event instead of `input`:

```vue
<VInput v-model.lazy="text" />
```

### `.number`

Automatically cast input value to number:

```vue
<VInput v-model.number="age" keyboardType="numeric" />
```

### `.trim`

Automatically trim whitespace from input:

```vue
<VInput v-model.trim="name" />
```

## Custom Components

`v-model` works on custom components too:

```vue
<script setup>
import { ref } from '@vue/runtime-core'

const value = ref('')
</script>

<template>
  <CustomInput v-model="value" />
</template>
```

Your custom component should accept `modelValue` prop and emit `update:modelValue`:

```vue
<script setup>
import { VInput } from '@thelacanians/vue-native-runtime'

defineProps(['modelValue'])
defineEmits(['update:modelValue'])
</script>

<template>
  <VInput 
    :value="modelValue" 
    @input="$emit('update:modelValue', $event.target.value)" 
  />
</template>
```

## Multiple v-models

You can have multiple v-models on a single component:

```vue
<script setup>
import { ref } from '@vue/runtime-core'

const firstName = ref('')
const lastName = ref('')
</script>

<template>
  <PersonForm 
    v-model:first-name="firstName"
    v-model:last-name="lastName"
  />
</template>
```

```vue
<script setup>
defineProps(['firstName', 'lastName'])
defineEmits(['update:firstName', 'update:lastName'])
</script>

<template>
  <VView>
    <VInput 
      :value="firstName"
      @input="$emit('update:firstName', $event.target.value)"
    />
    <VInput 
      :value="lastName"
      @input="$emit('update:lastName', $event.target.value)"
    />
  </VView>
</template>
```

## Form Validation

Combine v-model with computed properties for validation:

```vue
<script setup>
import { ref, computed } from '@thelacanians/vue-native-runtime'

const email = ref('')
const password = ref('')

const emailError = computed(() => {
  if (!email.value) return 'Email is required'
  if (!/^\S+@\S+\.\S+$/.test(email.value)) return 'Invalid email format'
  return ''
})

const isFormValid = computed(() => {
  return !emailError.value && password.value.length >= 8
})

function submit() {
  if (!isFormValid.value) return
  // Submit form
}
</script>

<template>
  <VView>
    <VInput v-model="email" placeholder="Email" />
    <VText v-if="emailError" :style="{ color: 'red' }">
      {{ emailError }}
    </VText>
    
    <VInput 
      v-model="password" 
      type="password"
      placeholder="Password (min 8 chars)"
    />
    
    <VButton 
      title="Submit" 
      @press="submit"
      :disabled="!isFormValid"
    />
  </VView>
</template>
```

## Programmatic Control

For advanced scenarios, you can control inputs programmatically:

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const text = ref('')
const inputRef = ref(null)

function focusInput() {
  // Access the native node
  const node = inputRef.value?.__nodeId
  if (node) {
    // Focus the input
    NativeBridge.updateProp(node, 'focused', true)
  }
}

function clearInput() {
  text.value = ''
}
</script>

<template>
  <VView>
    <VInput 
      ref="inputRef"
      v-model="text"
      placeholder="Enter text"
    />
    <VButton title="Focus" @press="focusInput" />
    <VButton title="Clear" @press="clearInput" />
  </VView>
</template>
```

## Handling Submit

Handle form submission with the keyboard's return key:

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const text = ref('')

function handleSubmit() {
  console.log('Submitted:', text.value)
}
</script>

<template>
  <VView>
    <VInput 
      v-model="text"
      placeholder="Enter text"
      :returnKeyType="'done'"
      @submit="handleSubmit"
    />
  </VView>
</template>
```

## Common Patterns

### Search Input

```vue
<script setup>
import { ref, watchDebounced } from '@thelacanians/vue-native-runtime'

const search = ref('')
const results = ref([])

watchDebounced(search, async (query) => {
  if (query.length > 2) {
    const response = await fetch(`/search?q=${query}`)
    results.value = await response.json()
  }
}, { debounce: 300 })
</script>

<template>
  <VView>
    <VInput 
      v-model="search"
      placeholder="Search..."
      :clearButtonMode="'while-editing'"
    />
    <VList 
      :data="results"
      :renderItem="(item) => <VText>{{ item.name }}</VText>"
    />
  </VView>
</template>
```

### Login Form

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const email = ref('')
const password = ref('')
const loading = ref(false)

async function login() {
  loading.value = true
  try {
    await $fetch('/api/login', {
      method: 'POST',
      body: { email: email.value, password: password.value }
    })
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <VView>
    <VInput v-model="email" placeholder="Email" keyboardType="email-address" />
    <VInput 
      v-model="password" 
      placeholder="Password" 
      secureTextEntry
      @submit="login"
    />
    <VButton 
      :title="loading ? 'Logging in...' : 'Login'"
      @press="login"
      :disabled="loading"
    />
  </VView>
</template>
```

## Troubleshooting

### v-model not updating

**Problem:** Input value doesn't update when the bound value changes.

**Solution:** Make sure you're using the correct prop name. Some components might use `value` while others use `modelValue`.

### Number modifier not working

**Problem:** `.number` modifier doesn't convert to number.

**Solution:** Ensure the input's `keyboardType` is set to `'numeric'` or `'number-pad'` for better compatibility.

### Custom component v-model

**Problem:** v-model doesn't work on custom component.

**Solution:** Ensure your component:
1. Accepts `modelValue` prop
2. Emits `update:modelValue` event
3. Passes the event correctly from the native input

## Related

- [VInput Component](../components/VInput.md)
- [VSwitch Component](../components/VSwitch.md)
- [VSlider Component](../components/VSlider.md)
- [Form Validation](#form-validation)
