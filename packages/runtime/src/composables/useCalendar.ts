import { ref } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface CalendarEvent {
  id: string
  title: string
  startDate: number // Unix timestamp in milliseconds
  endDate: number
  isAllDay: boolean
  calendarId: string
  notes?: string
  location?: string
}

export interface Calendar {
  id: string
  title: string
  color: string
  type: string
  isImmutable?: boolean
}

export interface CreateEventOptions {
  title: string
  startDate: number
  endDate: number
  notes?: string
  calendarId?: string
}

// ─── useCalendar composable ───────────────────────────────────────────────

/**
 * Calendar access composable for reading and writing calendar events.
 *
 * @example
 * const { requestAccess, getEvents, createEvent } = useCalendar()
 *
 * await requestAccess()
 * const events = await getEvents(Date.now(), Date.now() + 86400000)
 */
export function useCalendar() {
  const hasAccess = ref(false)
  const error = ref<string | null>(null)

  async function requestAccess(): Promise<boolean> {
    try {
      const result: { granted: boolean } = await NativeBridge.invokeNativeModule('Calendar', 'requestAccess')
      hasAccess.value = result.granted
      return result.granted
    } catch (e: any) {
      error.value = e?.message || String(e)
      return false
    }
  }

  async function getEvents(startDate: number, endDate: number): Promise<CalendarEvent[]> {
    return NativeBridge.invokeNativeModule('Calendar', 'getEvents', [startDate, endDate])
  }

  async function createEvent(options: CreateEventOptions): Promise<{ eventId: string }> {
    return NativeBridge.invokeNativeModule('Calendar', 'createEvent', [
      options.title,
      options.startDate,
      options.endDate,
      options.notes,
      options.calendarId,
    ])
  }

  async function deleteEvent(eventId: string): Promise<void> {
    return NativeBridge.invokeNativeModule('Calendar', 'deleteEvent', [eventId])
  }

  async function getCalendars(): Promise<Calendar[]> {
    return NativeBridge.invokeNativeModule('Calendar', 'getCalendars')
  }

  return { requestAccess, getEvents, createEvent, deleteEvent, getCalendars, hasAccess, error }
}
