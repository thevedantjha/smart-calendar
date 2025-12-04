import SwiftUI

struct EventEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var calendarManager: CalendarManager
    
    @State var title: String
    @State var startDate: Date
    @State var endDate: Date
    @State var location: String
    @State var notes: String

    var onSave: ((String) -> Void)?
    
    init(data: ParsedEventData, manager: CalendarManager, onSave: ((String) -> Void)? = nil) {
        _title = State(initialValue: data.title)
        _startDate = State(initialValue: data.date)
        _endDate = State(initialValue: data.date.addingTimeInterval(3600))
        _location = State(initialValue: data.location)
        _notes = State(initialValue: data.notes)
        self.calendarManager = manager
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Title", text: $title)
                    TextField("Location", text: $location)
                }
                
                Section(header: Text("Time")) {
                    DatePicker("Starts", selection: $startDate)
                    DatePicker("Ends", selection: $endDate)
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section {
                    Button(action: saveEvent) {
                        HStack {
                            Spacer()
                            Text("Add to Calendar")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    func saveEvent() {
        do {
            try calendarManager.addEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: location,
                notes: notes
            )
            onSave?(title)
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving: \(error)")
        }
    }
}
