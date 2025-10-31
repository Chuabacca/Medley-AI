import FoundationModels
import Foundation

protocol ConversationModel {
    func openingMessage(schema: DataSchema) async -> ChatMessage
    func streamOpeningMessage(schema: DataSchema) async throws -> AsyncStream<StreamingTurn>
    func streamNextTurn(for question: Question, userText: String?, conversationHistory: [ChatMessage]) async throws -> AsyncStream<StreamingTurn>
    func streamInfoSummary(info: String) async throws -> AsyncStream<StreamingTurn>
    func streamQuestion(for question: Question) async throws -> AsyncStream<StreamingTurn>
}

struct StreamingTurn {
    let partialText: String
    let isComplete: Bool
    let mappedAnswer: MappedAnswer?
    let nextQuestionId: String?
    let nextQuestionInfo: String?
}

/// FoundationModels-powered conversation model with dynamic response generation
final class FoundationModelsConversationModel: ConversationModel {
    private var session: LanguageModelSession
    private let schema: DataSchema
    
    init(schema: DataSchema) {
        self.schema = schema
        
        let instructions = Instructions {
            "You are the first point of contact for users coming to Hims for their healthcare needs."
            "You are an experienced, empathetic medical professional conducting a hair loss consultation."
            "Your role is to guide the patient through a series of questions with a warm bedside manner."
            "For each question, provide a conversational, professional prompt based on the question context."
            "When the user answers, acknowledge their response naturally before moving to the next question."
            "Keep responses concise, supportive, and medically appropriate."
            "NEVER start responses with phrases like 'Sure!', 'Absolutely!', 'Of course!', 'Great!', or other overly enthusiastic interjections."
            "Begin directly with substantive content in a calm, professional tone."
        }
        
        self.session = LanguageModelSession(instructions: instructions)
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
            "You represent Hims. You do not have a name."
            "Generate a warm opening message for a hair loss consultation."
            "The first question will be about: \(firstQuestion.prompt)"
            "Keep the opening brief, friendly, and professional. Then ask the first question naturally."
            "Do not use phrases like 'Sure!', 'Absolutely!', or other casual interjections. Start directly with your message."
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
        
        let mapped = await mapAnswer(from: text, for: question)
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
        
        // If next question has info, only generate acknowledgment
        // Otherwise, generate acknowledgment + next question together
        let prompt: Prompt
        if let info = nextQuestion.info, !info.isEmpty {
            prompt = Prompt {
                "Previous question: \(question.prompt)"
                "Patient's answer: \(text)"
                "Generate a warm acknowledgment of the patient's answer."
                "Do NOT ask a question."
                "Do not start with 'Sure!', 'Absolutely!', 'Great!', or similar phrases. Begin naturally."
            }
        } else {
            prompt = Prompt {
                "Previous question: \(question.prompt)"
                "Patient's answer: \(text)"
                "Next question topic: \(nextQuestion.prompt)"
                "Generate a brief acknowledgment of the patient's answer followed by the next question."
                "Keep the tone warm, professional, and conversational."
                "Do not start with 'Sure!', 'Absolutely!', 'Great!', or similar phrases. Begin naturally."
            }
        }
        
        return createStream(
            prompt: prompt,
            mappedAnswer: mapped,
            nextQuestionId: nextQuestionId,
            nextQuestionInfo: nextQuestion.info,
            fallbackText: "Thank you for sharing that."
        )
    }
    
    func streamInfoSummary(info: String) async throws -> AsyncStream<StreamingTurn> {
        let prompt = Prompt {
            "Summarize the following information in a warm and friendly tone:"
            info
            "Keep it brief and conversational."
        }
        
        return createStream(
            prompt: prompt,
            mappedAnswer: nil,
            nextQuestionId: nil,
            nextQuestionInfo: nil,
            fallbackText: info
        )
    }
    
