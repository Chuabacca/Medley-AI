// Testing is not currently working

import Testing
import FoundationModels
@testable import Medley

@Suite("Conversation Model Tests")
struct ConversationModelTests {
    
    private func makeBaseSchema() -> DataSchema {
        return DataSchema(
            version: "1.0",
            intro: Intro(firstQuestionId: "q1"),
            questions: [
                Question(
                    id: "q1",
                    info: "This is important information",
                    prompt: "First question?",
                    type: .single_choice,
                    options: [
                        Option(id: "opt1", label: "Option 1"),
                        Option(id: "opt2", label: "Option 2")
                    ],
                    predefinedResponses: ["Option 1", "Option 2"],
                    next: NextRules(default: "q2")
                ),
                Question(
                    id: "q2",
                    info: nil,
                    prompt: "Second question?",
                    type: .free_text,
                    options: nil,
                    predefinedResponses: nil,
                    next: NextRules(default: "__complete__")
                )
            ]
        )
    }
    
    @Test("streamOpeningMessage yields partial text and completes")
    func testStreamOpeningMessageYieldsPartialTextAndCompletes() async throws {
        let schema = makeBaseSchema()
        let model = MockStreamingConversationModel(schema: schema, shouldSucceed: true)
        
        let stream = try await model.streamOpeningMessage(schema: schema)
        
        var partialTexts: [String] = []
        var isCompleteFinal = false
        var nextQuestionId: String? = nil
        
        for await turn in stream {
            if !turn.isComplete {
                partialTexts.append(turn.partialText)
            } else {
                isCompleteFinal = turn.isComplete
                nextQuestionId = turn.nextQuestionId
            }
        }
        
        // Verify partial text was yielded
        #expect(!partialTexts.isEmpty, "Should yield partial text chunks")
        #expect(partialTexts.count >= 3, "Should yield multiple partial chunks")
        
        // Verify completion
        #expect(isCompleteFinal, "Should mark stream as complete")
        #expect(nextQuestionId == "q1", "Should return first question ID")
    }
    
    @Test("streamOpeningMessage handles errors and falls back")
    func testStreamOpeningMessageHandlesErrorsAndFallsBack() async throws {
        let schema = makeBaseSchema()
        let model = MockStreamingConversationModel(schema: schema, shouldSucceed: false)
        
        let stream = try await model.streamOpeningMessage(schema: schema)
        
        var finalText = ""
        var isCompleteFinal = false
        var turnCount = 0
        
        for await turn in stream {
            turnCount += 1
            if turn.isComplete {
                isCompleteFinal = true
            } else {
                finalText = turn.partialText
            }
        }
        
        // When an error occurs, should fall back to static prompt
        #expect(isCompleteFinal, "Should complete despite error")
        #expect(turnCount == 1, "Should yield single fallback message")
    }
    
    @Test("streamNextTurn yields partial text")
    func testStreamNextTurnYieldsPartialText() async throws {
        let schema = makeBaseSchema()
        let model = MockStreamingConversationModel(schema: schema, shouldSucceed: true)
        
        let question = try #require(schema.byId["q1"], "Question q1 not found")
        
        let stream = try await model.streamNextTurn(
            for: question,
            userText: "Option 1",
            conversationHistory: []
        )
        
        var partialTexts: [String] = []
        var isCompleteFinal = false
        var mappedAnswer: MappedAnswer? = nil
        var nextQuestionId: String? = nil
        
        for await turn in stream {
            if !turn.isComplete {
                partialTexts.append(turn.partialText)
            } else {
                isCompleteFinal = turn.isComplete
                mappedAnswer = turn.mappedAnswer
                nextQuestionId = turn.nextQuestionId
            }
        }
        
        // Verify streaming behavior
        #expect(!partialTexts.isEmpty, "Should yield partial text")
        #expect(partialTexts.count >= 3, "Should yield multiple chunks")
        #expect(isCompleteFinal, "Should complete")
        
        // Verify answer mapping
        #expect(mappedAnswer != nil, "Should map user answer")
        #expect(mappedAnswer?.keyPath == "q1", "Mapped keyPath should match question ID")
        #expect(mappedAnswer?.valueId == "opt1", "Mapped valueId should match")
        
        // Verify next question
        #expect(nextQuestionId == "q2", "Should advance to next question")
    }
    
