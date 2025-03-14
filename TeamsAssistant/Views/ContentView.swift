import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settingsModel: SettingsModel
    @EnvironmentObject private var meetingsModel: MeetingsModel
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            sidebar
            
            if selectedTab == 0 {
                if settingsModel.isConfigured {
                    MeetingsView()
                } else {
                    WelcomeView()
                }
            } else if selectedTab == 1 {
                SettingsView()
            } else if selectedTab == 2 {
                ActivityLogView()
            }
        }
        .sheet(isPresented: $meetingsModel.showAddMeetingSheet) {
            AddMeetingView()
                .environmentObject(meetingsModel)
        }
        .sheet(isPresented: $meetingsModel.showJoinMeetingSheet) {
            if let meeting = meetingsModel.meetingToJoin {
                JoinMeetingView(meeting: meeting)
                    .environmentObject(meetingsModel)
            }
        }
    }
    
    private var sidebar: some View {
        List {
            NavigationLink(
                destination: settingsModel.isConfigured ? MeetingsView() : WelcomeView(),
                tag: 0,
                selection: $selectedTab
            ) {
                Label("Meetings", systemImage: "video.fill")
            }
            
            NavigationLink(
                destination: SettingsView(),
                tag: 1,
                selection: $selectedTab
            ) {
                Label("Settings", systemImage: "gear")
            }
            
            NavigationLink(
                destination: ActivityLogView(),
                tag: 2,
                selection: $selectedTab
            ) {
                Label("Activity Log", systemImage: "list.bullet.rectangle")
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var settingsModel: SettingsModel
    @State private var firstName = ""
    @State private var openAIKey = ""
    @State private var webhookURL = "http://3.149.238.6:5678/webhook-test/e5b2e11d-e208-473d-a406-875de66d2696"
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("Welcome to Teams Assistant")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Let's set up a few things before we get started")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Your Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextField("Your First Name", text: $firstName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 10)
                
                Text("API Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                SecureField("OpenAI API Key", text: $openAIKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("N8N.io Webhook URL", text: $webhookURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
            }
            .frame(width: 400)
            
            Button(action: {
                // Save settings and mark as configured
                settingsModel.firstName = firstName
                settingsModel.openAIKey = openAIKey
                settingsModel.webhookURL = webhookURL
                settingsModel.isConfigured = true
                settingsModel.saveSettings()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .disabled(firstName.isEmpty || openAIKey.isEmpty)
            .padding(.top, 20)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SettingsModel())
            .environmentObject(MeetingsModel())
    }
} 