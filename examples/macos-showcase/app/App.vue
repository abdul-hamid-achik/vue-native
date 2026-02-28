<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  createStyleSheet,
  usePlatform,
  useWindow,
  useMenu,
  useFileDialog,
  useDragDrop,
} from '@thelacanians/vue-native-runtime'

// --- Composables ---

const { platform, isMacOS, isDesktop, isApple, isMobile } = usePlatform()
const { setTitle, setSize, center, minimize, toggleFullScreen } = useWindow()
const { setAppMenu, onMenuItemClick } = useMenu()
const { openFile, openDirectory, saveFile } = useFileDialog()
const { enableDropZone, onDrop, onDragEnter, onDragLeave, isDragging } = useDragDrop()

// --- State ---

const lastMenuAction = ref('')
const selectedFiles = ref<string[]>([])
const savedPath = ref('')
const selectedDir = ref('')
const droppedFiles = ref<string[]>([])
const windowTitle = ref('macOS Showcase')

// Native controls state
const checkboxA = ref(true)
const checkboxB = ref(false)
const radioValue = ref('option1')
const dropdownValue = ref('swift')
const segmentIndex = ref(0)
const sliderValue = ref(50)

// --- Setup ---

onMounted(() => {
  setTitle('macOS Showcase')

  setAppMenu([
    {
      title: 'File',
      items: [
        { id: 'new', title: 'New Document', key: 'n' },
        { id: 'open', title: 'Open...', key: 'o' },
        { id: 'save', title: 'Save', key: 's' },
        { separator: true, title: '' },
        { id: 'close', title: 'Close Window', key: 'w' },
      ],
    },
    {
      title: 'Edit',
      items: [
        { id: 'undo', title: 'Undo', key: 'z' },
        { id: 'redo', title: 'Redo' },
        { separator: true, title: '' },
        { id: 'cut', title: 'Cut', key: 'x' },
        { id: 'copy', title: 'Copy', key: 'c' },
        { id: 'paste', title: 'Paste', key: 'v' },
      ],
    },
    {
      title: 'View',
      items: [
        { id: 'fullscreen', title: 'Toggle Full Screen', key: 'f' },
        { id: 'minimize', title: 'Minimize', key: 'm' },
        { id: 'center', title: 'Center Window' },
      ],
    },
  ])

  onMenuItemClick((id, title) => {
    lastMenuAction.value = `${title} (${id})`
    if (id === 'fullscreen') toggleFullScreen()
    if (id === 'minimize') minimize()
    if (id === 'center') center()
  })

  enableDropZone()
  onDrop((files) => {
    droppedFiles.value = files
  })
  onDragEnter(() => {})
  onDragLeave(() => {})
})

// --- Actions ---

function handleSetTitle() {
  const newTitle = `macOS Showcase — ${Date.now()}`
  windowTitle.value = newTitle
  setTitle(newTitle)
}

function handleCenter() {
  center()
}

function handleResize() {
  setSize(1200, 800)
}

function handleMinimize() {
  minimize()
}

function handleFullScreen() {
  toggleFullScreen()
}

async function handleOpenFile() {
  const files = await openFile({ multiple: true, allowedTypes: ['txt', 'md', 'json', 'ts', 'vue'] })
  if (files) selectedFiles.value = files
}

async function handleOpenDir() {
  const dir = await openDirectory({ title: 'Select a folder' })
  if (dir) selectedDir.value = dir
}

async function handleSaveFile() {
  const path = await saveFile({ defaultName: 'export.json', title: 'Save export' })
  if (path) savedPath.value = path
}

