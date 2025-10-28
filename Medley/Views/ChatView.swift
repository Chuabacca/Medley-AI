import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundWarm
                    .ignoresSafeArea()
                
                VStack(spacing: 8) {
                    messagesScrollView
                    responseChipsView
                    bottomControlView
                }
            }
            .navigationTitle("Consultation")
            .toolbar { toolbar }
            .onAppear { viewModel.start() }
            .sheet(isPresented: $showResults) {
                ResultsView(data: viewModel.data)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Reset") {
                viewModel.start()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesContent
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private var messagesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.messages) { message in
                MessageRow(message: message)
                    .id(message.id)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    private var responseChipsView: some View {
        Group {
            if !viewModel.predefinedResponses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.predefinedResponses, id: \.self) { response in
                            responseChip(response)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func responseChip(_ text: String) -> some View {
        Button(text) {
            send(text)
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.brandPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var bottomControlView: some View {
        if viewModel.isComplete {
            nextButton
        } else {
            inputBar
        }
    }
    
    private var nextButton: some View {
        Button {
            showResults = true
        } label: {
            Text("Next")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brandDark)
                .clipShape(Capsule())
        }
        .padding()
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Type a message", text: $inputText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
            
            Button("Send") {
                send(inputText)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.send(text: trimmed)
        inputText = ""
    }
}

// MARK: - MessageRow

struct MessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            messageContent
                .padding(12)
                .padding(.leading, message.role == .user ? 18 : 12)
                .padding(.trailing, message.role == .model ? 18 : 12)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(bubbleShape)
            
            if message.role == .model {
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.5), value: message.text)
    }
    
    @ViewBuilder
    private var messageContent: some View {
        if message.text.isEmpty && message.isStreaming {
            TypingIndicator()
        } else {
            Text(message.text)
        }
    }
    
    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: message.role == .model ? 0 : 18,
            bottomTrailingRadius: message.role == .user ? 0 : 18,
            topTrailingRadius: 18
        )
    }
    
    private var backgroundColor: Color {
        message.role == .user ? .brandDark : .white
    }
    
    private var foregroundColor: Color {
        message.role == .user ? .white : .black
    }
}

// MARK: - TypingIndicator

struct TypingIndicator: View {
    @State private var animatingDots = [false, false, false]
    
    private let dotCount = 3
    private let dotSize: CGFloat = 8
    private let animationDuration: Double = 0.6
    private let animationDelay: Double = 0.2
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                dot(at: index)
            }
        }
        .onAppear {
            animatingDots = Array(repeating: true, count: dotCount)
        }
    }
    
    private func dot(at index: Int) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.6))
            .frame(width: dotSize, height: dotSize)
            .scaleEffect(animatingDots[index] ? 1.0 : 0.6)
            .animation(
                .easeInOut(duration: animationDuration)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * animationDelay),
                value: animatingDots[index]
            )
    }
}

#Preview {
    ChatView()
}
