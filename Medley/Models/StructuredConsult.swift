import Foundation

struct StructuredConsult: Codable {
    var hair = Hair()
    var lifestyle = Lifestyle()
    var routine = Routine()
    var goals = Goals()

    struct Hair: Codable {
        struct Changes: Codable { var location: String?; var amount: String?; var duration: String? }
        var changes = Changes()
        var pattern: String?
        var type: String?
        var length: String?
    }

    struct Lifestyle: Codable { var family_history: String?; var stress: String? }
    struct Routine: Codable { var care_time: String? }
    struct Goals: Codable {
        var open: String?
        var treatment: [String] = []
    }
}

struct ChatMessage: Identifiable, Codable {
    enum Role: String, Codable { case user, model, system }
    var id = UUID()
    let role: Role
    var text: String
    var isStreaming: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, role, text
    }
}

struct MappedAnswer { let keyPath: String; let valueId: String }