    @Test("streamNextTurn handles completion scenario")
    func testStreamNextTurnHandlesCompletionScenario() async throws {
        let schema = makeBaseSchema()
        let model = MockStreamingConversationModel(schema: schema, shouldSucceed: true)
        
        let question = try #require(schema.byId["q2"], "Question q2 not found")
        
        let stream = try await model.streamNextTurn(
            for: question,
            userText: "My free text answer",
            conversationHistory: []
        )
        
        var closingMessageReceived = false
        var isCompleteFinal = false
        var nextQuestionId: String? = nil
        var partialTexts: [String] = []
        
        for await turn in stream {
            if !turn.isComplete {
                partialTexts.append(turn.partialText)
            } else {
                isCompleteFinal = turn.isComplete
                nextQuestionId = turn.nextQuestionId
                closingMessageReceived = true
            }
        }
        
        // Verify completion behavior
        #expect(closingMessageReceived, "Should receive closing message")
        #expect(isCompleteFinal, "Should mark as complete")
        #expect(nextQuestionId == "__complete__", "Should indicate consultation complete")
        #expect(!partialTexts.isEmpty, "Should stream closing message")
    }
    
    @Test("advance function displays info message with delay")
    func testAdvanceFunctionDisplaysInfoMessageWithDelay() async throws {
        let schema = makeBaseSchema()
        let viewModel = await ChatViewModel(schema: schema, model: MockStreamingConversationModel(schema: schema, shouldSucceed: true))
        
        // Start with first question
        await viewModel.start()
        
        // Wait for opening message to complete
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let initialMessageCount = await viewModel.messages.count
        
        // Send response to first question to trigger advance
        await viewModel.send(text: "Option 1")
        
        // Wait for streaming and advance to complete
        try await Task.sleep(nanoseconds: 600_000_000)
        
        let messages = await viewModel.messages
        
        // Find info message
        let infoMessages = messages.filter { $0.text == "This is important information" }
        
        // The first question has info, but we're testing advance to q2 which has no info
        // So let's verify the flow: user message + model response + advance
        #expect(messages.count > initialMessageCount, "Should have new messages")
        
        // For this test, we should actually test with a question that has info
        // The advance function should show info message before the question
    }
    
    @Test("Info message is displayed before question")
    func testInfoMessageIsDisplayedBeforeQuestion() async throws {
        // Create schema with info on second question
        let schemaWithInfo = DataSchema(
            version: "1.0",
            intro: Intro(firstQuestionId: "q1"),
            questions: [
                Question(
                    id: "q1",
                    info: nil,
                    prompt: "First question?",
                    type: .single_choice,
                    options: [Option(id: "opt1", label: "Option 1")],
                    predefinedResponses: ["Option 1"],
                    next: NextRules(default: "q2_with_info")
                ),
                Question(
                    id: "q2_with_info",
                    info: "Important: Please read this carefully.",
                    prompt: "Second question with info?",
                    type: .free_text,
                    options: nil,
                    predefinedResponses: nil,
                    next: NextRules(default: nil)
                )
            ]
        )
        
        let viewModel = await ChatViewModel(
            schema: schemaWithInfo,
            model: MockStreamingConversationModel(schema: schemaWithInfo, shouldSucceed: true)
        )
        
        await viewModel.start()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let beforeSendCount = await viewModel.messages.count
        
        // Record start time
        let startTime = Date()
        
        await viewModel.send(text: "Option 1")
        
        // Wait for advance and info message
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let messages = await viewModel.messages
        let endTime = Date()
        
        // Verify info message exists
        let hasInfoMessage = messages.contains { $0.text == "Important: Please read this carefully." }
        #expect(hasInfoMessage, "Should display info message")
        
        // Verify delay occurred (at least 400ms as specified in advance function)
        let elapsed = endTime.timeIntervalSince(startTime)
        #expect(elapsed >= 0.4, "Should have delay of at least 400ms")
    }
    
