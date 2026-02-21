<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { createStyleSheet, useAsyncStorage, useColorScheme, useHaptics } from '@vue-native/runtime'
import { useRouter, useRoute } from '@vue-native/navigation'

interface Task {
  id: number
  title: string
  notes: string
  priority: 'low' | 'medium' | 'high'
  done: boolean
  createdAt: number
}

const router = useRouter()
const route = useRoute()
const { getItem, setItem } = useAsyncStorage()
const { isDark } = useColorScheme()
const { vibrate } = useHaptics()

const taskId = computed(() => route.value.params.taskId as number)
const task = ref<Task | null>(null)
const editTitle = ref('')
const editNotes = ref('')
const editPriority = ref<'low' | 'medium' | 'high'>('medium')
const saved = ref(false)

// Load task from storage
watch(taskId, async () => {
  try {
    const stored = await getItem('tasks_v1')
    if (stored) {
      const tasks = JSON.parse(stored) as Task[]
      const found = tasks.find(t => t.id === taskId.value)
      if (found) {
        task.value = found
        editTitle.value = found.title
        editNotes.value = found.notes
        editPriority.value = found.priority
      }
    }
  } catch (e) {}
}, { immediate: true })

async function saveTask() {
  if (!task.value) return
  try {
    const stored = await getItem('tasks_v1')
    if (stored) {
      const tasks = JSON.parse(stored) as Task[]
      const idx = tasks.findIndex(t => t.id === taskId.value)
      if (idx >= 0) {
        tasks[idx].title = editTitle.value
        tasks[idx].notes = editNotes.value
        tasks[idx].priority = editPriority.value
        await setItem('tasks_v1', JSON.stringify(tasks))
      }
    }
    vibrate('success')
    saved.value = true
    setTimeout(() => { saved.value = false }, 2000)
  } catch (e) {}
}

const priorities: Task['priority'][] = ['low', 'medium', 'high']

function priorityColor(priority: Task['priority']): string {
  switch (priority) {
    case 'high': return '#FF3B30'
    case 'medium': return '#FF9500'
    case 'low': return '#34C759'
  }
}

function formatDate(ts: number): string {
  const d = new Date(ts)
  return d.toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' })
}

const styles = computed(() => createStyleSheet({
  container: { flex: 1, backgroundColor: isDark.value ? '#000000' : '#F2F2F7' },
  navBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: isDark.value ? '#1C1C1E' : '#FFFFFF',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: isDark.value ? '#38383A' : '#E5E5EA',
    gap: 12,
  },
  backButton: {
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: 8,
  },
  backText: { fontSize: 16, color: '#007AFF' },
  navTitle: { flex: 1, fontSize: 17, fontWeight: '600', color: isDark.value ? '#FFFFFF' : '#1C1C1E', textAlign: 'center' },
  card: {
    backgroundColor: isDark.value ? '#1C1C1E' : '#FFFFFF',
    marginHorizontal: 16,
    marginTop: 16,
    borderRadius: 12,
    overflow: 'hidden',
    paddingHorizontal: 16,
    paddingVertical: 16,
    gap: 16,
  },
  label: { fontSize: 13, fontWeight: '600', color: '#8E8E93', marginBottom: 6 },
  textInput: {
    fontSize: 16,
    color: isDark.value ? '#FFFFFF' : '#1C1C1E',
    backgroundColor: isDark.value ? '#2C2C2E' : '#F2F2F7',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    minHeight: 44,
  },
  notesInput: { minHeight: 100 },
  priorityRow: { flexDirection: 'row', gap: 8 },
  priorityChip: {
    flex: 1, paddingVertical: 8, borderRadius: 8,
    alignItems: 'center', borderWidth: 2, borderColor: 'transparent',
  },
  priorityChipText: { fontSize: 13, fontWeight: '600', color: '#8E8E93' },
  saveButton: {
    backgroundColor: '#007AFF',
    marginHorizontal: 16,
    marginTop: 16,
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
  },
  saveButtonText: { color: '#FFFFFF', fontSize: 17, fontWeight: '600' },
  savedMessage: { alignItems: 'center', marginTop: 10 },
  savedText: { fontSize: 14, color: '#34C759', fontWeight: '500' },
  metaCard: {
    backgroundColor: isDark.value ? '#1C1C1E' : '#FFFFFF',
    marginHorizontal: 16,
    marginTop: 12,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  metaLabel: { fontSize: 13, color: '#8E8E93' },
  metaValue: { fontSize: 13, color: isDark.value ? '#FFFFFF' : '#1C1C1E' },
}))
</script>

<template>
  <VScrollView :style="styles.container" :showsVerticalScrollIndicator="false">
    <!-- Nav bar -->
    <VView :style="styles.navBar">
      <VButton :style="styles.backButton" :onPress="() => router.goBack()">
        <VText :style="styles.backText">‹ Back</VText>
      </VButton>
      <VText :style="styles.navTitle">Edit Task</VText>
    </VView>

    <VView v-if="task">
      <!-- Edit form -->
      <VView :style="styles.card">
        <VView>
          <VText :style="styles.label">TITLE</VText>
          <VInput
            v-model="editTitle"
            placeholder="Task title"
            :style="styles.textInput"
            returnKeyType="next"
          />
        </VView>

        <VView>
          <VText :style="styles.label">NOTES</VText>
          <VInput
            v-model="editNotes"
            placeholder="Add notes…"
            :style="[styles.textInput, styles.notesInput]"
            multiline
          />
        </VView>

        <VView>
          <VText :style="styles.label">PRIORITY</VText>
          <VView :style="styles.priorityRow">
            <VButton
              v-for="p in priorities"
              :key="p"
              :style="[
                styles.priorityChip,
                { backgroundColor: editPriority === p ? priorityColor(p) + '22' : 'transparent' },
                { borderColor: editPriority === p ? priorityColor(p) : '#E5E5EA' },
              ]"
              :onPress="() => editPriority = p"
            >
              <VText :style="[styles.priorityChipText, { color: priorityColor(p) }]">
                {{ p.charAt(0).toUpperCase() + p.slice(1) }}
              </VText>
            </VButton>
          </VView>
        </VView>
      </VView>

      <!-- Created date -->
      <VView :style="styles.metaCard">
        <VText :style="styles.metaLabel">Created</VText>
        <VText :style="styles.metaValue">{{ formatDate(task.createdAt) }}</VText>
      </VView>

      <!-- Save button -->
      <VButton :style="styles.saveButton" :onPress="saveTask">
        <VText :style="styles.saveButtonText">Save Changes</VText>
      </VButton>

      <VView v-if="saved" :style="styles.savedMessage">
        <VText :style="styles.savedText">Changes saved!</VText>
      </VView>
    </VView>
  </VScrollView>
</template>
