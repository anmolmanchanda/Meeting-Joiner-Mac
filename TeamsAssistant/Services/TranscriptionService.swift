import Foundation
import Combine

class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()
    
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Float = 0.0
    @Published var lastTranscriptionError: String?
    
    private let openAIEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    private var openAIKey: String {
        return UserDefaults.standard.string(forKey: "openAIKey") ?? ""
    }
    
    private var transcriptionTask: URLSessionDataTask?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func transcribeAudio(at url: URL, for meetingId: UUID?, meetingTitle: String, completion: @escaping (Transcript?) -> Void) {
        guard !openAIKey.isEmpty else {
            lastTranscriptionError = "OpenAI API key is missing. Please check your settings."
            completion(nil)
            return
        }
        
        isTranscribing = true
        transcriptionProgress = 0.0
        lastTranscriptionError = nil
        
        // Create multipart form data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: openAIEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createMultipartFormData(audioURL: url, boundary: boundary)
        
        request.httpBody = httpBody
        
        transcriptionTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false
                
                if let error = error {
                    self?.lastTranscriptionError = "Network error: \(error.localizedDescription)"
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    self?.lastTranscriptionError = "No data received from API"
                    completion(nil)
                    return
                }
                
                // Parse response
                do {
                    let response = try JSONDecoder().decode(WhisperResponse.self, from: data)
                    
                    // Create transcript object
                    let transcript = Transcript(
                        meetingId: meetingId ?? UUID(),
                        meetingTitle: meetingTitle,
                        text: response.text,
                        filePath: url.path
                    )
                    
                    // Save transcript to file
                    self?.saveTranscriptToFile(transcript)
                    
                    self?.transcriptionProgress = 1.0
                    completion(transcript)
                } catch {
                    // Try to parse error message
                    if let errorResponse = try? JSONDecoder().decode(WhisperErrorResponse.self, from: data) {
                        self?.lastTranscriptionError = "API error: \(errorResponse.error.message)"
                    } else {
                        self?.lastTranscriptionError = "Failed to parse response: \(error.localizedDescription)"
                    }
                    completion(nil)
                }
            }
        }
        
        transcriptionTask?.resume()
    }
    
    func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        isTranscribing = false
        lastTranscriptionError = "Transcription cancelled"
    }
    
    private func createMultipartFormData(audioURL: URL, boundary: String) -> Data {
        var body = Data()
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add language field (optional, can help with accuracy)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        // Read audio file data
        if let audioData = try? Data(contentsOf: audioURL) {
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Close body
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func saveTranscriptToFile(_ transcript: Transcript) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let transcriptsDirectory = documentsDirectory.appendingPathComponent("Transcripts", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
            
            let fileName = "\(transcript.meetingId)_\(Date().timeIntervalSince1970).txt"
            let fileURL = transcriptsDirectory.appendingPathComponent(fileName)
            
            // Create text content with metadata
            let content = """
            Meeting: \(transcript.meetingTitle)
            Date: \(DateFormatter.localizedString(from: transcript.createdAt, dateStyle: .medium, timeStyle: .medium))
            
            TRANSCRIPT:
            
            \(transcript.text)
            """
            
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save transcript to file: \(error.localizedDescription)")
        }
    }
    
    func loadTranscript(from url: URL) -> Transcript? {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // Parse the content to extract metadata and transcript text
            let lines = content.components(separatedBy: .newlines)
            if lines.count >= 5 {
                let meetingTitle = lines[0].replacingOccurrences(of: "Meeting: ", with: "")
                
                // Extract the transcript text (everything after "TRANSCRIPT:")
                var transcriptText = ""
                var foundTranscriptMarker = false
                
                for line in lines {
                    if foundTranscriptMarker {
                        transcriptText += line + "\n"
                    } else if line.contains("TRANSCRIPT:") {
                        foundTranscriptMarker = true
                    }
                }
                
                return Transcript(
                    meetingId: UUID(), // We don't have the original ID here
                    meetingTitle: meetingTitle,
                    text: transcriptText.trimmingCharacters(in: .whitespacesAndNewlines),
                    filePath: url.path
                )
            }
        } catch {
            print("Failed to load transcript: \(error.localizedDescription)")
        }
        
        return nil
    }
}

// Response models for OpenAI Whisper API
struct WhisperResponse: Codable {
    let text: String
}

struct WhisperErrorResponse: Codable {
    let error: WhisperError
}

struct WhisperError: Codable {
    let message: String
    let type: String
} 