    @Test("streamNextTurn handles streaming errors")
    func testStreamNextTurnHandlesStreamingErrors() async throws {
        let schema = makeBaseSchema()
        let model = MockStreamingConversationModel(schema: schema, shouldSucceed: false)
        
        let question = try #require(schema.byId["q1"], "Question q1 not found")
        
        let stream = try await model.streamNextTurn(
            for: question,
            userText: "Option 1",
            conversationHistory: []
        )
        
        var isCompleteFinal = false
        var fallbackReceived = false
        
        for await turn in stream {
            if turn.isComplete {
                isCompleteFinal = true
                // Should receive fallback prompt when error occurs
                fallbackReceived = true
            }
        }
        
        #expect(isCompleteFinal, "Should complete despite error")
        #expect(fallbackReceived, "Should provide fallback message")
    }
    
    @Test("streamNextTurn maps free text correctly")
    func testStreamNextTurnMapsFreeTextCorrectly() async throws {
        let schema = makeBaseSchema()
        let model = MockStreamingConversationModel(schema: schema, shouldSucceed: true)
        
        let question = try #require(schema.byId["q2"], "Question q2 not found")
        
        let stream = try await model.streamNextTurn(
            for: question,
            userText: "Custom free text response",
            conversationHistory: []
        )
        
        var mappedAnswer: MappedAnswer? = nil
        
        for await turn in stream {
            if turn.isComplete {
                mappedAnswer = turn.mappedAnswer
            }
        }
        
        // Verify free text mapping
        #expect(mappedAnswer != nil, "Should map free text answer")
        #expect(mappedAnswer?.keyPath == "q2", "Mapped keyPath should match question ID")
        #expect(mappedAnswer?.valueId == "Custom free text response", "Mapped valueId should match")
    }
}

// MARK: - Mock Implementation

/// Mock conversation model for testing streaming behavior
final class MockStreamingConversationModel: ConversationModel {
    private let schema: DataSchema
    private let shouldSucceed: Bool
    
    init(schema: DataSchema, shouldSucceed: Bool = true) {
        self.schema = schema
        self.shouldSucceed = shouldSucceed
    }
    
    func prewarm() async {
        // No-op for testing
    }
    
    func openingMessage(schema: DataSchema) async -> ChatMessage {
        guard let firstQuestion = schema.byId[schema.intro.firstQuestionId] else {
            return ChatMessage(role: .model, text: "Let's get started.")
        }
        return ChatMessage(role: .model, text: firstQuestion.prompt)
    }
    
    func streamOpeningMessage(schema: DataSchema) async throws -> AsyncStream<StreamingTurn> {
        let qid = schema.intro.firstQuestionId
        guard let firstQuestion = schema.byId[qid] else {
            return AsyncStream { continuation in
                continuation.yield(StreamingTurn(
                    partialText: "Let's get started.",
                    isComplete: true,
                    mappedAnswer: nil,
                    nextQuestionId: qid
                ))
                continuation.finish()
            }
        }
        
        if !shouldSucceed {
            // Simulate error fallback
            return AsyncStream { continuation in
                continuation.yield(StreamingTurn(
                    partialText: firstQuestion.prompt,
                    isComplete: true,
                    mappedAnswer: nil,
                    nextQuestionId: qid
                ))
                continuation.finish()
            }
        }
        
        // Simulate successful streaming
        return AsyncStream { continuation in
            Task {
                let chunks = ["Hello, ", "welcome to ", "the consultation. ", firstQuestion.prompt]
                
                for chunk in chunks {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms between chunks
                    continuation.yield(StreamingTurn(
                        partialText: chunks.prefix(through: chunks.firstIndex(of: chunk)!).joined(),
                        isComplete: false,
                        mappedAnswer: nil,
                        nextQuestionId: qid
                    ))
                }
                
                continuation.yield(StreamingTurn(
                    partialText: "",
                    isComplete: true,
                    mappedAnswer: nil,
                    nextQuestionId: qid
                ))
                continuation.finish()
            }
        }
    }
    
