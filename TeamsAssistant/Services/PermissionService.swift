import Foundation
import AVFoundation
import Cocoa

class PermissionService {
    static let shared = PermissionService()
    
    private init() {}
    
    // Check and request microphone permissions
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            showPermissionAlert(for: "Microphone", 
                               message: "This app needs microphone access to record meeting audio. Please enable it in System Preferences.")
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    // Check if screen recording permission is granted
    func checkScreenRecordingPermission() -> Bool {
        let screenshotTask = Process()
        screenshotTask.launchPath = "/usr/sbin/screencapture"
        screenshotTask.arguments = ["-x", "-t", "jpg", "/tmp/temp_screen_check.jpg"]
        
        screenshotTask.launch()
        screenshotTask.waitUntilExit()
        
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: "/tmp/temp_screen_check.jpg")
        
        if exists {
            try? fileManager.removeItem(atPath: "/tmp/temp_screen_check.jpg")
        }
        
        return exists && screenshotTask.terminationStatus == 0
    }
    
    // Request screen recording permission with guidance
    func requestScreenRecordingPermission() {
        if !checkScreenRecordingPermission() {
            showPermissionAlert(for: "Screen Recording",
                               message: "This app needs screen recording permission to detect meeting status. Please enable it in System Preferences > Security & Privacy > Privacy > Screen Recording.")
        }
    }
    
    // Request accessibility permissions
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            showPermissionAlert(for: "Accessibility",
                               message: "This app needs accessibility access to control Teams meeting buttons. Please enable it in System Preferences > Security & Privacy > Privacy > Accessibility.")
        }
    }
    
    // Request all necessary permissions
    func requestPermissionsIfNeeded() {
        requestMicrophonePermission { _ in }
        requestScreenRecordingPermission()
        requestAccessibilityPermission()
        
        // Check for automation permission by attempting a simple AppleScript
        let script = "tell application \"System Events\" to get name of first process"
        runAppleScript(script) { _, error in
            if error != nil {
                self.showPermissionAlert(for: "Automation",
                                       message: "This app needs automation permission to control Teams. Please enable it when prompted.")
            }
        }
    }
    
    // Show an alert with guidance on enabling a specific permission
    private func showPermissionAlert(for permission: String, message: String) {
        let alert = NSAlert()
        alert.messageText = "\(permission) Permission Required"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        }
    }
    
    // Run an AppleScript
    func runAppleScript(_ script: String, completion: @escaping (String?, Error?) -> Void) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            if let error = error {
                completion(nil, NSError(domain: "AppleScriptError", 
                                       code: error["NSAppleScriptErrorNumber"] as? Int ?? 0,
                                       userInfo: ["description": error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"]))
            } else {
                completion(output.stringValue, nil)
            }
        } else {
            completion(nil, NSError(domain: "AppleScriptError", code: 0, userInfo: ["description": "Failed to create script"]))
        }
    }
} 