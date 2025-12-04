import Foundation
import EventKit
import SwiftUI
import Combine

class CalendarManager: ObservableObject {
    private let store = EKEventStore()
    @Published var upcomingEvents: [EKEvent] = []
    @Published var isAccessGranted: Bool = false
    
    init() {
        requestAccess()
    }
    
    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAccessGranted = granted
                if granted {
                    self?.fetchUIEvents()
                }
            }
        }
    }

    func fetchUIEvents() {
        guard isAccessGranted else { return }
        let startDate = Date()
        guard let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) else { return }
        
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)
        
        DispatchQueue.main.async {
            self.upcomingEvents = events.sorted { $0.startDate < $1.startDate }
        }
    }
    
    func getEventsSummary(from startDate: Date, to endDate: Date) -> String {
        guard isAccessGranted else { return "Access denied" }
        
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        if events.isEmpty {
            return "No events."
        }
        
        var summary = ""
        var currentDayString = ""
        
        for event in events.prefix(30) {
            let dayHeader = DateFormatter.localizedString(from: event.startDate, dateStyle: .full, timeStyle: .none)
            
            if dayHeader != currentDayString {
                currentDayString = dayHeader
                summary += "\n[ \(dayHeader) ]\n"
            }
            
            let timeStr = DateFormatter.localizedString(from: event.startDate, dateStyle: .none, timeStyle: .short)
            summary += "- \(event.title ?? "Event") at \(timeStr)\n"
        }
        
        return summary
    }
    
    func addEvent(title: String, startDate: Date, endDate: Date, location: String, notes: String) throws {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
        fetchUIEvents()
    }
    
    func deleteEvent(title: String) {
        guard isAccessGranted else { return }
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 6, to: startDate)!
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)
        
        if let match = events.first(where: { $0.title.lowercased() == title.lowercased() }) {
            do {
                try store.remove(match, span: .thisEvent)
                fetchUIEvents()
            } catch {
                print("Failed to delete event: \(error)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
