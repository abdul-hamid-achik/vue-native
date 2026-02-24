<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { createStyleSheet, useWebSocket } from '@thelacanians/vue-native-runtime'

interface ChatMessage {
  id: number
  text: string
  sender: 'me' | 'echo'
  timestamp: number
}

let nextId = 1
const messages = ref<ChatMessage[]>([])
const inputText = ref('')

// Connect to WebSocket echo server
const { status, lastMessage, send, open } = useWebSocket('wss://echo.websocket.org', {
  autoConnect: true,
  autoReconnect: true,
  maxReconnectAttempts: 5,
  reconnectInterval: 2000,
})

// When we receive an echo message, add it to the list
watch(lastMessage, (msg) => {
  if (msg === null) return
  messages.value = [...messages.value, {
    id: nextId++,
    text: msg,
    sender: 'echo',
    timestamp: Date.now(),
  }]
})

function handleSend() {
  const text = inputText.value.trim()
  if (!text || status.value !== 'OPEN') return

  // Add outgoing message
  messages.value = [...messages.value, {
    id: nextId++,
    text,
    sender: 'me',
    timestamp: Date.now(),
  }]

  // Send via WebSocket (echo server will send it back)
  send(text)
  inputText.value = ''
}

function handleReconnect() {
  open()
}

function formatTime(ts: number): string {
  const d = new Date(ts)
  const h = d.getHours().toString().padStart(2, '0')
  const m = d.getMinutes().toString().padStart(2, '0')
  return `${h}:${m}`
}

const statusColor = computed(() => {
  switch (status.value) {
    case 'OPEN': return '#34C759'
    case 'CONNECTING': return '#FF9500'
    default: return '#FF3B30'
  }
})

const statusLabel = computed(() => {
  switch (status.value) {
    case 'OPEN': return 'Connected'
    case 'CONNECTING': return 'Connecting...'
    case 'CLOSING': return 'Disconnecting...'
    default: return 'Disconnected'
  }
})

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  header: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 16,
    paddingTop: 56,
    paddingBottom: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  statusText: {
    fontSize: 12,
    color: 'rgba(255, 255, 255, 0.8)',
  },
  messageList: {
    flex: 1,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  messageBubble: {
    maxWidth: '75%' as any,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginVertical: 3,
  },
  myMessage: {
    alignSelf: 'flex-end',
    backgroundColor: '#007AFF',
    borderBottomRightRadius: 4,
  },
  echoMessage: {
    alignSelf: 'flex-start',
    backgroundColor: '#E5E5EA',
    borderBottomLeftRadius: 4,
  },
  myMessageText: {
    fontSize: 16,
    color: '#FFFFFF',
  },
  echoMessageText: {
    fontSize: 16,
    color: '#1C1C1E',
  },
  timestamp: {
    fontSize: 11,
    marginTop: 4,
  },
  myTimestamp: {
    color: 'rgba(255, 255, 255, 0.7)',
    textAlign: 'right',
  },
  echoTimestamp: {
    color: '#8E8E93',
  },
  echoLabel: {
    fontSize: 11,
    color: '#8E8E93',
    marginBottom: 2,
    fontWeight: '500',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 80,
  },
  emptyIcon: {
    fontSize: 48,
    marginBottom: 12,
  },
  emptyText: {
    fontSize: 16,
    color: '#8E8E93',
    textAlign: 'center',
  },
  emptySubtext: {
    fontSize: 13,
    color: '#C7C7CC',
    marginTop: 4,
    textAlign: 'center',
  },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderTopWidth: 1,
    borderTopColor: '#E5E5EA',
    paddingHorizontal: 12,
    paddingVertical: 8,
    paddingBottom: 28,
    gap: 8,
  },
  input: {
    flex: 1,
    minHeight: 40,
    backgroundColor: '#F2F2F7',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 10,
    fontSize: 16,
    color: '#1C1C1E',
  },
  sendButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#007AFF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendButtonDisabled: {
    backgroundColor: '#C7C7CC',
  },
  sendButtonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
  disconnectedBanner: {
    backgroundColor: '#FFF3E0',
    paddingHorizontal: 16,
    paddingVertical: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  disconnectedText: {
    fontSize: 13,
    color: '#E65100',
  },
  reconnectButton: {
    backgroundColor: '#FF9500',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
  },
  reconnectButtonText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <!-- Header -->
    <VView :style="styles.header">
      <VText :style="styles.headerTitle">Chat</VText>
      <VView :style="styles.statusRow">
        <VView :style="[styles.statusDot, { backgroundColor: statusColor }]" />
        <VText :style="styles.statusText">{{ statusLabel }}</VText>
      </VView>
    </VView>

    <!-- Disconnected banner -->
    <VView
      v-if="status === 'CLOSED'"
      :style="styles.disconnectedBanner"
    >
      <VText :style="styles.disconnectedText">Connection lost</VText>
      <VButton :style="styles.reconnectButton" :on-press="handleReconnect">
        <VText :style="styles.reconnectButtonText">Reconnect</VText>
      </VButton>
    </VView>

    <!-- Message list -->
    <VKeyboardAvoiding :style="{ flex: 1 }" behavior="padding">
      <VScrollView :style="styles.messageList">
        <!-- Empty state -->
        <VView v-if="messages.length === 0" :style="styles.emptyState">
          <VText :style="styles.emptyIcon">💬</VText>
          <VText :style="styles.emptyText">No messages yet</VText>
          <VText :style="styles.emptySubtext">
            Send a message and the echo server will reply
          </VText>
        </VView>

        <!-- Messages -->
        <VView
          v-for="msg in messages"
          :key="msg.id"
          :style="[
            styles.messageBubble,
            msg.sender === 'me' ? styles.myMessage : styles.echoMessage,
          ]"
        >
          <VText v-if="msg.sender === 'echo'" :style="styles.echoLabel">Echo</VText>
          <VText
            :style="msg.sender === 'me' ? styles.myMessageText : styles.echoMessageText"
          >
            {{ msg.text }}
          </VText>
          <VText
            :style="[
              styles.timestamp,
              msg.sender === 'me' ? styles.myTimestamp : styles.echoTimestamp,
            ]"
          >
            {{ formatTime(msg.timestamp) }}
          </VText>
        </VView>
      </VScrollView>

      <!-- Input bar -->
      <VView :style="styles.inputBar">
        <VInput
          v-model="inputText"
          placeholder="Type a message..."
          :style="styles.input"
          return-key-type="send"
          @submit="handleSend"
        />
        <VButton
          :style="[
            styles.sendButton,
            (!inputText.trim() || status !== 'OPEN') && styles.sendButtonDisabled,
          ]"
          :on-press="handleSend"
        >
          <VText :style="styles.sendButtonText">↑</VText>
        </VButton>
      </VView>
    </VKeyboardAvoiding>
  </VView>
</template>