// --- Styles ---

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F7',
  },
  header: {
    paddingHorizontal: 32,
    paddingTop: 24,
    paddingBottom: 16,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#D2D2D7',
  },
  headerTitle: {
    fontSize: 26,
    fontWeight: 'bold',
    color: '#1D1D1F',
  },
  headerSubtitle: {
    fontSize: 13,
    color: '#86868B',
    marginTop: 4,
  },
  content: {
    paddingHorizontal: 24,
    paddingBottom: 40,
  },
  section: {
    marginTop: 24,
    backgroundColor: '#FFFFFF',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#D2D2D7',
    overflow: 'hidden',
  },
  sectionHeader: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: '#FAFAFA',
    borderBottomWidth: 1,
    borderBottomColor: '#E8E8ED',
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#86868B',
    textTransform: 'uppercase' as any,
    letterSpacing: 0.5,
  },
  sectionBody: {
    padding: 16,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
  },
  infoLabel: {
    width: 120,
    fontSize: 14,
    color: '#86868B',
    fontWeight: '500',
  },
  infoValue: {
    flex: 1,
    fontSize: 14,
    color: '#1D1D1F',
    fontWeight: '500',
  },
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderRadius: 12,
    backgroundColor: '#E8F5E9',
  },
  badgeTrue: {
    backgroundColor: '#E8F5E9',
  },
  badgeFalse: {
    backgroundColor: '#F3E5F5',
  },
  badgeTextTrue: {
    fontSize: 12,
    fontWeight: '600',
    color: '#2E7D32',
  },
  badgeTextFalse: {
    fontSize: 12,
    fontWeight: '600',
    color: '#7B1FA2',
  },
  buttonRow: {
    flexDirection: 'row',
    flexWrap: 'wrap' as any,
    gap: 10,
    marginTop: 8,
  },
  actionButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    backgroundColor: '#007AFF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionButtonSecondary: {
    backgroundColor: '#F5F5F7',
    borderWidth: 1,
    borderColor: '#D2D2D7',
  },
  actionButtonText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  actionButtonTextSecondary: {
    color: '#1D1D1F',
  },
  resultText: {
    fontSize: 12,
    color: '#86868B',
    marginTop: 10,
    fontStyle: 'italic' as any,
  },
  resultValue: {
    fontSize: 12,
    color: '#1D1D1F',
    marginTop: 4,
  },
  menuActionText: {
    fontSize: 13,
    color: '#007AFF',
    marginTop: 8,
  },
  controlRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#F2F2F7',
  },
  controlRowLast: {
    borderBottomWidth: 0,
  },
  controlLabel: {
    fontSize: 14,
    color: '#1D1D1F',
    fontWeight: '500',
  },
  controlSublabel: {
    fontSize: 12,
    color: '#86868B',
    marginTop: 2,
  },
  sliderRow: {
    paddingVertical: 12,
  },
  sliderLabel: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sliderValueText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#007AFF',
  },
  dropZone: {
    minHeight: 120,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: '#D2D2D7',
    borderStyle: 'dashed' as any,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FAFAFA',
    marginTop: 8,
  },
  dropZoneActive: {
    borderColor: '#007AFF',
    backgroundColor: '#EBF5FF',
  },
  dropZoneIcon: {
    fontSize: 32,
    color: '#86868B',
  },
  dropZoneText: {
    fontSize: 14,
    color: '#86868B',
    marginTop: 8,
  },
  dropZoneActiveText: {
    color: '#007AFF',
    fontWeight: '600',
  },
  fileList: {
    marginTop: 12,
  },
  fileItem: {
    fontSize: 12,
    color: '#1D1D1F',
    paddingVertical: 2,
  },
})
</script>

