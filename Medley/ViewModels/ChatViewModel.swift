import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var predefinedResponses: [String] = []

    private(set) var schema: DataSchema
    private let model: ConversationModel

    private var currentQuestionId: String?
    var data = StructuredConsult()

    init(schema: DataSchema = (try? SchemaLoader.load()) ?? DataSchema(version: "", intro: Intro(firstQuestionId: ""), questions: []),
         model: ConversationModel? = nil) {
        self.schema = schema
        // Use FoundationModels by default
        self.model = model ?? FoundationModelsConversationModel(schema: schema)
    }

    func start() {
        messages.removeAll()
        currentQuestionId = schema.intro.firstQuestionId
        if let q = currentQuestion { predefinedResponses = q.predefinedResponses ?? [] }
        
        Task {
            await model.prewarm()
            let opening = await model.openingMessage(schema: schema)
            messages.append(opening)
        }
    }

    var currentQuestion: Question? { currentQuestionId.flatMap { schema.byId[$0] } }

    func send(text: String) {
        guard let q = currentQuestion else { return }
        // Append user message
        messages.append(ChatMessage(role: .user, text: text))
        
        // Generate response asynchronously
        Task {
            do {
                let turn = try await model.nextTurn(for: q, userText: text, conversationHistory: messages)
                if let mapped = turn.mappedAnswer { assign(mapped) }
                
                // Add model's response
                if !turn.message.text.isEmpty {
                    messages.append(turn.message)
                }
                
                // Advance to next question
                advance(to: turn.nextQuestionId)
            } catch {
                // Log error and show fallback message
                print("Error generating response: \(error)")
                messages.append(ChatMessage(role: .model, text: "I apologize, I'm having a little trouble. Could you try again?"))
            }
        }
    }

    private func advance(to nextId: String?) {
        guard let nextId, let nextQ = schema.byId[nextId] else { return }
        currentQuestionId = nextId
        predefinedResponses = nextQ.predefinedResponses ?? []
        messages.append(ChatMessage(role: .model, text: nextQ.prompt))
    }

    private func assign(_ mapped: MappedAnswer) {
        // Minimal keyPath assignment using dot notation for demo
        let comps = mapped.keyPath.split(separator: ".").map(String.init)
        guard let head = comps.first else { return }
        switch head {
        case "hair":
            if comps.dropFirst().joined(separator: ".") == "changes.location" { data.hair.changes.location = mapped.valueId }
            else if comps.dropFirst().joined(separator: ".") == "changes.amount" { data.hair.changes.amount = mapped.valueId }
            else if comps.dropFirst().joined(separator: ".") == "changes.duration" { data.hair.changes.duration = mapped.valueId }
            else if comps.dropFirst().joined(separator: ".") == "pattern" { data.hair.pattern = mapped.valueId }
            else if comps.dropFirst().joined(separator: ".") == "type" { data.hair.type = mapped.valueId }
            else if comps.dropFirst().joined(separator: ".") == "length" { data.hair.length = mapped.valueId }
        case "lifestyle":
            if comps.dropFirst().joined(separator: ".") == "family_history" { data.lifestyle.family_history = mapped.valueId }
            else if comps.dropFirst().joined(separator: ".") == "stress" { data.lifestyle.stress = mapped.valueId }
        case "routine":
            if comps.dropFirst().joined(separator: ".") == "care_time" { data.routine.care_time = mapped.valueId }
        case "goals":
            if comps.dropFirst().joined(separator: ".") == "treatment" { if !data.goals.treatment.contains(mapped.valueId) { data.goals.treatment.append(mapped.valueId) } }
        default: break
        }
    }
}
