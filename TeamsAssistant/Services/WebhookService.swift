import Foundation
import Combine

class WebhookService: ObservableObject {
    static let shared = WebhookService()
    
    @Published var isSending = false
    @Published var lastError: String?
    
    private var webhookURL: String {
        return UserDefaults.standard.string(forKey: "webhookURL") ?? "http://3.149.238.6:5678/webhook-test/e5b2e11d-e208-473d-a406-875de66d2696"
    }
    
    private var sendTask: URLSessionDataTask?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func sendTranscript(_ transcript: Transcript, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: webhookURL) else {
            lastError = "Invalid webhook URL"
            completion(false)
            return
        }
        
        isSending = true
        lastError = nil
        
        // Convert transcript to JSON
        let jsonPayload = transcript.webhookPayload
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonPayload, options: [])
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            sendTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    self?.isSending = false
                    
                    if let error = error {
                        self?.lastError = "Network error: \(error.localizedDescription)"
                        completion(false)
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        self?.lastError = "Invalid response"
                        completion(false)
                        return
                    }
                    
                    // Check if the request was successful
                    if (200...299).contains(httpResponse.statusCode) {
                        completion(true)
                    } else {
                        self?.lastError = "HTTP Error: \(httpResponse.statusCode)"
                        
                        // Try to parse error response
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            self?.lastError! += " - \(errorString)"
                        }
                        
                        completion(false)
                    }
                }
            }
            
            sendTask?.resume()
        } catch {
            isSending = false
            lastError = "JSON serialization error: \(error.localizedDescription)"
            completion(false)
        }
    }
    
    func cancelSending() {
        sendTask?.cancel()
        sendTask = nil
        isSending = false
        lastError = "Webhook sending cancelled"
    }
    
    // Retry mechanism for failed webhook sends
    func retryFailedTranscripts() {
        // Load all transcripts that weren't sent successfully
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let transcriptsDirectory = documentsDirectory.appendingPathComponent("Transcripts", isDirectory: true)
        
        do {
            if !FileManager.default.fileExists(atPath: transcriptsDirectory.path) {
                return
            }
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: transcriptsDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "txt" {
                    if let transcript = TranscriptionService.shared.loadTranscript(from: fileURL),
                       !transcript.sentToWebhook {
                        
                        sendTranscript(transcript) { success in
                            if success {
                                // Mark as sent by appending a note to the transcript file
                                do {
                                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                                    let updatedContent = content + "\n\n[SENT TO WEBHOOK: \(Date())]"
                                    try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
                                } catch {
                                    print("Failed to update transcript file: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error retrying failed transcripts: \(error.localizedDescription)")
        }
    }
    
    // Test webhook connection
    func testWebhook(completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: webhookURL) else {
            completion(false, "Invalid webhook URL")
            return
        }
        
        // Create a test payload
        let testPayload: [String: Any] = [
            "type": "connection_test",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "message": "Teams Assistant connection test"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: testPayload, options: [])
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "Network error: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "Invalid response")
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    if (200...299).contains(httpResponse.statusCode) {
                        completion(true, nil)
                    } else {
                        var errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            errorMessage += " - \(responseString)"
                        }
                        completion(false, errorMessage)
                    }
                }
            }.resume()
        } catch {
            DispatchQueue.main.async {
                completion(false, "JSON serialization error: \(error.localizedDescription)")
            }
        }
    }
} 