<template>
  <VScrollView :style="styles.container" :shows-vertical-scroll-indicator="true">
    <!-- Header -->
    <VView :style="styles.header">
      <VText :style="styles.headerTitle">macOS Showcase</VText>
      <VText :style="styles.headerSubtitle">
        Demonstrating macOS-specific APIs and native controls
      </VText>
    </VView>

    <VView :style="styles.content">
      <!-- Platform Info -->
      <VView :style="styles.section">
        <VView :style="styles.sectionHeader">
          <VText :style="styles.sectionTitle">Platform Info</VText>
        </VView>
        <VView :style="styles.sectionBody">
          <VView :style="styles.infoRow">
            <VText :style="styles.infoLabel">Platform</VText>
            <VText :style="styles.infoValue">{{ platform }}</VText>
          </VView>
          <VView :style="styles.infoRow">
            <VText :style="styles.infoLabel">isMacOS</VText>
            <VView :style="[styles.badge, isMacOS ? styles.badgeTrue : styles.badgeFalse]">
              <VText :style="isMacOS ? styles.badgeTextTrue : styles.badgeTextFalse">
                {{ isMacOS }}
              </VText>
            </VView>
          </VView>
          <VView :style="styles.infoRow">
            <VText :style="styles.infoLabel">isDesktop</VText>
            <VView :style="[styles.badge, isDesktop ? styles.badgeTrue : styles.badgeFalse]">
              <VText :style="isDesktop ? styles.badgeTextTrue : styles.badgeTextFalse">
                {{ isDesktop }}
              </VText>
            </VView>
          </VView>
          <VView :style="styles.infoRow">
            <VText :style="styles.infoLabel">isApple</VText>
            <VView :style="[styles.badge, isApple ? styles.badgeTrue : styles.badgeFalse]">
              <VText :style="isApple ? styles.badgeTextTrue : styles.badgeTextFalse">
                {{ isApple }}
              </VText>
            </VView>
          </VView>
          <VView :style="styles.infoRow">
            <VText :style="styles.infoLabel">isMobile</VText>
            <VView :style="[styles.badge, isMobile ? styles.badgeTrue : styles.badgeFalse]">
              <VText :style="isMobile ? styles.badgeTextTrue : styles.badgeTextFalse">
                {{ isMobile }}
              </VText>
            </VView>
          </VView>
        </VView>
      </VView>

      <!-- Window Controls -->
      <VView :style="styles.section">
        <VView :style="styles.sectionHeader">
          <VText :style="styles.sectionTitle">Window Controls</VText>
        </VView>
        <VView :style="styles.sectionBody">
          <VView :style="styles.buttonRow">
            <VButton :style="styles.actionButton" :on-press="handleSetTitle">
              <VText :style="styles.actionButtonText">Set Title</VText>
            </VButton>
            <VButton :style="styles.actionButton" :on-press="handleCenter">
              <VText :style="styles.actionButtonText">Center</VText>
            </VButton>
            <VButton :style="styles.actionButton" :on-press="handleResize">
              <VText :style="styles.actionButtonText">Resize 1200x800</VText>
            </VButton>
            <VButton :style="[styles.actionButton, styles.actionButtonSecondary]" :on-press="handleMinimize">
              <VText :style="[styles.actionButtonText, styles.actionButtonTextSecondary]">Minimize</VText>
            </VButton>
            <VButton :style="[styles.actionButton, styles.actionButtonSecondary]" :on-press="handleFullScreen">
              <VText :style="[styles.actionButtonText, styles.actionButtonTextSecondary]">Full Screen</VText>
            </VButton>
          </VView>
          <VText v-if="windowTitle !== 'macOS Showcase'" :style="styles.resultText">
            Window title: {{ windowTitle }}
          </VText>
        </VView>
      </VView>

      <!-- Menu Bar -->
      <VView :style="styles.section">
        <VView :style="styles.sectionHeader">
          <VText :style="styles.sectionTitle">Menu Bar</VText>
        </VView>
        <VView :style="styles.sectionBody">
          <VText :style="{ fontSize: 13, color: '#86868B' }">
            Custom menu bar with File, Edit, and View menus has been set up.
            Try the keyboard shortcuts or menu items.
          </VText>
          <VText v-if="lastMenuAction" :style="styles.menuActionText">
            Last action: {{ lastMenuAction }}
          </VText>
        </VView>
      </VView>

      <!-- File Operations -->
      <VView :style="styles.section">
        <VView :style="styles.sectionHeader">
          <VText :style="styles.sectionTitle">File Operations</VText>
        </VView>
        <VView :style="styles.sectionBody">
          <VView :style="styles.buttonRow">
            <VButton :style="styles.actionButton" :on-press="handleOpenFile">
              <VText :style="styles.actionButtonText">Open File</VText>
            </VButton>
            <VButton :style="styles.actionButton" :on-press="handleOpenDir">
              <VText :style="styles.actionButtonText">Open Directory</VText>
            </VButton>
            <VButton :style="[styles.actionButton, styles.actionButtonSecondary]" :on-press="handleSaveFile">
              <VText :style="[styles.actionButtonText, styles.actionButtonTextSecondary]">Save File</VText>
            </VButton>
          </VView>

          <VView v-if="selectedFiles.length > 0">
            <VText :style="styles.resultText">Selected files:</VText>
            <VText
              v-for="file in selectedFiles"
              :key="file"
              :style="styles.resultValue"
            >
              {{ file }}
            </VText>
          </VView>
          <VView v-if="selectedDir">
            <VText :style="styles.resultText">Selected directory:</VText>
            <VText :style="styles.resultValue">{{ selectedDir }}</VText>
          </VView>
          <VView v-if="savedPath">
            <VText :style="styles.resultText">Saved to:</VText>
            <VText :style="styles.resultValue">{{ savedPath }}</VText>
          </VView>
        </VView>
      </VView>

      <!-- Native Controls -->
      <VView :style="styles.section">
        <VView :style="styles.sectionHeader">
          <VText :style="styles.sectionTitle">Native Controls</VText>
        </VView>
        <VView :style="styles.sectionBody">
          <!-- Checkboxes -->
          <VView :style="styles.controlRow">
            <VView>
              <VText :style="styles.controlLabel">Enable notifications</VText>
              <VText :style="styles.controlSublabel">Receive desktop alerts</VText>
            </VView>
            <VCheckbox v-model="checkboxA" />
          </VView>
          <VView :style="styles.controlRow">
            <VView>
              <VText :style="styles.controlLabel">Dark mode sidebar</VText>
              <VText :style="styles.controlSublabel">Use dark appearance for sidebar</VText>
            </VView>
            <VCheckbox v-model="checkboxB" />
          </VView>

          <!-- Radio -->
          <VView :style="styles.controlRow">
            <VText :style="styles.controlLabel">Layout</VText>
            <VRadio
              v-model="radioValue"
              :options="[
                { label: 'List', value: 'option1' },
                { label: 'Grid', value: 'option2' },
                { label: 'Column', value: 'option3' },
              ]"
            />
          </VView>

          <!-- Dropdown -->
          <VView :style="styles.controlRow">
            <VText :style="styles.controlLabel">Language</VText>
            <VDropdown
              v-model="dropdownValue"
              :options="[
                { label: 'Swift', value: 'swift' },
                { label: 'Kotlin', value: 'kotlin' },
                { label: 'TypeScript', value: 'typescript' },
                { label: 'Rust', value: 'rust' },
              ]"
            />
          </VView>

          <!-- Segmented Control -->
          <VView :style="styles.controlRow">
            <VText :style="styles.controlLabel">View Mode</VText>
            <VSegmentedControl
              v-model="segmentIndex"
              :segments="['Day', 'Week', 'Month']"
            />
          </VView>

          <!-- Slider -->
          <VView :style="[styles.sliderRow, styles.controlRowLast]">
            <VView :style="styles.sliderLabel">
              <VText :style="styles.controlLabel">Opacity</VText>
              <VText :style="styles.sliderValueText">{{ sliderValue }}%</VText>
            </VView>
            <VSlider
              v-model="sliderValue"
              :minimum-value="0"
              :maximum-value="100"
              :step="1"
              minimum-track-tint-color="#007AFF"
            />
          </VView>
        </VView>
      </VView>

      <!-- Drag & Drop -->
      <VView :style="styles.section">
        <VView :style="styles.sectionHeader">
          <VText :style="styles.sectionTitle">Drag & Drop</VText>
        </VView>
        <VView :style="styles.sectionBody">
          <VText :style="{ fontSize: 13, color: '#86868B' }">
            Drop files anywhere in the zone below.
          </VText>
          <VView :style="[styles.dropZone, isDragging && styles.dropZoneActive]">
            <VText :style="styles.dropZoneIcon">
              {{ isDragging ? '&darr;' : '&#128193;' }}
            </VText>
            <VText :style="[styles.dropZoneText, isDragging && styles.dropZoneActiveText]">
              {{ isDragging ? 'Release to drop' : 'Drag files here' }}
            </VText>
          </VView>
          <VView v-if="droppedFiles.length > 0" :style="styles.fileList">
            <VText :style="styles.resultText">Dropped files:</VText>
            <VText
              v-for="file in droppedFiles"
              :key="file"
              :style="styles.fileItem"
            >
              {{ file }}
            </VText>
          </VView>
        </VView>
      </VView>
    </VView>
  </VScrollView>
</template>
