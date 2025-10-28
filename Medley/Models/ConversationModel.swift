import FoundationModels
import Foundation

protocol ConversationModel {
    func prewarm() async
    func openingMessage(schema: DataSchema) async -> ChatMessage
    func streamOpeningMessage(schema: DataSchema) async throws -> AsyncStream<StreamingTurn>
    func streamNextTurn(for question: Question, userText: String?, conversationHistory: [ChatMessage]) async throws -> AsyncStream<StreamingTurn>
}

struct StreamingTurn {
    let partialText: String
    let isComplete: Bool
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
        }
        
        self.session = LanguageModelSession(instructions: instructions)
    }
    
    func prewarm() async {
        session.prewarm()
    }
    
    func openingMessage(schema: DataSchema) async -> ChatMessage {
        guard let firstQuestion = schema.byId[schema.intro.firstQuestionId] else {
            return ChatMessage(role: .model, text: "Let's get started.")
        }
        return ChatMessage(role: .model, text: firstQuestion.prompt)
    }
    
    func streamOpeningMessage(schema: DataSchema) async throws -> AsyncStream<StreamingTurn> {
        let questionId = schema.intro.firstQuestionId
        guard let firstQuestion = schema.byId[questionId] else {
            return fallbackStream(
                text: "Let's get started.",
                mappedAnswer: nil,
                nextQuestionId: questionId
            )
        }
        
        let prompt = Prompt {
            "Generate a warm opening message for a hair loss consultation."
            "The first question will be about: \(firstQuestion.prompt)"
            "Keep the opening brief, friendly, and professional. Then ask the first question naturally."
        }
        
        return createStream(
            prompt: prompt,
            mappedAnswer: nil,
            nextQuestionId: questionId,
            fallbackText: firstQuestion.prompt
        )
    }
    
    
    func streamNextTurn(for question: Question, userText: String?, conversationHistory: [ChatMessage]) async throws -> AsyncStream<StreamingTurn> {
        guard let text = userText else {
            return fallbackStream(
                text: question.prompt,
                mappedAnswer: nil,
                nextQuestionId: question.next?.default
            )
        }
        
        let mapped = mapAnswer(from: text, for: question)
        let nextId = question.next?.default
        
        // Check if consultation is complete
        if nextId == "consultation_end" || nextId == nil {
            let prompt = Prompt {
                "The patient has completed the consultation."
                "Generate a brief, warm closing message and let the patient know the consultation information is on the next screen."
            }
            return createStream(
                prompt: prompt,
                mappedAnswer: mapped,
                nextQuestionId: nextId,
                fallbackText: "Thank you for your time."
            )
        }
        
        guard let nextQuestionId = nextId, let nextQuestion = schema.byId[nextQuestionId] else {
            return fallbackStream(
                text: "Thank you for sharing that information.",
                mappedAnswer: mapped,
                nextQuestionId: nil
            )
        }
        
        // Generate transition to next question
        let prompt = Prompt {
            "Previous question: \(question.prompt)"
            "Patient's answer: \(text)"
            "Next question topic: \(nextQuestion.prompt)"
//            if let options = nextQuestion.options, !options.isEmpty {
//                "Available response options (do not list them in the response): \(options.map { $0.label }.joined(separator: ", "))"
//            }
            "Generate a brief acknowledgment of the patient's answer followed by the next question."
            "Keep the tone warm, professional, and conversational."
        }
        
        return createStream(
            prompt: prompt,
            mappedAnswer: mapped,
            nextQuestionId: nextQuestionId,
            fallbackText: nextQuestion.prompt
        )
    }
    
    // MARK: - Private Helpers
    
    private func mapAnswer(from text: String, for question: Question) -> MappedAnswer? {
        guard let key = question.key else { return nil }
        
        if let option = question.options?.first(where: {
            $0.label.caseInsensitiveCompare(text).rawValue == 0 || $0.id == text
        }) {
            return MappedAnswer(keyPath: key, valueId: option.id)
        } else if question.type == .free_text {
            return MappedAnswer(keyPath: key, valueId: text)
        }
        
        return nil
    }
    
    private func createStream(
        prompt: Prompt,
        mappedAnswer: MappedAnswer?,
        nextQuestionId: String?,
        fallbackText: String
    ) -> AsyncStream<StreamingTurn> {
        AsyncStream { continuation in
            Task {
                let stream = session.streamResponse(to: prompt)
                do {
                    for try await snapshot in stream {
                        continuation.yield(StreamingTurn(
                            partialText: snapshot.content,
                            isComplete: false,
                            mappedAnswer: mappedAnswer,
                            nextQuestionId: nextQuestionId
                        ))
                    }
                    continuation.yield(StreamingTurn(
                        partialText: "",
                        isComplete: true,
                        mappedAnswer: mappedAnswer,
                        nextQuestionId: nextQuestionId
                    ))
                } catch {
                    continuation.yield(StreamingTurn(
                        partialText: fallbackText,
                        isComplete: true,
                        mappedAnswer: mappedAnswer,
                        nextQuestionId: nextQuestionId
                    ))
                }
                continuation.finish()
            }
        }
    }
    
    private func fallbackStream(
        text: String,
        mappedAnswer: MappedAnswer?,
        nextQuestionId: String?
    ) -> AsyncStream<StreamingTurn> {
        AsyncStream { continuation in
            continuation.yield(StreamingTurn(
                partialText: text,
                isComplete: true,
                mappedAnswer: mappedAnswer,
                nextQuestionId: nextQuestionId
            ))
            continuation.finish()
        }
    }
}
