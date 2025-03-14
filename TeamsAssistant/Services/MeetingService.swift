import Foundation
import Cocoa
import AVFoundation
import AppKit

class MeetingService: ObservableObject {
    static let shared = MeetingService()
    
    @Published var isJoiningMeeting = false
    @Published var currentMeeting: Meeting?
    @Published var meetingStatus: MeetingStatus = .scheduled
    @Published var statusMessage: String = ""
    
    private var permissionHandlerTask: DispatchWorkItem?
    private var meetingMonitorTimer: Timer?
    private var meetingJoinedTime: Date?
    private var firstName: String {
        return UserDefaults.standard.string(forKey: "firstName") ?? ""
    }
    
    private init() {}
    
    // Method to join a Teams meeting
    func joinMeeting(meeting: Meeting) {
        guard !isJoiningMeeting else {
            statusMessage = "Already joining a meeting"
            return
        }
        
        // Update states
        isJoiningMeeting = true
        currentMeeting = meeting
        meetingStatus = .scheduled
        statusMessage = "Preparing to join meeting..."
        
        // Validate meeting link
        guard isValidTeamsLink(meeting.link) else {
            isJoiningMeeting = false
            statusMessage = "Invalid Microsoft Teams meeting link"
            return
        }
        
        // Prepare to launch Teams
        launchTeamsWithMeetingLink(meeting.link)
    }
    
    // Validate if string is a Teams meeting link
    private func isValidTeamsLink(_ link: String) -> Bool {
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
    
    // Launch Teams with the meeting link
    private func launchTeamsWithMeetingLink(_ link: String) {
        statusMessage = "Launching Microsoft Teams..."
        
        // Check if Teams is installed
        let teamsAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.teams")
        
        if teamsAppURL == nil {
            // Teams isn't installed, try to open with browser
            if let url = URL(string: link) {
                NSWorkspace.shared.open(url)
                handleMeetingJoinProcess()
            } else {
                isJoiningMeeting = false
                statusMessage = "Failed to parse meeting link"
            }
            return
        }
        
        // Teams is installed, prepare AppleScript to open it with the meeting link
        let script = """
        tell application "Microsoft Teams"
            activate
        end tell
        
        delay 2
        
        do shell script "open '\(link)'"
        """
        
        PermissionService.shared.runAppleScript(script) { [weak self] _, error in
            guard let self = self else { return }
            
            if let error = error {
                self.isJoiningMeeting = false
                self.statusMessage = "Failed to launch Teams: \(error.localizedDescription)"
                return
            }
            
            // Teams launch succeeded, now handle the join process
            self.handleMeetingJoinProcess()
        }
    }
    
    // Handle the process after Teams is launched
    private func handleMeetingJoinProcess() {
        statusMessage = "Waiting for Microsoft Teams to load..."
        
        // Give Teams a moment to open
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.statusMessage = "Handling dialog boxes..."
            
            // Start monitoring for dialog boxes
            self.startDialogMonitoring()
            
            // Set up a meeting monitor for detecting when meeting ends
            self.setupMeetingMonitor()
        }
    }
    
