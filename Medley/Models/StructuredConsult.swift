import Foundation

struct StructuredConsult: Codable {
    var consultationStart: String?
    var hairLossLocation: String?
    var hairLossAmount: String?
    var changesTiming: String?
    var treatmentGoals: [String]?
    var hairType: String?
    var hairLength: String?
    var familyHistory: String?
    var stressFrequency: String?
    var hairCareTime: String?
    
    enum CodingKeys: String, CodingKey {
        case consultationStart = "consultation_start"
        case hairLossLocation = "hair_loss_location"
        case hairLossAmount = "hair_loss_amount"
        case changesTiming = "changes_timing"
        case treatmentGoals = "treatment_goals"
        case hairType = "hair_type"
        case hairLength = "hair_length"
        case familyHistory = "family_history"
        case stressFrequency = "stress_frequency"
        case hairCareTime = "hair_care_time"
    }
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
