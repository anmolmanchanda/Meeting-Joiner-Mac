import SwiftUI

struct MeetingsView: View {
    @EnvironmentObject private var meetingsModel: MeetingsModel
    @EnvironmentObject private var settingsModel: SettingsModel
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Meetings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    meetingsModel.showAddMeetingSheet = true
                }) {
                    Label("Add Meeting", systemImage: "plus")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .padding(.trailing)
            }
            .padding(.vertical)
            .background(Color(.systemBackground))
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search Meetings", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            
            // Tabs
            HStack(spacing: 20) {
                TabButton(title: "Upcoming", isSelected: selectedTab == 0, action: { selectedTab = 0 })
                TabButton(title: "Active", isSelected: selectedTab == 1, action: { selectedTab = 1 })
                TabButton(title: "Completed", isSelected: selectedTab == 2, action: { selectedTab = 2 })
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
            
            Divider()
            
            // Meeting lists
            if selectedTab == 0 {
                UpcomingMeetingsView(searchText: searchText)
            } else if selectedTab == 1 {
                ActiveMeetingsView(searchText: searchText)
            } else {
                CompletedMeetingsView(searchText: searchText)
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .foregroundColor(isSelected ? .blue : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UpcomingMeetingsView: View {
    @EnvironmentObject private var meetingsModel: MeetingsModel
    let searchText: String
    
    var filteredMeetings: [Meeting] {
        let upcomingMeetings = meetingsModel.getUpcomingMeetings()
        
        if searchText.isEmpty {
            return upcomingMeetings
        } else {
            return upcomingMeetings.filter { meeting in
                meeting.title.lowercased().contains(searchText.lowercased()) ||
                meeting.details.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        if filteredMeetings.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.clock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                
                Text("No upcoming meetings")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Button(action: {
                    meetingsModel.showAddMeetingSheet = true
                }) {
                    Text("Add a meeting")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else {
            List {
                ForEach(filteredMeetings) { meeting in
                    MeetingRow(meeting: meeting)
                        .contextMenu {
                            Button(action: {
                                meetingsModel.joinMeeting(meeting)
                            }) {
                                Label("Join Meeting", systemImage: "video.fill")
                            }
                            
                            Button(action: {
                                // Edit functionality would be implemented here
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(action: {
                                meetingsModel.deleteMeeting(meeting)
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                }
            }
            .listStyle(PlainListStyle())
        }
    }
}

struct ActiveMeetingsView: View {
    @EnvironmentObject private var meetingsModel: MeetingsModel
    let searchText: String
    
    var filteredMeetings: [Meeting] {
        let activeMeetings = meetingsModel.getActiveMeetings()
        
        if searchText.isEmpty {
            return activeMeetings
        } else {
            return activeMeetings.filter { meeting in
                meeting.title.lowercased().contains(searchText.lowercased()) ||
                meeting.details.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        if filteredMeetings.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "video.slash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                
                Text("No active meetings")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("Meetings in progress will appear here")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else {
            List {
                ForEach(filteredMeetings) { meeting in
                    ActiveMeetingRow(meeting: meeting)
                }
            }
            .listStyle(PlainListStyle())
        }
    }
}

struct CompletedMeetingsView: View {
    @EnvironmentObject private var meetingsModel: MeetingsModel
    let searchText: String
    
    var filteredMeetings: [Meeting] {
        let completedMeetings = meetingsModel.getCompletedMeetings()
        
        if searchText.isEmpty {
            return completedMeetings
        } else {
            return completedMeetings.filter { meeting in
                meeting.title.lowercased().contains(searchText.lowercased()) ||
                meeting.details.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        if filteredMeetings.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                
                Text("No completed meetings")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("Past meetings will appear here")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else {
            List {
                ForEach(filteredMeetings) { meeting in
                    CompletedMeetingRow(meeting: meeting)
                        .contextMenu {
                            Button(action: {
                                // Open transcript
                            }) {
                                Label("View Transcript", systemImage: "doc.text")
                            }
                            
                            Button(action: {
                                meetingsModel.deleteMeeting(meeting)
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                }
            }
            .listStyle(PlainListStyle())
        }
    }
}

struct MeetingRow: View {
    let meeting: Meeting
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)
                
                Text(meeting.details)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    
                    Text(formatDate(meeting.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                MeetingsModel().joinMeeting(meeting)
            }) {
                Text("Join")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ActiveMeetingRow: View {
    let meeting: Meeting
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)
                
                Text(meeting.details)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("In progress - \(formatElapsedTime(elapsedTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                MeetingService.shared.leaveMeeting()
            }) {
                Text("Leave")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1.0
        }
    }
    
    private func formatElapsedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct CompletedMeetingRow: View {
    let meeting: Meeting
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)
                
                Text(meeting.details)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(.green)
                    
                    Text(formatDate(meeting.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let endTime = meeting.endTime {
                        Text("to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(endTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if meeting.lastTranscriptPath != nil {
                Button(action: {
                    // Open transcript
                }) {
                    Text("Transcript")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MeetingsView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingsView()
            .environmentObject(MeetingsModel())
            .environmentObject(SettingsModel())
    }
} 