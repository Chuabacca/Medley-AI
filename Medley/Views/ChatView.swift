import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showResults = false
    
    private var isModelStreaming: Bool {
        viewModel.messages.last?.isStreaming ?? false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundWarm
                    .ignoresSafeArea()
                
                ZStack(alignment: .bottom) {
                    messagesScrollView
                    
                    VStack(spacing: 0) {
                        responseChipsView
                        bottomControlView
                    }
                }
            }
            .navigationTitle("Consultation")
            .toolbar { toolbar }
            .onAppear {
                viewModel.start()
            }
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
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    private var messagesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.messages) { message in
                MessageRow(message: message)
                    .id(message.id)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, bottomContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var bottomContentPadding: CGFloat {
        if viewModel.isComplete {
            return 80  // Next button height
        }
        return (!viewModel.predefinedResponses.isEmpty && !isModelStreaming) ? 120 : 40
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        // Use a small delay to ensure layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.4)) {
                proxy.scrollTo(lastMessage.id, anchor: .top)
            }
        }
    }
    
    private var responseChipsView: some View {
        Group {
            if !viewModel.predefinedResponses.isEmpty && !isModelStreaming {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.predefinedResponses, id: \.self) { response in
                            responseChip(response)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isModelStreaming)
    }
    
    private func responseChip(_ text: String) -> some View {
        Button(text) {
            send(text)
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.brandPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 0)
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandDark)
                .frame(maxWidth: 250)
                .padding(.vertical, 10)
                .backgroundStyle(Color.black)
                .clipShape(Capsule())
        }
        .padding()
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Type a message", text: $inputText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 0)

            Button("Send") {
                send(inputText)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(sendButtonColor)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var sendButtonColor: Color {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Color.gray.opacity(0.5)
            : Color.brandPrimary
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
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ChatView()
}
