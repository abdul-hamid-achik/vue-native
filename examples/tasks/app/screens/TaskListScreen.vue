<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { createStyleSheet, useAsyncStorage, useColorScheme } from '@thelacanians/vue-native-runtime'
import { useRouter } from '@thelacanians/vue-native-navigation'

interface Task {
  id: number
  title: string
  notes: string
  priority: 'low' | 'medium' | 'high'
  done: boolean
  createdAt: number
}

let nextId = 1

const router = useRouter()
const { getItem, setItem } = useAsyncStorage()
const { isDark } = useColorScheme()

// --- State ---

const tasks = ref<Task[]>([])
const filterIndex = ref(0)
const filterValues = ['All', 'Active', 'Done']

// Delete dialog
const showDeleteDialog = ref(false)
const taskToDeleteId = ref<number | null>(null)

// Flash animation node IDs (for completed task animation)
// We track which task was just completed to flash it
const justCompletedId = ref<number | null>(null)

// --- Load from storage ---

onMounted(async () => {
  try {
    const stored = await getItem('tasks_v1')
    if (stored) {
      const parsed = JSON.parse(stored) as Task[]
      tasks.value = parsed
      nextId = parsed.reduce((max, t) => Math.max(max, t.id), 0) + 1
    } else {
      // Seed with sample data
      tasks.value = [
        { id: nextId++, title: 'Set up Vue Native project', notes: 'Install dependencies and configure Xcode', priority: 'high', done: true, createdAt: Date.now() - 86400000 * 3 },
        { id: nextId++, title: 'Build the bridge layer', notes: 'Implement JS↔Swift operation batching', priority: 'high', done: true, createdAt: Date.now() - 86400000 * 2 },
        { id: nextId++, title: 'Write component factories', notes: 'VView, VText, VButton, VInput, VImage...', priority: 'high', done: true, createdAt: Date.now() - 86400000 },
        { id: nextId++, title: 'Add Yoga layout engine', notes: 'FlexLayout SPM package integration', priority: 'medium', done: true, createdAt: Date.now() - 3600000 * 5 },
        { id: nextId++, title: 'Implement hot reload', notes: 'WebSocket dev server + HotReloadManager', priority: 'medium', done: false, createdAt: Date.now() - 3600000 * 2 },
        { id: nextId++, title: 'Write example apps', notes: 'Counter, Todo, Calculator, Settings', priority: 'medium', done: false, createdAt: Date.now() - 3600000 },
        { id: nextId++, title: 'Ship to App Store', notes: 'Prepare production build', priority: 'low', done: false, createdAt: Date.now() },
      ]
      await saveTasks()
    }
  } catch {
    // Storage unavailable in simulator — use seed data
  }
})

async function saveTasks() {
  try {
    await setItem('tasks_v1', JSON.stringify(tasks.value))
  } catch { /* storage unavailable */ }
}

watch(tasks, saveTasks, { deep: true })

// --- Computed ---

const filteredTasks = computed(() => {
  switch (filterIndex.value) {
    case 1: return tasks.value.filter(t => !t.done)
    case 2: return tasks.value.filter(t => t.done)
    default: return tasks.value
  }
})

const completedCount = computed(() => tasks.value.filter(t => t.done).length)
const totalCount = computed(() => tasks.value.length)
const progress = computed(() => totalCount.value > 0 ? completedCount.value / totalCount.value : 0)

// --- Actions ---

function toggleDone(task: Task) {
  task.done = !task.done
  if (task.done) {
    justCompletedId.value = task.id
    setTimeout(() => {
      justCompletedId.value = null
    }, 800)
  }
}

function confirmDelete(taskId: number) {
  taskToDeleteId.value = taskId
  showDeleteDialog.value = true
}

function onDeleteConfirm() {
  if (taskToDeleteId.value !== null) {
    tasks.value = tasks.value.filter(t => t.id !== taskToDeleteId.value)
  }
  taskToDeleteId.value = null
  showDeleteDialog.value = false
}

function onDeleteCancel() {
  taskToDeleteId.value = null
  showDeleteDialog.value = false
}