    func streamQuestion(for question: Question) async throws -> AsyncStream<StreamingTurn> {
        let prompt = Prompt {
            "Next question topic: \(question.prompt)"
            "Generate a brief question for the next topic."
            "Keep the tone warm, professional, and conversational."
            "Do not start with 'Sure!', 'Absolutely!', or similar phrases. Begin directly with the question."
        }
        
        return createStream(
            prompt: prompt,
            mappedAnswer: nil,
            nextQuestionId: nil,
            nextQuestionInfo: nil,
            fallbackText: question.prompt
        )
    }
    
    // MARK: - Private Helpers
    
    private func mapAnswer(from text: String, for question: Question) async -> MappedAnswer? {
        // First, try exact match with option label or id
        if let option = question.options?.first(where: {
            $0.label.caseInsensitiveCompare(text).rawValue == 0 || $0.id == text
        }) {
            return MappedAnswer(keyPath: question.id, valueId: option.id)
        }
        
        // For free text questions, save the user's exact response
        if question.type == .free_text {
            return MappedAnswer(keyPath: question.id, valueId: text)
        }
        
        // For questions with predefined options, use LLM to categorize open-ended response
        if let options = question.options, !options.isEmpty {
            do {
                let categorizedOption = try await categorizeResponse(
                    userResponse: text,
                    question: question.prompt,
                    questionType: question.type,
                    options: options
                )
                return MappedAnswer(keyPath: question.id, valueId: categorizedOption)
            } catch {
                print("Error categorizing response: \(error)")
                // Fallback: use first option if categorization fails
                if let firstOption = options.first {
                    return MappedAnswer(keyPath: question.id, valueId: firstOption.id)
                }
            }
        }
        
        return nil
    }
    
    private func categorizeResponse(
        userResponse: String,
        question: String,
        questionType: QuestionType,
        options: [Option]
    ) async throws -> String {
        let optionIds = options.map { $0.id }.joined(separator: ", ")
        let optionsList = options.map { "- \($0.id): \($0.label)" }.joined(separator: "\n")
        
        let prompt = Prompt {
            "Question: \(question)"
            "User's response: \(userResponse)"
            "Available response options:"
            optionsList
            "Based on the user's response, return \(questionType == .multiple_choice ? "one or more" : "exactly one") of the following option IDs:"
            optionIds
        }
        
        var response = try await session.respond(to: prompt)
        let categoryId = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate the category ID exists
        if options.contains(where: { $0.id == categoryId }) {
            return categoryId
        }
        
        // If invalid, try to find a match in the response
        for option in options {
            if categoryId.contains(option.id) {
                return option.id
            }
        }
        
        // Fallback to first option
        return options.first?.id ?? ""
    }
    
    private func createStream(
        prompt: Prompt,
        mappedAnswer: MappedAnswer?,
        nextQuestionId: String?,
        nextQuestionInfo: String? = "",
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
                            nextQuestionId: nextQuestionId,
                            nextQuestionInfo: nextQuestionInfo
                        ))
                    }
                    continuation.yield(StreamingTurn(
                        partialText: "",
                        isComplete: true,
                        mappedAnswer: mappedAnswer,
                        nextQuestionId: nextQuestionId,
                        nextQuestionInfo: nextQuestionInfo
                    ))
                } catch {
                    continuation.yield(StreamingTurn(
                        partialText: fallbackText,
                        isComplete: true,
                        mappedAnswer: mappedAnswer,
                        nextQuestionId: nextQuestionId,
                        nextQuestionInfo: nextQuestionInfo
                    ))
                }
                continuation.finish()
            }
        }
    }
    
    private func fallbackStream(
        text: String,
        mappedAnswer: MappedAnswer?,
        nextQuestionId: String?,
        nextQuestionInfo: String? = nil
    ) -> AsyncStream<StreamingTurn> {
        AsyncStream { continuation in
            continuation.yield(StreamingTurn(
                partialText: text,
                isComplete: true,
                mappedAnswer: mappedAnswer,
                nextQuestionId: nextQuestionId,
                nextQuestionInfo: nextQuestionInfo
            ))
            continuation.finish()
        }
    }
}
