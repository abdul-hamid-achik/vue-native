package com.vuenative.core

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import androidx.core.content.ContextCompat

class CalendarModule : NativeModule {
    override val moduleName = "Calendar"

    private var context: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run { callback(null, "Not initialized"); return }

        when (method) {
            "requestAccess" -> {
                val granted = ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CALENDAR) ==
                    PackageManager.PERMISSION_GRANTED
                callback(mapOf("granted" to granted), null)
            }

            "getEvents" -> {
                val startMs = (args.getOrNull(0) as? Number)?.toLong() ?: run {
                    callback(null, "Missing startDate"); return
                }
                val endMs = (args.getOrNull(1) as? Number)?.toLong() ?: run {
                    callback(null, "Missing endDate"); return
                }

                if (!hasCalendarReadPermission(ctx)) {
                    callback(null, "Calendar read permission not granted"); return
                }

                try {
                    val events = mutableListOf<Map<String, Any?>>()
                    val projection = arrayOf(
                        CalendarContract.Events._ID,
                        CalendarContract.Events.TITLE,
                        CalendarContract.Events.DTSTART,
                        CalendarContract.Events.DTEND,
                        CalendarContract.Events.ALL_DAY,
                        CalendarContract.Events.CALENDAR_ID,
                        CalendarContract.Events.DESCRIPTION,
                        CalendarContract.Events.EVENT_LOCATION,
                    )
                    val selection = "${CalendarContract.Events.DTSTART} >= ? AND ${CalendarContract.Events.DTEND} <= ?"
                    val selectionArgs = arrayOf(startMs.toString(), endMs.toString())

                    ctx.contentResolver.query(
                        CalendarContract.Events.CONTENT_URI,
                        projection, selection, selectionArgs, "${CalendarContract.Events.DTSTART} ASC"
                    )?.use { cursor ->
                        while (cursor.moveToNext()) {
                            events.add(mapOf(
                                "id" to cursor.getLong(0).toString(),
                                "title" to (cursor.getString(1) ?: ""),
                                "startDate" to cursor.getLong(2),
                                "endDate" to cursor.getLong(3),
                                "isAllDay" to (cursor.getInt(4) == 1),
                                "calendarId" to cursor.getLong(5).toString(),
                                "notes" to (cursor.getString(6) ?: ""),
                                "location" to (cursor.getString(7) ?: ""),
                            ))
                        }
                    }
                    callback(events, null)
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }

            "createEvent" -> {
                val title = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing title"); return
                }
                val startMs = (args.getOrNull(1) as? Number)?.toLong() ?: run {
                    callback(null, "Missing startDate"); return
                }
                val endMs = (args.getOrNull(2) as? Number)?.toLong() ?: run {
                    callback(null, "Missing endDate"); return
                }
                val notes = args.getOrNull(3)?.toString()
                val calendarId = args.getOrNull(4)?.toString()

                if (!hasCalendarWritePermission(ctx)) {
                    callback(null, "Calendar write permission not granted"); return
                }

                try {
                    val values = ContentValues().apply {
                        put(CalendarContract.Events.TITLE, title)
                        put(CalendarContract.Events.DTSTART, startMs)
                        put(CalendarContract.Events.DTEND, endMs)
                        put(CalendarContract.Events.EVENT_TIMEZONE, java.util.TimeZone.getDefault().id)
                        if (notes != null) put(CalendarContract.Events.DESCRIPTION, notes)
                        if (calendarId != null) {
                            put(CalendarContract.Events.CALENDAR_ID, calendarId.toLong())
                        } else {
                            put(CalendarContract.Events.CALENDAR_ID, getDefaultCalendarId(ctx))
                        }
                    }
                    val uri: Uri? = ctx.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
                    val eventId = uri?.lastPathSegment ?: ""
                    callback(mapOf("eventId" to eventId), null)
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }

            "deleteEvent" -> {
                val eventId = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing eventId"); return
                }

                if (!hasCalendarWritePermission(ctx)) {
                    callback(null, "Calendar write permission not granted"); return
                }

                try {
                    val uri = CalendarContract.Events.CONTENT_URI.buildUpon().appendPath(eventId).build()
                    ctx.contentResolver.delete(uri, null, null)
                    callback(null, null)
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }

            "getCalendars" -> {
                if (!hasCalendarReadPermission(ctx)) {
                    callback(null, "Calendar read permission not granted"); return
                }

                try {
                    val calendars = mutableListOf<Map<String, Any?>>()
                    val projection = arrayOf(
                        CalendarContract.Calendars._ID,
                        CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                        CalendarContract.Calendars.CALENDAR_COLOR,
                        CalendarContract.Calendars.ACCOUNT_TYPE,
                    )
                    ctx.contentResolver.query(
                        CalendarContract.Calendars.CONTENT_URI,
                        projection, null, null, null
                    )?.use { cursor ->
                        while (cursor.moveToNext()) {
                            val color = cursor.getInt(2)
                            calendars.add(mapOf(
                                "id" to cursor.getLong(0).toString(),
                                "title" to (cursor.getString(1) ?: ""),
                                "color" to String.format("#%06X", 0xFFFFFF and color),
                                "type" to (cursor.getString(3) ?: "local"),
                            ))
                        }
                    }
                    callback(calendars, null)
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }

            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun hasCalendarReadPermission(ctx: Context): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun hasCalendarWritePermission(ctx: Context): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun getDefaultCalendarId(ctx: Context): Long {
        ctx.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(CalendarContract.Calendars._ID),
            "${CalendarContract.Calendars.IS_PRIMARY} = 1",
            null, null
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }
        // Fallback: first available calendar
        ctx.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(CalendarContract.Calendars._ID),
            null, null, null
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }
        return 1L
    }
}
