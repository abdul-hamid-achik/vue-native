<script setup lang="ts">
import { ThemeProvider } from './theme'
import ThemeDemo from './ThemeDemo.vue'
</script>

<template>
  <ThemeProvider initial-color-scheme="light">
    <ThemeDemo />
  </ThemeProvider>
</template>
