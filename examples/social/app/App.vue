<script setup lang="ts">
import { TabNavigator, tabs } from './main'
</script>

<template>
  <TabNavigator :screens="tabs" initial-tab="feed" />
</template>
