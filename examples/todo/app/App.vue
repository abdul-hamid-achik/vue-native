<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { createStyleSheet, useAsyncStorage } from '@thelacanians/vue-native-runtime'

type Filter = 'all' | 'active' | 'done'

interface Todo {
  id: number
  text: string
  done: boolean
}

let nextId = 1

const { getItem, setItem } = useAsyncStorage()

const todos = ref<Todo[]>([])
const newTodo = ref('')
const filter = ref<Filter>('all')

onMounted(async () => {
  try {
    const stored = await getItem('todos_v1')
    if (stored) {
      const parsed = JSON.parse(stored) as Todo[]
      todos.value = parsed
      nextId = parsed.reduce((max, t) => Math.max(max, t.id), 0) + 1
    } else {
      todos.value = [
        { id: nextId++, text: 'Build Vue Native', done: false },
        { id: nextId++, text: 'Write examples', done: false },
        { id: nextId++, text: 'Ship to App Store', done: false },
      ]
    }
  } catch {
    todos.value = [
      { id: nextId++, text: 'Build Vue Native', done: false },
      { id: nextId++, text: 'Write examples', done: false },
      { id: nextId++, text: 'Ship to App Store', done: false },
    ]
  }
})

async function saveTodos() {
  try {
    await setItem('todos_v1', JSON.stringify(todos.value))
  } catch { /* storage unavailable */ }
}

watch(todos, saveTodos, { deep: true })

const filtered = computed(() => {
  switch (filter.value) {
    case 'active': return todos.value.filter(t => !t.done)
    case 'done': return todos.value.filter(t => t.done)
    default: return todos.value
  }
})

const remaining = computed(() => todos.value.filter(t => !t.done).length)

function addTodo() {
  const text = newTodo.value.trim()
  if (!text) return
  todos.value.push({ id: nextId++, text, done: false })
  newTodo.value = ''
}

function toggleTodo(id: number) {
  const todo = todos.value.find(t => t.id === id)
  if (todo) todo.done = !todo.done
}

function deleteTodo(id: number) {
  todos.value = todos.value.filter(t => t.id !== id)
}

function setFilter(f: Filter) {
  filter.value = f
}

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  header: {
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1C1C1E',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: '#8E8E93',
  },
  inputRow: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#FFFFFF',
    marginTop: 8,
    gap: 8,
  },
  input: {
    flex: 1,
    height: 40,
    paddingHorizontal: 12,
    backgroundColor: '#F2F2F7',
    borderRadius: 10,
    fontSize: 16,
    color: '#1C1C1E',
  },
  addButton: {
    width: 40,
    height: 40,
    borderRadius: 10,
    backgroundColor: '#007AFF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  addButtonText: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: 'bold',
  },
  filterRow: {
    flexDirection: 'row',
    marginHorizontal: 16,
    marginTop: 12,
    gap: 8,
  },
  filterButton: {
    flex: 1,
    paddingVertical: 7,
    borderRadius: 8,
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
  },
  filterButtonActive: {
    backgroundColor: '#007AFF',
  },
  filterText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#007AFF',
  },
  filterTextActive: {
    color: '#FFFFFF',
  },
  list: {
    marginTop: 12,
    marginHorizontal: 16,
    gap: 1,
    borderRadius: 12,
    overflow: 'hidden',
  },
  todoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 12,
  },
  checkCircle: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    borderColor: '#C7C7CC',
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkCircleDone: {
    backgroundColor: '#34C759',
    borderColor: '#34C759',
  },
  checkmark: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: 'bold',
  },
  todoText: {
    flex: 1,
    fontSize: 16,
    color: '#1C1C1E',
  },
  todoTextDone: {
    color: '#8E8E93',
  },
  deleteButton: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#FF3B30',
    alignItems: 'center',
    justifyContent: 'center',
  },
  deleteButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: 'bold',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyText: {
    fontSize: 16,
    color: '#8E8E93',
  },
})
</script>

<template>
  <VScrollView :style="styles.container" :shows-vertical-scroll-indicator="false">
    <!-- Header -->
    <VView :style="styles.header">
      <VText :style="styles.title">My Todos</VText>
      <VText :style="styles.subtitle">{{ remaining }} remaining</VText>
    </VView>

    <!-- Input row -->
    <VView :style="styles.inputRow">
      <VInput
        v-model="newTodo"
        placeholder="What needs to be done?"
        :style="styles.input"
        return-key-type="done"
        @submit="addTodo"
      />
      <VButton :style="styles.addButton" :on-press="addTodo">
        <VText :style="styles.addButtonText">+</VText>
      </VButton>
    </VView>

    <!-- Filter tabs -->
    <VView :style="styles.filterRow">
      <VButton
        v-for="f in (['all', 'active', 'done'] as const)"
        :key="f"
        :style="[styles.filterButton, filter === f && styles.filterButtonActive]"
        :on-press="() => setFilter(f)"
      >
        <VText :style="[styles.filterText, filter === f && styles.filterTextActive]">
          {{ f.charAt(0).toUpperCase() + f.slice(1) }}
        </VText>
      </VButton>
    </VView>

    <!-- Todo list -->
    <VView :style="styles.list">
      <VView v-if="filtered.length === 0" :style="styles.emptyState">
        <VText :style="styles.emptyText">Nothing here yet ✓</VText>
      </VView>

      <VView
        v-for="todo in filtered"
        :key="todo.id"
        :style="styles.todoRow"
      >
        <!-- Check circle -->
        <VButton
          :style="[styles.checkCircle, todo.done && styles.checkCircleDone]"
          :on-press="() => toggleTodo(todo.id)"
        >
          <VText v-if="todo.done" :style="styles.checkmark">✓</VText>
        </VButton>

        <!-- Todo text -->
        <VText :style="[styles.todoText, todo.done && styles.todoTextDone]">
          {{ todo.text }}
        </VText>

        <!-- Delete -->
        <VButton :style="styles.deleteButton" :on-press="() => deleteTodo(todo.id)">
          <VText :style="styles.deleteButtonText">×</VText>
        </VButton>
      </VView>
    </VView>
  </VScrollView>
</template>
