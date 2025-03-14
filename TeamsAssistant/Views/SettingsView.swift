import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsModel: SettingsModel
    @State private var showOpenAIKey = false
    @State private var testingWebhook = false
    @State private var webhookTestResult: String?
    @State private var webhookTestSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                // User Information Section
                settingsSection(title: "User Information") {
                    TextField("First Name", text: $settingsModel.firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.bottom, 5)
                }
                
                // API Settings Section
                settingsSection(title: "API Settings") {
                    HStack {
                        if showOpenAIKey {
                            TextField("OpenAI API Key", text: $settingsModel.openAIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            SecureField("OpenAI API Key", text: $settingsModel.openAIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        Button(action: {
                            showOpenAIKey.toggle()
                        }) {
                            Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 5)
                    
                    Text("Your API key is stored securely in the system keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 15)
                    
                    TextField("N8N.io Webhook URL", text: $settingsModel.webhookURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.bottom, 5)
                    
                    HStack {
                        Button(action: {
                            testWebhook()
                        }) {
                            HStack {
                                if testingWebhook {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text("Test Webhook Connection")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(5)
                        }
                        .disabled(testingWebhook)
                        
                        if webhookTestResult != nil {
                            HStack {
                                Image(systemName: webhookTestSuccess ? "checkmark.circle" : "xmark.circle")
                                    .foregroundColor(webhookTestSuccess ? .green : .red)
                                Text(webhookTestResult!)
                                    .font(.caption)
                                    .foregroundColor(webhookTestSuccess ? .green : .red)
                            }
                        }
                    }
                }
                
                // Behavior Settings Section
                settingsSection(title: "Behavior Settings") {
                    Toggle("Join meetings automatically", isOn: $settingsModel.joinMeetingsAutomatically)
                        .padding(.bottom, 10)
                    
                    Toggle("Record meetings automatically", isOn: $settingsModel.recordMeetingsAutomatically)
                        .padding(.bottom, 10)
                    
                    Toggle("Transcribe meetings automatically", isOn: $settingsModel.transcribeMeetingsAutomatically)
                        .padding(.bottom, 10)
                    
                    Toggle("Enable microphone after joining", isOn: $settingsModel.enabledMicrophoneAfterJoining)
                        .padding(.bottom, 10)
                    
                    Toggle("Enable camera after joining", isOn: $settingsModel.enabledCameraAfterJoining)
                        .padding(.bottom, 10)
                }
                
                // App Preferences Section
                settingsSection(title: "App Preferences") {
                    Toggle("Show notifications", isOn: $settingsModel.showNotifications)
                        .padding(.bottom, 10)
                    
                    Toggle("Launch at login", isOn: $settingsModel.launchAtLogin)
                        .padding(.bottom, 10)
                    
                    Button(action: {
                        AudioService.shared.cleanupOldRecordings()
                    }) {
                        Text("Clean Up Old Recordings")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(5)
                    }
                    .padding(.top, 5)
                }
                
                // Save Button
                Button(action: {
                    settingsModel.saveSettings()
                }) {
                    Text("Save Settings")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
            .padding(20)
            .frame(maxWidth: 600)
            .onChange(of: settingsModel.firstName) { _ in
                settingsModel.isConfigured = true
            }
            .onChange(of: settingsModel.openAIKey) { _ in
                settingsModel.isConfigured = true
            }
        }
    }
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func testWebhook() {
        testingWebhook = true
        webhookTestResult = nil
        
        WebhookService.shared.testWebhook { success, message in
            testingWebhook = false
            webhookTestSuccess = success
            
            if success {
                webhookTestResult = "Connection successful"
            } else {
                webhookTestResult = message ?? "Connection failed"
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsModel())
    }
} 