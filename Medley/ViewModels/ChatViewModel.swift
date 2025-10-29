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
        let loadedSchema = schema ?? (try? SchemaLoader.load()) ?? DataSchema(
            version: "",
            intro: Intro(firstQuestionId: ""),
            questions: []
        )
        self.schema = loadedSchema
        self.model = model ?? FoundationModelsConversationModel(schema: loadedSchema)
    }

    func start() {
        messages.removeAll()
        isComplete = false
        currentQuestionId = schema.intro.firstQuestionId
        predefinedResponses = currentQuestion?.predefinedResponses ?? []
        
        // Show typing indicator immediately
        messages.append(ChatMessage(role: .model, text: "", isStreaming: true))
        
        Task { @MainActor in
            await streamOpeningMessage()
        }
    }

    var currentQuestion: Question? {
        currentQuestionId.flatMap { schema.byId[$0] }
    }

    func send(text: String) {
        guard let question = currentQuestion else { return }
        messages.append(ChatMessage(role: .user, text: text))
        
        Task { @MainActor in
            await streamResponse(for: question, userText: text)
        }
    }

    // MARK: - Private Helpers
    
    private func streamOpeningMessage() async {
        do {
            // Message already added in start(), just get its index
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
    
    private func streamResponse(for question: Question, userText: String) async {
        do {
            // 1. Stream acknowledgment
            let streamingMessage = ChatMessage(role: .model, text: "", isStreaming: true)
            messages.append(streamingMessage)
            let messageIndex = messages.count - 1
            
            var mappedAnswer: MappedAnswer?
            var nextQuestionId: String?
            var nextQuestionInfo: String?
            
            let stream = try await model.streamNextTurn(
                for: question,
                userText: userText,
                conversationHistory: messages
            )
            
            for await turn in stream {
                if turn.isComplete {
                    messages[messageIndex].isStreaming = false
                    mappedAnswer = turn.mappedAnswer
                    nextQuestionId = turn.nextQuestionId
                    nextQuestionInfo = turn.nextQuestionInfo
                } else {
                    messages[messageIndex].text = turn.partialText
                }
            }
            
            if let mapped = mappedAnswer {
                assign(mapped)
            }
            
            await advance(to: nextQuestionId, info: nextQuestionInfo)
        } catch {
            print("Error generating response: \(error)")
            messages.append(ChatMessage(
                role: .model,
                text: "I apologize, I'm having a little trouble. Could you try again?"
            ))
        }
    }
    
    private func advance(to nextId: String?, info: String?) async {
        if nextId == "consultation_end" {
            isComplete = true
            predefinedResponses = []
            return
        }
        
        guard let nextId, let nextQuestion = schema.byId[nextId] else { return }
        currentQuestionId = nextId
        predefinedResponses = nextQuestion.predefinedResponses ?? []
        
        // Only stream info summary and question separately if info is present
        if let info, !info.isEmpty {
            // 2. Stream info summary
            do {
                var infoMessage = ChatMessage(role: .model, text: "", isStreaming: true)
                messages.append(infoMessage)
                let infoIndex = messages.count - 1
                
                let infoStream = try await model.streamInfoSummary(info: info)
                for await turn in infoStream {
                    if turn.isComplete {
                        messages[infoIndex].isStreaming = false
                    } else {
                        messages[infoIndex].text = turn.partialText
                    }
                }
                
                try? await Task.sleep(nanoseconds: 400_000_000)
            } catch {
                print("Error generating info summary: \(error)")
                messages.append(ChatMessage(role: .model, text: info))
            }
            
            // 3. Stream the question
            do {
                var questionMessage = ChatMessage(role: .model, text: "", isStreaming: true)
                messages.append(questionMessage)
                let questionIndex = messages.count - 1
                
                let questionStream = try await model.streamQuestion(for: nextQuestion)
                for await turn in questionStream {
                    if turn.isComplete {
                        messages[questionIndex].isStreaming = false
                    } else {
                        messages[questionIndex].text = turn.partialText
                    }
                }
            } catch {
                print("Error generating question: \(error)")
                messages.append(ChatMessage(role: .model, text: nextQuestion.prompt))
            }
        }
        // If no info, the acknowledgment already included the next question
    }

    private func assign(_ mapped: MappedAnswer) {
        let components = mapped.keyPath.split(separator: ".").map(String.init)
        guard let category = components.first else { return }
        
        let path = components.dropFirst().joined(separator: ".")
        
        switch category {
        case "hair":
            assignHairData(path: path, value: mapped.valueId)
        case "lifestyle":
            assignLifestyleData(path: path, value: mapped.valueId)
        case "routine":
            assignRoutineData(path: path, value: mapped.valueId)
        case "goals":
            assignGoalsData(path: path, value: mapped.valueId)
        default:
            break
        }
    }
    
    private func assignHairData(path: String, value: String) {
        switch path {
        case "changes.location":
            data.hair.changes.location = value
        case "changes.amount":
            data.hair.changes.amount = value
        case "changes.duration":
            data.hair.changes.duration = value
        case "pattern":
            data.hair.pattern = value
        case "type":
            data.hair.type = value
        case "length":
            data.hair.length = value
        default:
            break
        }
    }
    
    private func assignLifestyleData(path: String, value: String) {
        switch path {
        case "family_history":
            data.lifestyle.family_history = value
        case "stress":
            data.lifestyle.stress = value
        default:
            break
        }
    }
    
    private func assignRoutineData(path: String, value: String) {
        if path == "care_time" {
            data.routine.care_time = value
        }
    }
    
    private func assignGoalsData(path: String, value: String) {
        switch path {
        case "open":
            data.goals.open = value
        case "treatment":
            if !data.goals.treatment.contains(value) {
                data.goals.treatment.append(value)
            }
        default:
            break
        }
    }
}
