import Foundation
import Combine
import Security

class SettingsModel: ObservableObject {
    // User data
    @Published var firstName: String = ""
    @Published var isConfigured: Bool = false
    
    // API credentials
    @Published var openAIKey: String = ""
    @Published var webhookURL: String = "http://3.149.238.6:5678/webhook-test/e5b2e11d-e208-473d-a406-875de66d2696"
    
    // Behavior settings
    @Published var joinMeetingsAutomatically: Bool = true
    @Published var recordMeetingsAutomatically: Bool = true
    @Published var transcribeMeetingsAutomatically: Bool = true
    @Published var enabledMicrophoneAfterJoining: Bool = true
    @Published var enabledCameraAfterJoining: Bool = true
    
    // App preferences
    @Published var showNotifications: Bool = true
    @Published var launchAtLogin: Bool = false
    
    private let keychainOpenAIKeyKey = "com.teamsassistant.openai.key"
    private let defaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    func saveSettings() {
        // Save non-sensitive settings to UserDefaults
        defaults.set(firstName, forKey: "firstName")
        defaults.set(isConfigured, forKey: "isConfigured")
        defaults.set(webhookURL, forKey: "webhookURL")
        defaults.set(joinMeetingsAutomatically, forKey: "joinMeetingsAutomatically")
        defaults.set(recordMeetingsAutomatically, forKey: "recordMeetingsAutomatically")
        defaults.set(transcribeMeetingsAutomatically, forKey: "transcribeMeetingsAutomatically")
        defaults.set(enabledMicrophoneAfterJoining, forKey: "enabledMicrophoneAfterJoining")
        defaults.set(enabledCameraAfterJoining, forKey: "enabledCameraAfterJoining")
        defaults.set(showNotifications, forKey: "showNotifications")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        
        // Save sensitive data to Keychain
        saveOpenAIKeyToKeychain()
    }
    
    func loadSettings() {
        // Load non-sensitive settings from UserDefaults
        firstName = defaults.string(forKey: "firstName") ?? ""
        isConfigured = defaults.bool(forKey: "isConfigured")
        webhookURL = defaults.string(forKey: "webhookURL") ?? "http://3.149.238.6:5678/webhook-test/e5b2e11d-e208-473d-a406-875de66d2696"
        joinMeetingsAutomatically = defaults.bool(forKey: "joinMeetingsAutomatically")
        recordMeetingsAutomatically = defaults.bool(forKey: "recordMeetingsAutomatically")
        transcribeMeetingsAutomatically = defaults.bool(forKey: "transcribeMeetingsAutomatically")
        enabledMicrophoneAfterJoining = defaults.bool(forKey: "enabledMicrophoneAfterJoining")
        enabledCameraAfterJoining = defaults.bool(forKey: "enabledCameraAfterJoining")
        showNotifications = defaults.bool(forKey: "showNotifications")
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        
        // Load sensitive data from Keychain
        loadOpenAIKeyFromKeychain()
    }
    
    // MARK: - Keychain functions
    
    private func saveOpenAIKeyToKeychain() {
        guard !openAIKey.isEmpty else { return }
        
        // Delete any existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainOpenAIKeyKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new key
        let keyData = openAIKey.data(using: .utf8)!
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainOpenAIKeyKey,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error saving OpenAI key to keychain: \(status)")
        }
    }
    
    private func loadOpenAIKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainOpenAIKeyKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) {
            self.openAIKey = key
        } else {
            self.openAIKey = ""
        }
    }
} 