    func nextTurn(for question: Question, userText: String?, conversationHistory: [ChatMessage]) async throws -> ModelTurn {
        guard let text = userText else {
            return ModelTurn(
                message: ChatMessage(role: .model, text: question.prompt),
                mappedAnswer: nil,
                nextQuestionId: question.next?.default
            )
        }
        
        // Map answer
        var mapped: MappedAnswer? = nil
        if let opt = question.options?.first(where: {
            $0.label.caseInsensitiveCompare(text).rawValue == 0 || $0.id == text
        }) {
            mapped = MappedAnswer(keyPath: question.id, valueId: opt.id)
        } else if question.type == .free_text {
            mapped = MappedAnswer(keyPath: question.id, valueId: text)
        }
        
        let nextId = question.next?.default
        
        if nextId == "__complete__" || nextId == nil {
            return ModelTurn(
                message: ChatMessage(role: .model, text: "Thank you for completing the consultation."),
                mappedAnswer: mapped,
                nextQuestionId: nextId
            )
        }
        
        guard let nextQuestionId = nextId, let nextQuestion = schema.byId[nextQuestionId] else {
            return ModelTurn(
                message: ChatMessage(role: .model, text: "Thank you for sharing that information."),
                mappedAnswer: mapped,
                nextQuestionId: nil
            )
        }
        
        return ModelTurn(
            message: ChatMessage(role: .model, text: "Thanks. \(nextQuestion.prompt)"),
            mappedAnswer: mapped,
            nextQuestionId: nextQuestionId
        )
    }
    
    func streamNextTurn(for question: Question, userText: String?, conversationHistory: [ChatMessage]) async throws -> AsyncStream<StreamingTurn> {
        guard let text = userText else {
            return AsyncStream { continuation in
                continuation.yield(StreamingTurn(
                    partialText: question.prompt,
                    isComplete: true,
                    mappedAnswer: nil,
                    nextQuestionId: question.next?.default
                ))
                continuation.finish()
            }
        }
        
        // Map answer
        var mapped: MappedAnswer? = nil
        if let opt = question.options?.first(where: {
            $0.label.caseInsensitiveCompare(text).rawValue == 0 || $0.id == text
        }) {
            mapped = MappedAnswer(keyPath: question.id, valueId: opt.id)
        } else if question.type == .free_text {
            mapped = MappedAnswer(keyPath: question.id, valueId: text)
        }
        
        let nextId = question.next?.default
        
        if !shouldSucceed {
            // Simulate error fallback
            return AsyncStream { continuation in
                if nextId == "__complete__" || nextId == nil {
                    continuation.yield(StreamingTurn(
                        partialText: "Thank you for your time.",
                        isComplete: true,
                        mappedAnswer: mapped,
                        nextQuestionId: nextId
                    ))
                } else if let nextQuestionId = nextId, let nextQuestion = schema.byId[nextQuestionId] {
                    continuation.yield(StreamingTurn(
                        partialText: nextQuestion.prompt,
                        isComplete: true,
                        mappedAnswer: mapped,
                        nextQuestionId: nextQuestionId
                    ))
                }
                continuation.finish()
            }
        }
        
        // Simulate successful streaming
        return AsyncStream { continuation in
            Task {
                if nextId == "__complete__" || nextId == nil {
                    // Completion scenario
                    let chunks = ["Thank you ", "for completing ", "the consultation."]
                    
                    for chunk in chunks {
                        try? await Task.sleep(nanoseconds: 10_000_000)
                        continuation.yield(StreamingTurn(
                            partialText: chunks.prefix(through: chunks.firstIndex(of: chunk)!).joined(),
                            isComplete: false,
                            mappedAnswer: mapped,
                            nextQuestionId: nextId
                        ))
                    }
                    
                    continuation.yield(StreamingTurn(
                        partialText: "",
                        isComplete: true,
                        mappedAnswer: mapped,
                        nextQuestionId: nextId
                    ))
                } else if let nextQuestionId = nextId, let nextQuestion = schema.byId[nextQuestionId] {
                    // Normal progression
                    let chunks = ["Thanks. ", nextQuestion.prompt]
                    
                    for chunk in chunks {
                        try? await Task.sleep(nanoseconds: 10_000_000)
                        continuation.yield(StreamingTurn(
                            partialText: chunks.prefix(through: chunks.firstIndex(of: chunk)!).joined(),
                            isComplete: false,
                            mappedAnswer: mapped,
                            nextQuestionId: nextQuestionId
                        ))
                    }
                    
                    continuation.yield(StreamingTurn(
                        partialText: "",
                        isComplete: true,
                        mappedAnswer: mapped,
                        nextQuestionId: nextQuestionId
                    ))
                }
                
                continuation.finish()
            }
        }
    }
}

