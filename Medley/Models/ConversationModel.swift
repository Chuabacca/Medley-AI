import FoundationModels
import Foundation

protocol ConversationModel {
    func prewarm() async -> Void
    func openingMessage(schema: DataSchema) async -> ChatMessage
    func nextTurn(for question: Question, userText: String?, conversationHistory: [ChatMessage]) async throws -> ModelTurn
}

struct ModelTurn {
    let message: ChatMessage
    let mappedAnswer: MappedAnswer?
    let nextQuestionId: String?
}

/// FoundationModels-powered conversation model with dynamic response generation
final class FoundationModelsConversationModel: ConversationModel {
    private var session: LanguageModelSession
    private let schema: DataSchema
    
    init(schema: DataSchema) {
        self.schema = schema
        
        let instructions = Instructions {
            "You are the first point of contact for users coming to Hims & Hers for their healthcare needs."
            "You are an experienced, empathetic medical professional conducting a hair loss consultation."
            "Your role is to guide the patient through a series of questions with a warm bedside manner."
            "For each question, provide a conversational, professional prompt based on the question context."
            "When the user answers, acknowledge their response naturally before moving to the next question."
            "Keep responses concise, supportive, and medically appropriate."
            "Do not make diagnoses or treatment recommendations—only collect information."
        }
        
        self.session = LanguageModelSession(instructions: instructions)
    }
    
    func prewarm() async {
        session.prewarm()
    }
    
    func openingMessage(schema: DataSchema) async -> ChatMessage {
        let qid = schema.intro.firstQuestionId
        guard let firstQuestion = schema.byId[qid] else {
            return ChatMessage(role: .model, text: "Let's get started.")
        }
        
        do {
            let prompt = Prompt {
                "Generate a warm opening message for a hair loss consultation."
                "The first question will be about: \(firstQuestion.prompt)"
                "Keep the opening brief, friendly, and professional. Then ask the first question naturally."
                "Inform users that they can type in their own responses or choose an option from the buttons below."
                "The options are generated in the UI, don't list them in your response. Don't use bullet points."
            }
            
            var responseText = ""
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                responseText = snapshot.content
            }
            
            return ChatMessage(role: .model, text: responseText.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            // Fallback to static prompt
            return ChatMessage(role: .model, text: firstQuestion.prompt)
        }
    }
    
    func nextTurn(for question: Question, userText: String?, conversationHistory: [ChatMessage]) async throws -> ModelTurn {
        guard let text = userText else {
            return ModelTurn(message: ChatMessage(role: .model, text: question.prompt), mappedAnswer: nil, nextQuestionId: question.next?.default)
        }
        
        // Map the user's response to structured data
        var mapped: MappedAnswer? = nil
        if let key = question.key {
            if let opt = question.options?.first(where: { 
                $0.label.caseInsensitiveCompare(text).rawValue == 0 || $0.id == text 
            }) {
                mapped = MappedAnswer(keyPath: key, valueId: opt.id)
            } else if question.type == .free_text {
                mapped = MappedAnswer(keyPath: key, valueId: text)
            }
        }
        
        // Generate dynamic acknowledgment and next question using the LLM
        let nextId = question.next?.default
        
        // Check if consultation is complete
        if nextId == "__complete__" || nextId == nil {
            let prompt = Prompt {
                "The patient has completed the consultation."
                "Generate a brief, warm closing message thanking them and letting them know you've gathered the information needed."
            }
            
            var responseText = ""
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                responseText = snapshot.content
            }
            
            return ModelTurn(
                message: ChatMessage(role: .model, text: responseText.trimmingCharacters(in: .whitespacesAndNewlines)),
                mappedAnswer: mapped,
                nextQuestionId: nextId
            )
        }
        
        guard let nextQuestionId = nextId, let nextQuestion = schema.byId[nextQuestionId] else {
            // Invalid next question ID
            return ModelTurn(
                message: ChatMessage(role: .model, text: "Thank you for sharing that information."),
                mappedAnswer: mapped,
                nextQuestionId: nil
            )
        }
        
        // Generate transition to next question
        let prompt = Prompt {
            "Previous question: \(question.prompt)"
            "Patient's answer: \(text)"
            "Next question topic: \(nextQuestion.prompt)"
            if let options = nextQuestion.options, !options.isEmpty {
                "Available response options: \(options.map { $0.label }.joined(separator: ", "))"
            }
            "Generate a brief acknowledgment of the patient's answer followed by the next question."
            "Keep the tone warm, professional, and conversational."
//            "Be concise - aim for 1-2 sentences maximum."
        }
        
        var responseText = ""
        let stream = session.streamResponse(to: prompt)
        for try await snapshot in stream {
            responseText = snapshot.content
        }
        
        return ModelTurn(
            message: ChatMessage(role: .model, text: responseText.trimmingCharacters(in: .whitespacesAndNewlines)),
            mappedAnswer: mapped,
            nextQuestionId: nextQuestionId
        )
    }
}
