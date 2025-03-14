import Foundation
import Combine

struct Meeting: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var link: String
    var details: String
    var isRecurring: Bool
    var startTime: Date
    var endTime: Date?
    var isCompleted: Bool = false
    var isJoined: Bool = false
    var isRecording: Bool = false
    var lastTranscriptPath: String?
    
    static func == (lhs: Meeting, rhs: Meeting) -> Bool {
        return lhs.id == rhs.id
    }
}

enum MeetingStatus: String {
    case scheduled = "Scheduled"
    case active = "Active"
    case completed = "Completed"
    case failed = "Failed"
}

class MeetingsModel: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var selectedMeeting: Meeting?
    @Published var showAddMeetingSheet = false
    @Published var showJoinMeetingSheet = false
    @Published var meetingToJoin: Meeting?
    
    private let defaults = UserDefaults.standard
    
    init() {
        loadMeetings()
    }
    
    func addMeeting(_ meeting: Meeting) {
        meetings.append(meeting)
        saveMeetings()
    }
    
    func updateMeeting(_ meeting: Meeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
            saveMeetings()
        }
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        meetings.removeAll(where: { $0.id == meeting.id })
        saveMeetings()
    }
    
    func joinMeeting(_ meeting: Meeting) {
        meetingToJoin = meeting
        showJoinMeetingSheet = true
    }
    
    private func saveMeetings() {
        if let encodedData = try? JSONEncoder().encode(meetings) {
            defaults.set(encodedData, forKey: "meetings")
        }
    }
    
    private func loadMeetings() {
        if let data = defaults.data(forKey: "meetings"),
           let decodedMeetings = try? JSONDecoder().decode([Meeting].self, from: data) {
            meetings = decodedMeetings
        }
    }
    
    func getUpcomingMeetings() -> [Meeting] {
        let now = Date()
        return meetings
            .filter { !$0.isCompleted && $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }
    }
    
    func getActiveMeetings() -> [Meeting] {
        return meetings.filter { $0.isJoined && !$0.isCompleted }
    }
    
    func getCompletedMeetings() -> [Meeting] {
        return meetings.filter { $0.isCompleted }
    }
    
    func getMeetingStatus(_ meeting: Meeting) -> MeetingStatus {
        if meeting.isCompleted {
            return .completed
        } else if meeting.isJoined {
            return .active
        } else {
            return .scheduled
        }
    }
}

struct Transcript: Identifiable, Codable {
    var id: UUID = UUID()
    var meetingId: UUID
    var meetingTitle: String
    var text: String
    var createdAt: Date = Date()
    var filePath: String?
    var sentToWebhook: Bool = false
    
    var webhookPayload: [String: Any] {
        return [
            "meetingId": meetingId.uuidString,
            "meetingTitle": meetingTitle,
            "transcript": text,
            "timestamp": ISO8601DateFormatter().string(from: createdAt)
        ]
    }
} 