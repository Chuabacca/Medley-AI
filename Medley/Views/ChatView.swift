import SwiftUI

struct ChatView: View {
    @State private var vm = ChatViewModel()
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { msg in
                            HStack {
                                if msg.role == .user { Spacer() }
                                Text(msg.text)
                                    .padding(12)
                                    .background(msg.role == .user ? Color.black : Color(.systemGray6))
                                    .foregroundStyle(msg.role == .user ? .white : .black)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                if msg.role == .model { Spacer() }
                            }
                        }
                    }.padding(.horizontal)
                }
                // Predefined response chips
                if !vm.predefinedResponses.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.predefinedResponses, id: \.self) { chip in
                                Button(chip) { send(chip) }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                        }.padding(.horizontal)
                    }
                }
                // Input bar
                HStack {
                    TextField("Type a message", text: $text)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") { send(text) }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding()
            }
            .navigationTitle("Consultation")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { vm.start() }
                }
            }
            .onAppear { vm.start() }
        }
    }

    private func send(_ s: String) {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        vm.send(text: trimmed)
        text = ""
    }
}

#Preview {
    ChatView()
}
