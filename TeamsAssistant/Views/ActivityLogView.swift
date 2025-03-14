import SwiftUI

// Define log entry struct
struct LogEntry: Identifiable, Equatable {
    var id = UUID()
    var timestamp: Date
    var level: LogLevel
    var message: String
    var details: String?
    
    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

enum LogLevel: String, CaseIterable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case success = "Success"
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .success:
            return .green
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .success:
            return "checkmark.circle"
        }
    }
}

// Logger class
class Logger: ObservableObject {
    static let shared = Logger()
    
    @Published var logs: [LogEntry] = []
    
    private init() {
        // Add welcome log entry
        logs.append(LogEntry(
            timestamp: Date(),
            level: .info,
            message: "Teams Assistant started",
            details: "Welcome to Teams Assistant. The application is ready to use."
        ))
    }
    
    func log(_ message: String, level: LogLevel = .info, details: String? = nil) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message, details: details)
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
            
            // Limit log size
            if self.logs.count > 1000 {
                self.logs.removeLast()
            }
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.log("Logs cleared", level: .info)
        }
    }
}

struct ActivityLogView: View {
    @ObservedObject private var logger = Logger.shared
    @State private var selectedLogEntry: LogEntry?
    @State private var filterLevel: LogLevel?
    @State private var searchText = ""
    
    var filteredLogs: [LogEntry] {
        var result = logger.logs
        
        // Apply level filter
        if let level = filterLevel {
            result = result.filter { $0.level == level }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { log in
                log.message.lowercased().contains(searchText.lowercased()) ||
                (log.details?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity Log")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    logger.clearLogs()
                }) {
                    Text("Clear Logs")
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red)
                        .cornerRadius(5)
                }
                .padding(.trailing)
            }
            .padding(.vertical)
            
            // Search and filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search Logs", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Level filter menu
                Menu {
                    Button(action: {
                        filterLevel = nil
                    }) {
                        HStack {
                            Text("All Levels")
                            if filterLevel == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button(action: {
                            filterLevel = level
                        }) {
                            HStack {
                                Image(systemName: level.icon)
                                    .foregroundColor(level.color)
                                Text(level.rawValue)
                                if filterLevel == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let level = filterLevel {
                            Image(systemName: level.icon)
                                .foregroundColor(level.color)
                            Text(level.rawValue)
                        } else {
                            Text("All Levels")
                        }
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(5)
                }
            }
            .padding()
            
            // Logs list
            if filteredLogs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray)
                    
                    Text("No logs matching your criteria")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if filterLevel != nil || !searchText.isEmpty {
                        Button(action: {
                            filterLevel = nil
                            searchText = ""
                        }) {
                            Text("Clear filters")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredLogs) { log in
                        LogEntryRow(logEntry: log)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedLogEntry = log
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(item: $selectedLogEntry) { logEntry in
            LogDetailView(logEntry: logEntry)
        }
    }
}

struct LogEntryRow: View {
    let logEntry: LogEntry
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        HStack {
            Image(systemName: logEntry.level.icon)
                .foregroundColor(logEntry.level.color)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(logEntry.message)
                    .font(.headline)
                
                Text(dateFormatter.string(from: logEntry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if logEntry.details != nil {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(.vertical, 5)
    }
}

struct LogDetailView: View {
    let logEntry: LogEntry
    @Environment(\.presentationMode) private var presentationMode
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: logEntry.level.icon)
                            .foregroundColor(logEntry.level.color)
                            .font(.title)
                        
                        Text(logEntry.level.rawValue)
                            .font(.headline)
                            .foregroundColor(logEntry.level.color)
                    }
                    
                    Text(logEntry.message)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(dateFormatter.string(from: logEntry.timestamp))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    if let details = logEntry.details {
                        Text("Details")
                            .font(.headline)
                        
                        Text(details)
                            .font(.body)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("Log Details", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ActivityLogView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityLogView()
    }
} 