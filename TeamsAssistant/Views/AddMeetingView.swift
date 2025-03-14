import SwiftUI
import AppKit

struct AddMeetingView: View {
    @EnvironmentObject private var meetingsModel: MeetingsModel
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var title = ""
    @State private var link = ""
    @State private var details = ""
    @State private var isRecurring = false
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var isValidLink = true
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meeting Details")) {
                    TextField("Meeting Title", text: $title)
                    
                    ZStack(alignment: .topLeading) {
                        if details.isEmpty {
                            Text("Meeting Description (Optional)")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $details)
                            .frame(minHeight: 100)
                            .padding(.horizontal, -4)
                    }
                }
                
                Section(header: Text("Teams Link")) {
                    TextField("Microsoft Teams Meeting Link", text: $link)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: link) { newValue in
                            validateTeamsLink(newValue)
                        }
                    
                    if !isValidLink && !link.isEmpty {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Meeting Time")) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Recurring Meeting", isOn: $isRecurring)
                }
            }
            .navigationTitle("Add Meeting")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveMeeting()
                }
                .disabled(title.isEmpty || link.isEmpty || !isValidLink)
            )
        }
        .onAppear {
            // Pre-fill with clipboard if it contains a Teams link
            if let clipboardString = NSPasteboard.general.string(forType: .string), isTeamsLink(clipboardString) {
                link = clipboardString
                validateTeamsLink(clipboardString)
            }
        }
    }
    
    private func saveMeeting() {
        // Combine date and time components
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        guard let startDate = calendar.date(from: combinedComponents) else {
            return
        }
        
        // Create new meeting
        let meeting = Meeting(
            title: title,
            link: link,
            details: details,
            isRecurring: isRecurring,
            startTime: startDate
        )
        
        // Add to model
        meetingsModel.addMeeting(meeting)
        
        // Dismiss sheet
        presentationMode.wrappedValue.dismiss()
    }
    
    private func validateTeamsLink(_ link: String) {
        if link.isEmpty {
            isValidLink = true
            validationMessage = ""
            return
        }
        
        if isTeamsLink(link) {
            isValidLink = true
            validationMessage = ""
        } else {
            isValidLink = false
            validationMessage = "Please enter a valid Microsoft Teams meeting link"
        }
    }
    
    private func isTeamsLink(_ link: String) -> Bool {
        // Teams links typically have these formats:
        // https://teams.microsoft.com/l/meetup-join/...
        // https://teams.live.com/meet/...
        
        guard let url = URL(string: link) else { return false }
        
        if url.host?.contains("teams.microsoft.com") == true && 
            url.path.contains("/l/meetup-join/") {
            return true
        }
        
        if url.host?.contains("teams.live.com") == true && 
            url.path.contains("/meet/") {
            return true
        }
        
        return false
    }
}

struct AddMeetingView_Previews: PreviewProvider {
    static var previews: some View {
        AddMeetingView()
            .environmentObject(MeetingsModel())
    }
} 