    // Monitor for and handle dialog boxes
    private func startDialogMonitoring() {
        // Cancel any existing dialog handler
        permissionHandlerTask?.cancel()
        
        // Create a new task for handling dialogs
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Monitor for 2 minutes
            var elapsedTime: TimeInterval = 0
            let monitorInterval: TimeInterval = 3
            let maxMonitorTime: TimeInterval = 120
            
            while elapsedTime < maxMonitorTime {
                // Check for and handle dialogs
                self.checkAndHandleDialogs()
                
                // Sleep for interval
                Thread.sleep(forTimeInterval: monitorInterval)
                elapsedTime += monitorInterval
                
                // Check if we already detected that we're in the meeting
                if self.meetingStatus == .active {
                    break
                }
            }
            
            // If we still haven't joined the meeting, handle it
            if self.meetingStatus != .active {
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to join meeting within the time limit"
                    self.isJoiningMeeting = false
                }
            }
        }
        
        permissionHandlerTask = task
        DispatchQueue.global(qos: .userInitiated).async(execute: task)
    }
    
    // Check for and handle dialog boxes
    private func checkAndHandleDialogs() {
        // Check for permission dialog boxes
        checkForPermissionDialogs()
        
        // Check for meeting join screens
        checkForJoinScreen()
        
        // Check for name input field
        checkForNameInputField()
        
        // Check for camera/mic controls
        checkForMediaControls()
    }
    
    // Check for system permission dialogs and allow them
    private func checkForPermissionDialogs() {
        let script = """
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
            
            if frontApp is "Microsoft Teams" then
                -- Check for permission dialogs
                set dialogExists to false
                
                -- Check for standard permission dialog
                try
                    if exists (window 1 whose subrole is "AXDialog") then
                        set dialogExists to true
                        -- Look for Allow button
                        if exists button "Allow" of window 1 then
                            click button "Allow" of window 1
                            return "Clicked Allow on permission dialog"
                        end if
                        
                        -- Look for OK button
                        if exists button "OK" of window 1 then
                            click button "OK" of window 1
                            return "Clicked OK on permission dialog"
                        end if
                    end if
                end try
                
                -- Check for accessibility dialog (macOS specific)
                try
                    if exists (window 1 whose title contains "wants access") then
                        set dialogExists to true
                        if exists button "Allow" of window 1 then
                            click button "Allow" of window 1
                            return "Clicked Allow on accessibility dialog"
                        end if
                    end if
                end try
                
                return "No dialogs found"
            end if
            
            return "Teams is not frontmost"
        end tell
        """
        
        PermissionService.shared.runAppleScript(script) { [weak self] result, error in
            if error == nil, let result = result {
                DispatchQueue.main.async {
                    if result.contains("Clicked") {
                        self?.statusMessage = "Handled permission dialog"
                    }
                }
            }
        }
    }
    
    // Check for the Join screen and click the join button
    private func checkForJoinScreen() {
        let script = """
        tell application "System Events"
            if exists process "Microsoft Teams" then
                tell process "Microsoft Teams"
                    try
                        -- Look for the Join button
                        if exists (button 1 whose name contains "Join" or description contains "Join") then
                            click (button 1 whose name contains "Join" or description contains "Join")
                            return "Clicked Join button"
                        end if
                    end try
                end tell
            end if
            
            return "Join button not found"
        end tell
        """
        
        PermissionService.shared.runAppleScript(script) { [weak self] result, error in
            if error == nil, let result = result, result.contains("Clicked Join") {
                DispatchQueue.main.async {
                    self?.statusMessage = "Joining meeting..."
                    
                    // Wait a moment and then check if we need to enter a name
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.checkForNameInputField()
                    }
                }
            }
        }
    }
    
    // Check for name input field and enter the user's name
    private func checkForNameInputField() {
        guard !firstName.isEmpty else { return }
        
        let script = """
        tell application "System Events"
            if exists process "Microsoft Teams" then
                tell process "Microsoft Teams"
                    try
                        -- Look for text fields that might be for name input
                        repeat with tf in (text fields of windows)
                            set tfValue to value of tf as string
                            if tfValue is "" then
                                set focused of tf to true
                                keystroke "\(firstName)"
                                delay 0.5
                                return "Entered name"
                            end if
                        end repeat
                    end try
                end tell
            end if
            
            return "Name field not found"
        end tell
        """
        
        PermissionService.shared.runAppleScript(script) { [weak self] result, error in
            if error == nil, let result = result, result.contains("Entered name") {
                DispatchQueue.main.async {
                    self?.statusMessage = "Entered name in meeting"
                }
            }
        }
    }
    
    // Check for camera and microphone controls and enable them if needed
    private func checkForMediaControls() {
        let script = """
        tell application "System Events"
            if exists process "Microsoft Teams" then
                tell process "Microsoft Teams"
                    set controlsFound to false
                    
                    try
                        -- Look for camera toggle
                        if exists (checkbox 1 whose description contains "camera" or description contains "video") then
                            set controlsFound to true
                            set cameraCheckbox to checkbox 1 whose description contains "camera" or description contains "video"
                            
                            -- Check if camera is off (assuming unchecked means on in Teams UI)
                            if value of cameraCheckbox is 0 then
                                -- Camera is already on
                            else
                                -- Camera is off, turn it on
                                click cameraCheckbox
                            end if
                        end if
                    end try
                    
                    try
                        -- Look for microphone toggle
                        if exists (checkbox 1 whose description contains "microphone" or description contains "audio") then
                            set controlsFound to true
                            set micCheckbox to checkbox 1 whose description contains "microphone" or description contains "audio"
                            
                            -- Check if microphone is off
                            if value of micCheckbox is 0 then
                                -- Mic is already on
                            else
                                -- Mic is off, turn it on
                                click micCheckbox
                            end if
                        end if
                    end try
                    
                    if controlsFound then
                        return "Media controls handled"
                    else
                        return "Media controls not found"
                    end if
                end tell
            end if
            
            return "Teams not found"
        end tell
        """
        
        PermissionService.shared.runAppleScript(script) { [weak self] result, error in
            if error == nil, let result = result, result.contains("Media controls handled") {
                DispatchQueue.main.async {
                    self?.statusMessage = "Camera and microphone ready"
                    
                    // We've successfully handled controls, which means we're in the meeting
                    self?.meetingJoined()
                }
            }
        }
    }
    
    // Handle successful meeting join
    private func meetingJoined() {
        guard let meeting = currentMeeting else { return }
        
        isJoiningMeeting = false
        meetingStatus = .active
        meetingJoinedTime = Date()
        statusMessage = "Successfully joined meeting"
        
        // Update the meeting in the model
        var updatedMeeting = meeting
        updatedMeeting.isJoined = true
        
        // Start recording if settings allow
        if UserDefaults.standard.bool(forKey: "recordMeetingsAutomatically") {
            AudioService.shared.startRecording(for: meeting.id)
            updatedMeeting.isRecording = true
            statusMessage = "Recording meeting audio"
        }
        
        // Update the meeting model
        MeetingsModel().updateMeeting(updatedMeeting)
    }
    
    // Set up timer to monitor the meeting
    private func setupMeetingMonitor() {
        // Cancel any existing timer
        meetingMonitorTimer?.invalidate()
        
        // Create a new timer to check meeting status every 15 seconds
        meetingMonitorTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkMeetingStatus()
        }
    }
    
    // Check if the meeting is still active
    private func checkMeetingStatus() {
        let script = """
        tell application "System Events"
            if exists process "Microsoft Teams" then
                tell process "Microsoft Teams"
                    try
                        -- Check for typical meeting UI elements
                        if exists (button whose description contains "Leave" or description contains "End") then
                            return "Meeting active"
                        end if
                        
                        -- Check for participants panel
                        if exists (group whose description contains "Participants" or description contains "People") then
                            return "Meeting active"
                        end if
                        
                        -- Check for chat panel
                        if exists (group whose description contains "Chat" or description contains "Messages") then
                            return "Meeting active"
                        end if
                    end try
                    
                    return "Meeting not detected"
                end tell
            else
                return "Teams not running"
            end if
        end tell
        """
        
        PermissionService.shared.runAppleScript(script) { [weak self] result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if error != nil || result != "Meeting active" {
                    // Meeting might have ended
                    self.checkIfMeetingEnded()
                }
            }
        }
    }
    
    // Check if the meeting has ended
    private func checkIfMeetingEnded() {
        // Consider a meeting ended if we can't detect it for 3 consecutive checks
        static var consecutiveFailures = 0
        
        if meetingStatus == .active {
            consecutiveFailures += 1
            
            if consecutiveFailures >= 3 {
                // Meeting has likely ended
                meetingEnded()
                consecutiveFailures = 0
            }
        } else {
            consecutiveFailures = 0
        }
    }
    
    // Handle meeting end
    private func meetingEnded() {
        guard let meeting = currentMeeting else { return }
        
        meetingMonitorTimer?.invalidate()
        meetingMonitorTimer = nil
        
        meetingStatus = .completed
        statusMessage = "Meeting ended"
        
        // Stop recording if active
        if AudioService.shared.isRecording {
            AudioService.shared.stopRecording { [weak self] recordingURL, meetingId in
                guard let self = self, let recordingURL = recordingURL else { return }
                
                // Transcribe the recording
                if UserDefaults.standard.bool(forKey: "transcribeMeetingsAutomatically") {
                    self.statusMessage = "Transcribing meeting audio..."
                    
                    TranscriptionService.shared.transcribeAudio(
                        at: recordingURL,
                        for: meetingId,
                        meetingTitle: meeting.title
                    ) { [weak self] transcript in
                        guard let self = self, let transcript = transcript else {
                            self?.statusMessage = "Transcription failed"
                            return
                        }
                        
                        // Send transcript to webhook
                        self.statusMessage = "Sending transcript to webhook..."
                        
                        WebhookService.shared.sendTranscript(transcript) { success in
                            DispatchQueue.main.async {
                                if success {
                                    self.statusMessage = "Transcript sent successfully"
                                } else {
                                    self.statusMessage = "Failed to send transcript: \(WebhookService.shared.lastError ?? "Unknown error")"
                                }
                                
                                // Clean up and complete meeting
                                self.completeMeeting(meeting)
                            }
                        }
                    }
                } else {
                    // Just complete the meeting without transcribing
                    self.completeMeeting(meeting)
                }
            }
        } else {
            // No recording, just complete the meeting
            completeMeeting(meeting)
        }
    }
    
    // Complete the meeting process
    private func completeMeeting(_ meeting: Meeting) {
        var updatedMeeting = meeting
        updatedMeeting.isJoined = false
        updatedMeeting.isRecording = false
        updatedMeeting.isCompleted = true
        updatedMeeting.endTime = Date()
        
        // Update the meeting model
        MeetingsModel().updateMeeting(updatedMeeting)
        
        // Reset state
        currentMeeting = nil
        meetingJoinedTime = nil
    }
    
    // Force leave current meeting
    func leaveMeeting() {
        guard meetingStatus == .active else { return }
        
        let script = """
        tell application "System Events"
            if exists process "Microsoft Teams" then
                tell process "Microsoft Teams"
                    try
                        -- Look for leave/hang up button
                        if exists (button whose description contains "Leave" or description contains "End" or description contains "Hang up") then
                            click (button whose description contains "Leave" or description contains "End" or description contains "Hang up")
                            return "Left meeting"
                        end if
                    end try
                end tell
            end if
            
            return "Leave button not found"
        end tell
        """
        
        PermissionService.shared.runAppleScript(script) { [weak self] result, error in
            DispatchQueue.main.async {
                if error == nil, let result = result, result.contains("Left meeting") {
                    self?.meetingEnded()
                } else {
                    // If we couldn't find leave button, try to close Teams window
                    self?.forceCloseTeamsWindow()
                }
            }
        }
    }
    
    // Force close Teams window as a last resort
    private func forceCloseTeamsWindow() {
        let script = """
        tell application "Microsoft Teams" to quit
        """
        
        PermissionService.shared.runAppleScript(script) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.meetingEnded()
            }
        }
    }
    
    // Clean up resources when app is terminating
    func cleanup() {
        // Stop any recordings
        if AudioService.shared.isRecording {
            AudioService.shared.stopRecording()
        }
        
        // Stop meeting monitor
        meetingMonitorTimer?.invalidate()
        meetingMonitorTimer = nil
        
        // Cancel permission handler
        permissionHandlerTask?.cancel()
        permissionHandlerTask = nil
    }
} 