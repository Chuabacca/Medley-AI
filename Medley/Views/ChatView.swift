import SwiftUI

struct ChatView: View {
    @State private var vm = ChatViewModel()
    @State private var text: String = ""
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                messagesScrollView
                responseChipsView
                bottomControlView
            }
            .background(Color.backgroundWarm)
            .navigationTitle("Consultation")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { vm.start() }
                }
            }
            .onAppear { vm.start() }
            .sheet(isPresented: $showResults) {
                ResultsView(data: vm.data)
            }
        }
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(vm.messages) { msg in
                        MessageRow(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: vm.messages.count) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: vm.messages.last?.text) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = vm.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private var responseChipsView: some View {
        Group {
            if !vm.predefinedResponses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.predefinedResponses, id: \.self) { chip in
                            Button(chip) { send(chip) }
                                .font(.system(size: 16))
                                .foregroundStyle(Color.brandPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
                        }
                    }.padding(.horizontal)
                }
            }
        }
    }
    
    @ViewBuilder
    private var bottomControlView: some View {
        if vm.isComplete {
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
        HStack {
            TextField("Type a message", text: $text)
                .textFieldStyle(.roundedBorder)
            Button("Send") { send(text) }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.padding()
    }

    private func send(_ s: String) {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        vm.send(text: trimmed)
        text = ""
    }
}

struct MessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            Group {
                if message.text.isEmpty && message.isStreaming {
                    TypingIndicator()
                } else {
                    Text(message.text)
                }
            }
            .padding(12)
            .padding(.leading, message.role == .user ? 18 : 12)
            .padding(.trailing, message.role == .model ? 18 : 12)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: message.role == .model ? 0 : 18,
                bottomTrailingRadius: message.role == .user ? 0 : 18,
                topTrailingRadius: 18
            ))
            if message.role == .model { Spacer() }
        }
        .animation(.easeInOut(duration: 0.2), value: message.text)
    }
    
    private var backgroundColor: Color {
        message.role == .user ? Color.brandDark : Color.white
    }
    
    private var foregroundColor: Color {
        message.role == .user ? .white : .black
    }
}

struct TypingIndicator: View {
    @State private var animatingDots = [false, false, false]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDots[index] ? 1.0 : 0.6)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animatingDots[index]
                    )
            }
        }
        .onAppear {
            for index in 0..<3 {
                animatingDots[index] = true
            }
        }
    }
}

#Preview {
    ChatView()
}
