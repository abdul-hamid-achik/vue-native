<script setup lang="ts">
import { TabNavigator, tabs } from './navigation'
</script>

<template>
  <TabNavigator :screens="tabs" initial-tab="feed" />
</template>
