import Foundation
import AVFoundation
import Cocoa

class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingError: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingSession: AVAudioSession?
    private var timer: Timer?
    private var currentMeetingId: UUID?
    
    private override init() {
        super.init()
        setupRecordingSession()
    }
    
    private func setupRecordingSession() {
        #if os(macOS)
        // On macOS we don't need to setup the recording session
        #else
        // This is iOS-specific code, which we keep for reference
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default)
            try recordingSession?.setActive(true)
        } catch {
            print("Failed to set up recording session: \(error.localizedDescription)")
        }
        #endif
    }
    
    func startRecording(for meetingId: UUID? = nil) {
        // Make sure we have microphone permission
        PermissionService.shared.requestMicrophonePermission { [weak self] granted in
            guard let self = self, granted else {
                self?.recordingError = "Microphone permission denied"
                return
            }
            
            self.setupAudioRecorder(for: meetingId)
        }
    }
    
    private func setupAudioRecorder(for meetingId: UUID?) {
        currentMeetingId = meetingId
        
        // Create directory for recordings if it doesn't exist
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        } catch {
            recordingError = "Could not create Recordings directory: \(error.localizedDescription)"
            return
        }
        
        // Create unique filename for the recording
        let fileName = "\(meetingId?.uuidString ?? "manual")_\(Date().timeIntervalSince1970).m4a"
        recordingURL = recordingsDirectory.appendingPathComponent(fileName)
        
        // Configure the audio settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            
            // Start recording
            if audioRecorder?.record() == true {
                isRecording = true
                recordingDuration = 0
                
                // Set up timer to update recording duration
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.recordingDuration += 1.0
                }
            } else {
                recordingError = "Could not start recording"
            }
        } catch {
            recordingError = "Failed to setup audio recorder: \(error.localizedDescription)"
        }
    }
    
    func stopRecording(completion: ((URL?, UUID?) -> Void)? = nil) {
        guard isRecording, let audioRecorder = audioRecorder else {
            completion?(nil, currentMeetingId)
            return
        }
        
        audioRecorder.stop()
        timer?.invalidate()
        timer = nil
        
        isRecording = false
        let finalURL = recordingURL
        let finalMeetingId = currentMeetingId
        
        self.audioRecorder = nil
        self.recordingURL = nil
        
        completion?(finalURL, finalMeetingId)
    }
    
    func getRecordingPath() -> URL? {
        return recordingURL
    }
    
    func cleanupOldRecordings(olderThan days: Int = 7) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: recordingsDirectory, 
                                                                      includingPropertiesForKeys: [.creationDateKey],
                                                                      options: .skipsHiddenFiles)
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            for fileURL in fileURLs {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: fileURL)
                    print("Removed old recording: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Error cleaning up old recordings: \(error.localizedDescription)")
        }
    }
}

extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        
        if !flag {
            recordingError = "Recording finished unsuccessfully"
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
        recordingError = "Recording error: \(error?.localizedDescription ?? "Unknown error")"
    }
} 