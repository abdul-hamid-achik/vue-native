#if canImport(UIKit)
import UIKit
import EventKit

/// Native module for calendar (EventKit) access.
///
/// Methods:
///   - requestAccess() — request calendar access
///   - getEvents(startDate, endDate) — fetch events in a date range
///   - createEvent(title, startDate, endDate, notes?) — create a calendar event
///   - deleteEvent(eventId) — delete an event
///   - getCalendars() — list available calendars
final class CalendarModule: NativeModule {
    var moduleName: String { "Calendar" }

    private let eventStore = EKEventStore()

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "requestAccess":
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error = error {
                        callback(nil, error.localizedDescription)
                    } else {
                        callback(["granted": granted], nil)
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        callback(nil, error.localizedDescription)
                    } else {
                        callback(["granted": granted], nil)
                    }
                }
            }

        case "getEvents":
            guard let startMs = args[safe: 0] as? Double,
                  let endMs = args[safe: 1] as? Double else {
                callback(nil, "CalendarModule: missing startDate/endDate (milliseconds)"); return
            }
            let startDate = Date(timeIntervalSince1970: startMs / 1000)
            let endDate = Date(timeIntervalSince1970: endMs / 1000)
            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            let events = eventStore.events(matching: predicate)
            let result = events.map { eventToDict($0) }
            callback(result, nil)

        case "createEvent":
            guard let title = args[safe: 0] as? String,
                  let startMs = args[safe: 1] as? Double,
                  let endMs = args[safe: 2] as? Double else {
                callback(nil, "CalendarModule: missing title/startDate/endDate"); return
            }
            let notes = args[safe: 3] as? String
            let calendarId = args[safe: 4] as? String

            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.startDate = Date(timeIntervalSince1970: startMs / 1000)
            event.endDate = Date(timeIntervalSince1970: endMs / 1000)
            event.notes = notes

            if let calId = calendarId,
               let cal = eventStore.calendar(withIdentifier: calId) {
                event.calendar = cal
            } else {
                event.calendar = eventStore.defaultCalendarForNewEvents
            }

            do {
                try eventStore.save(event, span: .thisEvent)
                callback(["eventId": event.eventIdentifier ?? ""], nil)
            } catch {
                callback(nil, error.localizedDescription)
            }

        case "deleteEvent":
            guard let eventId = args[safe: 0] as? String else {
                callback(nil, "CalendarModule: missing eventId"); return
            }
            guard let event = eventStore.event(withIdentifier: eventId) else {
                callback(nil, "Event not found: \(eventId)"); return
            }
            do {
                try eventStore.remove(event, span: .thisEvent)
                callback(nil, nil)
            } catch {
                callback(nil, error.localizedDescription)
            }

        case "getCalendars":
            let calendars = eventStore.calendars(for: .event)
            let result = calendars.map { calendarToDict($0) }
            callback(result, nil)

        default:
            callback(nil, "CalendarModule: Unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }

    // MARK: - Helpers

    private func eventToDict(_ event: EKEvent) -> [String: Any] {
        var dict: [String: Any] = [
            "id": event.eventIdentifier ?? "",
            "title": event.title ?? "",
            "startDate": (event.startDate?.timeIntervalSince1970 ?? 0) * 1000,
            "endDate": (event.endDate?.timeIntervalSince1970 ?? 0) * 1000,
            "isAllDay": event.isAllDay,
            "calendarId": event.calendar?.calendarIdentifier ?? "",
        ]
        if let notes = event.notes { dict["notes"] = notes }
        if let location = event.location { dict["location"] = location }
        return dict
    }

    private func calendarToDict(_ calendar: EKCalendar) -> [String: Any] {
        return [
            "id": calendar.calendarIdentifier,
            "title": calendar.title,
            "color": hexString(from: calendar.cgColor),
            "isImmutable": calendar.isImmutable,
            "type": calendarTypeString(calendar.type),
        ]
    }

    private func calendarTypeString(_ type: EKCalendarType) -> String {
        switch type {
        case .local: return "local"
        case .calDAV: return "calDAV"
        case .exchange: return "exchange"
        case .subscription: return "subscription"
        case .birthday: return "birthday"
        @unknown default: return "unknown"
        }
    }

    private func hexString(from cgColor: CGColor?) -> String {
        guard let color = cgColor,
              let components = color.components,
              components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#endif