function openDetail(task: Task) {
  router.push('TaskDetail', { taskId: task.id })
}

const newTaskTitle = ref('')

function addTask() {
  const title = newTaskTitle.value.trim()
  if (!title) return
  tasks.value.push({
    id: nextId++,
    title,
    notes: '',
    priority: 'medium',
    done: false,
    createdAt: Date.now(),
  })
  newTaskTitle.value = ''
}

// --- Priority colors ---

function priorityColor(priority: Task['priority']): string {
  switch (priority) {
    case 'high': return '#FF3B30'
    case 'medium': return '#FF9500'
    case 'low': return '#34C759'
  }
}

// --- Styles (dark mode aware) ---

const styles = computed(() => createStyleSheet({
  container: { flex: 1, backgroundColor: isDark.value ? '#000000' : '#F2F2F7' },
  header: {
    backgroundColor: isDark.value ? '#1C1C1E' : '#FFFFFF',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: isDark.value ? '#38383A' : '#E5E5EA',
    gap: 12,
  },
  headerTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  title: { fontSize: 28, fontWeight: 'bold', color: isDark.value ? '#FFFFFF' : '#1C1C1E' },
  subtitle: { fontSize: 13, color: '#8E8E93' },
  progressSection: { gap: 4 },
  progressLabel: { fontSize: 12, color: '#8E8E93' },
  inputRow: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: isDark.value ? '#1C1C1E' : '#FFFFFF',
    marginTop: 8,
    gap: 8,
  },
  input: {
    flex: 1,
    height: 40,
    paddingHorizontal: 12,
    backgroundColor: isDark.value ? '#2C2C2E' : '#F2F2F7',
    borderRadius: 10,
    fontSize: 16,
    color: isDark.value ? '#FFFFFF' : '#1C1C1E',
  },
  addButton: {
    width: 40, height: 40, borderRadius: 10,
    backgroundColor: '#007AFF',
    alignItems: 'center', justifyContent: 'center',
  },
  addButtonText: { color: '#FFFFFF', fontSize: 22, fontWeight: 'bold' },
  filterContainer: { paddingHorizontal: 16, paddingVertical: 10 },
  taskList: { paddingBottom: 40 },
  taskCard: {
    backgroundColor: isDark.value ? '#1C1C1E' : '#FFFFFF',
    marginHorizontal: 16,
    marginTop: 8,
    borderRadius: 12,
    overflow: 'hidden',
  },
  taskCardCompleted: { opacity: 0.6 },
  taskCardFlash: { backgroundColor: '#E8F5E9' },
  taskRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 14,
    gap: 12,
  },
  checkButton: {
    width: 24, height: 24, borderRadius: 12,
    borderWidth: 2, borderColor: '#C7C7CC',
    alignItems: 'center', justifyContent: 'center',
  },
  checkButtonDone: { backgroundColor: '#34C759', borderColor: '#34C759' },
  checkmark: { color: '#FFFFFF', fontSize: 12, fontWeight: 'bold' },
  taskContent: { flex: 1 },
  taskTitle: { fontSize: 16, color: isDark.value ? '#FFFFFF' : '#1C1C1E', fontWeight: '500' },
  taskTitleDone: { color: '#8E8E93' },
  taskNotes: { fontSize: 12, color: '#8E8E93', marginTop: 2 },
  priorityDot: {
    width: 8, height: 8, borderRadius: 4, marginRight: 4,
  },
  taskMeta: { flexDirection: 'row', alignItems: 'center', marginTop: 4 },
  priorityLabel: { fontSize: 11, color: '#8E8E93' },
  deleteButton: {
    width: 32, height: 32, borderRadius: 16,
    backgroundColor: '#FF3B30',
    alignItems: 'center', justifyContent: 'center',
  },
  deleteButtonText: { color: '#FFFFFF', fontSize: 16, fontWeight: 'bold' },
  emptyState: { alignItems: 'center', paddingVertical: 60 },
  emptyIcon: { fontSize: 48, marginBottom: 12 },
  emptyText: { fontSize: 16, color: '#8E8E93' },
  emptySubtext: { fontSize: 13, color: '#C7C7CC', marginTop: 4 },
}))
</script>

