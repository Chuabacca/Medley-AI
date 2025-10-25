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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(vm.messages) { msg in
                    MessageRow(message: msg)
                }
            }.padding(.horizontal)
        }
    }
    
    private var responseChipsView: some View {
        Group {
            if !vm.predefinedResponses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.predefinedResponses, id: \.self) { chip in
                            Button(chip) { send(chip) }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
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
                .background(Color.black)
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
            Text(message.text)
                .padding(12)
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
    }
    
    private var backgroundColor: Color {
        message.role == .user ? Color.black : Color(.systemGray6)
    }
    
    private var foregroundColor: Color {
        message.role == .user ? .white : .black
    }
}

#Preview {
    ChatView()
}
