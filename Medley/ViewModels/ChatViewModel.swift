import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var predefinedResponses: [String] = []
    var isComplete = false

    private(set) var schema: DataSchema
    private let model: ConversationModel

    private var currentQuestionId: String?
    var data = StructuredConsult()

    init(schema: DataSchema? = nil, model: ConversationModel? = nil) {
        // Load schema on main actor
        let loadedSchema = schema ?? (try? SchemaLoader.load()) ?? DataSchema(version: "", intro: Intro(firstQuestionId: ""), questions: [])
        self.schema = loadedSchema
        // Use FoundationModels by default
        self.model = model ?? FoundationModelsConversationModel(schema: loadedSchema)
    }

    func start() {
        messages.removeAll()
        isComplete = false
        currentQuestionId = schema.intro.firstQuestionId
        if let q = currentQuestion { predefinedResponses = q.predefinedResponses ?? [] }
        
        Task { @MainActor in
            await model.prewarm()
            
            do {
                // Create a placeholder message for streaming
                var streamingMessage = ChatMessage(role: .model, text: "", isStreaming: true)
                messages.append(streamingMessage)
                let messageIndex = messages.count - 1
                
                let stream = try await model.streamOpeningMessage(schema: schema)
                
                for await turn in stream {
                    if turn.isComplete {
                        messages[messageIndex].isStreaming = false
                    } else {
                        messages[messageIndex].text = turn.partialText
                    }
                }
            } catch {
                print("Error generating opening message: \(error)")
                let opening = await model.openingMessage(schema: schema)
                messages.append(opening)
            }
        }
    }

    var currentQuestion: Question? { currentQuestionId.flatMap { schema.byId[$0] } }

    func send(text: String) {
        guard let q = currentQuestion else { return }
        // Append user message
        messages.append(ChatMessage(role: .user, text: text))
        
        // Generate response asynchronously with streaming
        Task { @MainActor in
            do {
                // Create a placeholder message for streaming
                var streamingMessage = ChatMessage(role: .model, text: "", isStreaming: true)
                messages.append(streamingMessage)
                let messageIndex = messages.count - 1
                
                var mappedAnswer: MappedAnswer? = nil
                var nextQuestionId: String? = nil
                
                let stream = try await model.streamNextTurn(for: q, userText: text, conversationHistory: messages)
                
                for await turn in stream {
                    if turn.isComplete {
                        // Mark streaming as complete
                        messages[messageIndex].isStreaming = false
                        if let mapped = turn.mappedAnswer { 
                            mappedAnswer = mapped
                        }
                        nextQuestionId = turn.nextQuestionId
                    } else {
                        // Update with partial text
                        messages[messageIndex].text = turn.partialText
                    }
                }
                
                // Assign mapped answer after streaming completes
                if let mapped = mappedAnswer { assign(mapped) }
                
                // Advance to next question
                await advance(to: nextQuestionId)
            } catch {
                // Log error and show fallback message
                print("Error generating response: \(error)")
                messages.append(ChatMessage(role: .model, text: "I apologize, I'm having a little trouble. Could you try again?"))
            }
        }
    }

    private func advance(to nextId: String?) async {
        // Check for completion
        if nextId == "consultation_end" {
            isComplete = true
            predefinedResponses = []
            return
        }
        
        guard let nextId, let nextQ = schema.byId[nextId] else { return }
        currentQuestionId = nextId
        predefinedResponses = nextQ.predefinedResponses ?? []
        
        // If question has info, add it as a separate message before the question
        if let info = nextQ.info, !info.isEmpty {
            messages.append(ChatMessage(role: .model, text: info))
            // Delay before the question message appears
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
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