<template>
  <VView :style="styles.container">
    <VScrollView :style="styles.container" :shows-vertical-scroll-indicator="false">
      <!-- Header -->
      <VView :style="styles.header">
        <VView :style="styles.headerTop">
          <VView>
            <VText :style="styles.title">Tasks</VText>
            <VText :style="styles.subtitle">
              {{ completedCount }} of {{ totalCount }} completed
            </VText>
          </VView>
        </VView>

        <!-- Progress bar -->
        <VView :style="styles.progressSection">
          <VText :style="styles.progressLabel">{{ Math.round(progress * 100) }}% complete</VText>
          <VProgressBar
            :progress="progress"
            progress-tint-color="#34C759"
            track-tint-color="#E5E5EA"
          />
        </VView>
      </VView>

      <!-- New task input -->
      <VView :style="styles.inputRow">
        <VInput
          v-model="newTaskTitle"
          placeholder="Add a new task…"
          :style="styles.input"
          return-key-type="done"
          @submit="addTask"
        />
        <VButton :style="styles.addButton" :on-press="addTask">
          <VText :style="styles.addButtonText">+</VText>
        </VButton>
      </VView>

      <!-- Filter -->
      <VView :style="styles.filterContainer">
        <VSegmentedControl
          :values="filterValues"
          :selected-index="filterIndex"
          tint-color="#007AFF"
          @change="(e: any) => filterIndex = e.selectedIndex"
        />
      </VView>

      <!-- Task list -->
      <VView :style="styles.taskList">
        <VView v-if="filteredTasks.length === 0" :style="styles.emptyState">
          <VText :style="styles.emptyIcon">
            {{ filterIndex === 2 ? '🎉' : '📋' }}
          </VText>
          <VText :style="styles.emptyText">
            {{ filterIndex === 1 ? 'All tasks done!' : filterIndex === 2 ? 'No completed tasks yet' : 'No tasks yet' }}
          </VText>
          <VText :style="styles.emptySubtext">
            {{ filterIndex === 0 ? 'Add your first task above' : '' }}
          </VText>
        </VView>

        <VView
          v-for="task in filteredTasks"
          :key="task.id"
          :style="[
            styles.taskCard,
            task.done && styles.taskCardCompleted,
            justCompletedId === task.id && styles.taskCardFlash,
          ]"
        >
          <VView :style="styles.taskRow">
            <!-- Checkbox -->
            <VButton
              :style="[styles.checkButton, task.done && styles.checkButtonDone]"
              :on-press="() => toggleDone(task)"
            >
              <VText v-if="task.done" :style="styles.checkmark">✓</VText>
            </VButton>

            <!-- Content -->
            <VButton :style="styles.taskContent" :on-press="() => openDetail(task)">
              <VText :style="[styles.taskTitle, task.done && styles.taskTitleDone]">
                {{ task.title }}
              </VText>
              <VText v-if="task.notes" :style="styles.taskNotes" number-of-lines="1">
                {{ task.notes }}
              </VText>
              <VView :style="styles.taskMeta">
                <VView :style="[styles.priorityDot, { backgroundColor: priorityColor(task.priority) }]" />
                <VText :style="styles.priorityLabel">{{ task.priority }} priority</VText>
              </VView>
            </VButton>

            <!-- Delete -->
            <VButton :style="styles.deleteButton" :on-press="() => confirmDelete(task.id)">
              <VText :style="styles.deleteButtonText">×</VText>
            </VButton>
          </VView>
        </VView>
      </VView>
    </VScrollView>

    <!-- Delete confirmation dialog -->
    <VAlertDialog
      :visible="showDeleteDialog"
      title="Delete Task"
      message="Are you sure you want to delete this task? This action cannot be undone."
      :buttons="[{ label: 'Cancel', style: 'cancel' }, { label: 'Delete', style: 'destructive' }]"
      @cancel="onDeleteCancel"
      @confirm="onDeleteConfirm"
    />
  </VView>
</template>
