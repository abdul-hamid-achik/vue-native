# useCalendar

Calendar access composable for reading and writing device calendar events. Supports fetching events in a date range, creating new events, deleting events, and listing available calendars.

## Usage

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useCalendar } from '@thelacanians/vue-native-runtime'

const { requestAccess, getEvents, hasAccess } = useCalendar()
const events = ref([])

onMounted(async () => {
  await requestAccess()
  if (hasAccess.value) {
    const now = Date.now()
    events.value = await getEvents(now, now + 7 * 86400000)
  }
})
</script>

<template>
  <VView>
    <VText v-for="event in events" :key="event.id">
      {{ event.title }}
    </VText>
  </VView>
</template>
```

## API

```ts
useCalendar(): {
  requestAccess: () => Promise<boolean>
  getEvents: (startDate: number, endDate: number) => Promise<CalendarEvent[]>
  createEvent: (options: CreateEventOptions) => Promise<{ eventId: string }>
  deleteEvent: (eventId: string) => Promise<void>
  getCalendars: () => Promise<Calendar[]>
  hasAccess: Ref<boolean>
  error: Ref<string | null>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `requestAccess` | `() => Promise<boolean>` | Request calendar access. Returns `true` if granted. |
| `getEvents` | `(startDate, endDate) => Promise<CalendarEvent[]>` | Fetch events within a date range (millisecond timestamps). |
| `createEvent` | `(options) => Promise<{ eventId: string }>` | Create a new calendar event. Returns the new event ID. |
| `deleteEvent` | `(eventId) => Promise<void>` | Delete an event by its ID. |
| `getCalendars` | `() => Promise<Calendar[]>` | List all available calendars on the device. |
| `hasAccess` | `Ref<boolean>` | Whether calendar access has been granted. |
| `error` | `Ref<string \| null>` | Last error message, or `null`. |

### Types

```ts
interface CalendarEvent {
  id: string
  title: string
  startDate: number     // Unix timestamp in milliseconds
  endDate: number
  isAllDay: boolean
  calendarId: string
  notes?: string
  location?: string
}

interface Calendar {
  id: string
  title: string
  color: string         // Hex color string (e.g., "#FF0000")
  type: string          // "local", "calDAV", "exchange", etc.
  isImmutable?: boolean // iOS only
}

interface CreateEventOptions {
  title: string
  startDate: number     // Unix timestamp in milliseconds
  endDate: number
  notes?: string
  calendarId?: string   // Target calendar; uses default if omitted
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `EventKit` (`EKEventStore`). Add `NSCalendarsUsageDescription` to `Info.plist`. iOS 17+ uses `requestFullAccessToEvents`. |
| Android | Uses `CalendarContract` content provider. Requires `READ_CALENDAR` and `WRITE_CALENDAR` permissions. |

## Example

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useCalendar } from '@thelacanians/vue-native-runtime'

const { requestAccess, getEvents, createEvent, deleteEvent, getCalendars, hasAccess } = useCalendar()
const events = ref([])
const calendars = ref([])

onMounted(async () => {
  const granted = await requestAccess()
  if (!granted) return

  // Load this week's events
  const now = Date.now()
  const oneWeek = 7 * 24 * 60 * 60 * 1000
  events.value = await getEvents(now, now + oneWeek)

  // Load calendars
  calendars.value = await getCalendars()
})

async function addMeeting() {
  const now = Date.now()
  const result = await createEvent({
    title: 'Team Standup',
    startDate: now + 3600000,       // 1 hour from now
    endDate: now + 3600000 + 1800000, // 30 minutes duration
    notes: 'Daily sync meeting',
  })
  console.log('Created event:', result.eventId)

  // Refresh events
  events.value = await getEvents(now, now + 7 * 86400000)
}

async function removeEvent(eventId: string) {
  await deleteEvent(eventId)
  events.value = events.value.filter(e => e.id !== eventId)
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold', marginBottom: 12 }">
      Calendar
    </VText>

    <VButton :onPress="addMeeting">
      <VText>Add Meeting</VText>
    </VButton>

    <VView v-for="event in events" :key="event.id" :style="{ marginVertical: 8, padding: 12, backgroundColor: '#f0f0f0', borderRadius: 8 }">
      <VText :style="{ fontWeight: 'bold' }">{{ event.title }}</VText>
      <VText>{{ new Date(event.startDate).toLocaleString() }}</VText>
      <VButton :onPress="() => removeEvent(event.id)">
        <VText :style="{ color: 'red' }">Delete</VText>
      </VButton>
    </VView>

    <VText v-if="events.length === 0">No events this week</VText>
  </VView>
</template>
```

## Notes

- **Permissions:** Always call `requestAccess()` before reading or writing events. On iOS 17+, the framework uses `requestFullAccessToEvents()` for full read/write access.
- **Timestamps:** All dates use Unix timestamps in milliseconds (like `Date.now()`).
- **Default calendar:** When creating events without specifying `calendarId`, the device's default calendar is used.
- **Time zones:** On Android, events are created in the device's default time zone.
