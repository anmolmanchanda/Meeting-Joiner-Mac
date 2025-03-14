import SwiftUI

struct JoinMeetingView: View {
    let meeting: Meeting
    @EnvironmentObject private var meetingsModel: MeetingsModel
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var meetingService = MeetingService.shared
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            HStack {
                Spacer()
                
                Button(action: {
                    if meetingService.meetingStatus == .active {
                        showLeaveMeetingAlert()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            // Meeting info
            VStack(spacing: 10) {
                Text(meeting.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(meeting.details)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                    
                    Text(meeting.link)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 5)
            }
            .padding(.horizontal)
            
            // Status area
            VStack(spacing: 15) {
                // Status icon
                statusIcon
                    .frame(width: 80, height: 80)
                
                // Status text
                Text(meetingService.statusMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Progress bar during joining
                if meetingService.isJoiningMeeting {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal, 50)
                        .padding(.top, 10)
                }
            }
            
            Spacer()
            
            // Bottom buttons
            HStack(spacing: 20) {
                if meetingService.meetingStatus == .active {
                    // Leave meeting button
                    Button(action: {
                        showLeaveMeetingAlert()
                    }) {
                        Text("Leave Meeting")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    
                    // Toggle recording button
                    Button(action: {
                        toggleRecording()
                    }) {
                        Text(AudioService.shared.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AudioService.shared.isRecording ? Color.orange : Color.green)
                            .cornerRadius(10)
                    }
                } else if meetingService.meetingStatus == .scheduled {
                    // Manual join button
                    Button(action: {
                        joinMeeting()
                    }) {
                        Text("Join Now")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(meetingService.isJoiningMeeting)
                } else if meetingService.meetingStatus == .completed {
                    // Close button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Close")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            // Automatically start joining when view appears
            joinMeeting()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var statusIcon: some View {
        Group {
            switch meetingService.meetingStatus {
            case .scheduled:
                if meetingService.isJoiningMeeting {
                    ProgressView()
                        .scaleEffect(2)
                } else {
                    Image(systemName: "calendar.badge.clock")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.blue)
                }
            case .active:
                Image(systemName: "video.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.green)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.red)
            }
        }
    }
    
    private func joinMeeting() {
        MeetingService.shared.joinMeeting(meeting: meeting)
    }
    
    private func toggleRecording() {
        if AudioService.shared.isRecording {
            AudioService.shared.stopRecording()
        } else {
            AudioService.shared.startRecording(for: meeting.id)
        }
    }
    
    private func showLeaveMeetingAlert() {
        let alert = NSAlert()
        alert.messageText = "Leave Meeting"
        alert.informativeText = "Are you sure you want to leave this meeting?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Leave")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            MeetingService.shared.leaveMeeting()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct JoinMeetingView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleMeeting = Meeting(
            title: "Weekly Team Meeting",
            link: "https://teams.microsoft.com/l/meetup-join/sample",
            details: "Weekly sync meeting with the development team",
            isRecurring: true,
            startTime: Date()
        )
        
        JoinMeetingView(meeting: sampleMeeting)
            .environmentObject(MeetingsModel())
    }
} 