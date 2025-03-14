import SwiftUI

@main
struct TeamsAssistantApp: App {
    @StateObject private var settingsModel = SettingsModel()
    @StateObject private var meetingsModel = MeetingsModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsModel)
                .environmentObject(meetingsModel)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                    
                    // Request necessary permissions if not already granted
                    PermissionService.shared.requestPermissionsIfNeeded()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            CommandMenu("Meetings") {
                Button("Add New Meeting") {
                    meetingsModel.showAddMeetingSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Divider()
                
                Button("Join Selected Meeting") {
                    guard let selectedMeeting = meetingsModel.selectedMeeting else { return }
                    MeetingService.shared.joinMeeting(meeting: selectedMeeting)
                }
                .keyboardShortcut("j", modifiers: [.command])
                .disabled(meetingsModel.selectedMeeting == nil)
            }
            
            CommandMenu("Recording") {
                Button("Start Recording") {
                    AudioService.shared.startRecording()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(AudioService.shared.isRecording)
                
                Button("Stop Recording") {
                    AudioService.shared.stopRecording()
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(!AudioService.shared.isRecording)
            }
        }
    }
} 