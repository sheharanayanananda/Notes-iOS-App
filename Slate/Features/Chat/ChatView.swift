//
//  ChatView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-20.
//

import SwiftUI

struct ChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Binding var activeTab: ContentView.TabIdentifier
    
    @State private var chatText = ""
    
    @State private var thinkingLevel: String = "Off"
    @State private var creativity: Double = 0.3
    @State private var memorySize: MemoryLimit = .standard
    
    // Persisted storage — only written to, never read for UI rendering
    @AppStorage("active_chat_preset") private var storedPreset: ChatPreset = .slateFlash
    // State-driven — drives the UI instantly without SwiftUI animation transactions
    @State private var displayedPreset: ChatPreset = .slateFlash

    @State private var messages: [OllamaChatMessage] = []
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @FocusState private var isInputFocused: Bool
    @State private var newlyGeneratedMessageId: String? = nil
    @State private var isTextFieldDisabled = false
    @State private var scrollTask: Task<Void, Never>? = nil
    @State private var hasAppeared = false

    
    var body: some View {
        Group {
            if messages.isEmpty {
                ZStack {
                    VStack(spacing: 10) {
                        Spacer()
                        
                        Image(systemName: "apple.intelligence")
                            .font(.system(size: 55))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 10) {
                            Text("Slate Agent")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("New Conversation")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -40)
                    
                    VStack {
                        Spacer()
                        ChatCapsule(
                            text: $chatText,
                            isGenerating: isGenerating,
                            isTextFieldDisabled: isTextFieldDisabled,
                            isInputFocused: $isInputFocused,
                            onSend: sendMessage
                        )
                            .padding(.bottom, 16)
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            VStack(spacing: 24) {
                                ForEach(messages) { message in
                                    if message.role == "assistant" && message.content.isEmpty && isGenerating {
                                        ChatLoadingBubbleView()
                                            .id("loading")
                                            .transition(.opacity.animation(.easeOut(duration: 0.1)))
                                    } else {
                                        ChatBubbleView(message: message, isNew: message.id == newlyGeneratedMessageId) {
                                            self.scrollToBottom(proxy: proxy, delay: 0.0, animate: true)
                                        }
                                    }
                                }
                                
                                if let errorMessage = errorMessage {
                                    ChatErrorBubbleView(message: errorMessage)
                                        .id("error")
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            
                            Color.clear
                                .frame(height: 1)
                                .id("bottomSpacer")
                        }
                    }
                    .defaultScrollAnchor(.bottom)
                    .safeAreaInset(edge: .bottom) {
                        ChatCapsule(
                            text: $chatText,
                            isGenerating: isGenerating,
                            isTextFieldDisabled: isTextFieldDisabled,
                            isInputFocused: $isInputFocused,
                            onSend: sendMessage
                        )
                            .padding(.bottom, 16)
                    }
                    .onChange(of: messages) {
                        if hasAppeared {
                            scrollToBottom(proxy: proxy, delay: 0.08)
                        }
                    }
                    .onChange(of: isGenerating) {
                        scrollToBottom(proxy: proxy, delay: 0.08)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                        scrollToBottom(proxy: proxy, delay: 0.05)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                        scrollToBottom(proxy: proxy, delay: 0.05)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                        scrollToBottom(proxy: proxy, delay: 0.05)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    activeTab = .notes
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarSpacer(placement: .cancellationAction)
            
            ToolbarItem(placement: .cancellationAction) {
                Menu {
                    Picker("Preset", selection: $displayedPreset) {
                        ForEach(ChatPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        // Fixed-width text: single-pass layout, nav bar never resizes,
                        // chevron always renders in the same frame as the text.
                        Text("\(Text("Slate ").font(.system(size: 17, weight: .semibold)))\(Text(displayedPreset.modelTierName).font(.system(size: 16, weight: .regular)))")
                            .foregroundColor(.primary)
                            .frame(alignment: .center)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: displayedPreset) {
                    selectPreset(displayedPreset)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    messages = []
                    saveMessages([])
                    errorMessage = nil
                    chatText = ""
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            messages = loadMessages()
            // Load persisted preset into @State on first appear
            displayedPreset = storedPreset
            applyPreset(storedPreset)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
    }
    
    /// Selects a preset instantly in UI state, persists without animation
    private func selectPreset(_ preset: ChatPreset) {
        // Update @State immediately — this is NOT wrapped in any animation transaction
        displayedPreset = preset
        applyPreset(preset)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        // Write to @AppStorage on next runloop tick to avoid triggering
        // SwiftUI's animated view-update pass during this layout cycle
        DispatchQueue.main.async {
            storedPreset = preset
        }
    }
    
    private func applyPreset(_ preset: ChatPreset) {
        creativity = preset.creativity
        memorySize = preset.memorySize
        thinkingLevel = preset.thinkingLevel
    }
    
    private func getFileURL() -> URL? {
        try? FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("active_chat.json")
    }
    
    private func saveMessages(_ msgs: [OllamaChatMessage]) {
        guard let url = getFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(msgs)
            try data.write(to: url)
        } catch {
            print("Failed to save chat: \(error)")
        }
    }
    
    private func loadMessages() -> [OllamaChatMessage] {
        guard let url = getFileURL(), FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([OllamaChatMessage].self, from: data)
        } catch {
            print("Failed to load chat: \(error)")
            return []
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, delay: Double = 0.0, animate: Bool = true) {
        scrollTask?.cancel()
        scrollTask = Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            if animate {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    proxy.scrollTo("bottomSpacer", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("bottomSpacer", anchor: .bottom)
            }
        }
    }
    
    private func sendMessage() {
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Resign focus first to trigger smooth keyboard dismissal transition
        isInputFocused = false
        
        // Clear input and update states with animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            chatText = ""
            errorMessage = nil
            newlyGeneratedMessageId = nil
            isGenerating = true
        }
        
        // Delay disabling the text field to allow keyboard dismissal animation to run fully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isTextFieldDisabled = true
            }
        }
        
        let userMessage = OllamaChatMessage(role: "user", content: trimmed)
        messages.append(userMessage)
        
        // Append an empty assistant message as a placeholder for streaming
        let assistantPlaceholder = OllamaChatMessage(role: "assistant", content: "")
        messages.append(assistantPlaceholder)
        saveMessages(messages)
        
        let sendGenerator = UIImpactFeedbackGenerator(style: .light)
        sendGenerator.impactOccurred()
        
        Task {
            do {
                let client = OllamaClient(modelName: "gemma4:31b")
                
                var messagesToSend = Array(messages.dropLast())
                let systemMsg = OllamaChatMessage(role: "system", content: displayedPreset.systemPrompt)
                messagesToSend.insert(systemMsg, at: 0)
                
                let finalMessage = try await client.chat(
                    messages: messagesToSend,
                    reasoningLevel: thinkingLevel,
                    creativity: creativity,
                    memorySize: memorySize.rawValue
                )
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        if let lastIndex = messages.indices.last {
                            messages[lastIndex] = finalMessage
                            newlyGeneratedMessageId = finalMessage.id
                        }
                        isGenerating = false
                        isTextFieldDisabled = false
                    }
                    saveMessages(messages)
                    
                    let replyGenerator = UIImpactFeedbackGenerator(style: .medium)
                    replyGenerator.impactOccurred()
                    
                    // Clear the newlyGeneratedMessageId after 3 seconds to prevent re-animation on scroll
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if newlyGeneratedMessageId == finalMessage.id {
                            newlyGeneratedMessageId = nil
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if messages.last?.role == "assistant" && messages.last?.content.isEmpty == true {
                        messages.removeLast()
                    }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        errorMessage = error.localizedDescription
                        isGenerating = false
                        isTextFieldDisabled = false
                    }
                    
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(activeTab: .constant(.notes))
    }
}




struct ChatBubbleView: View {
    let message: OllamaChatMessage
    var isNew: Bool = false
    var onBlockRevealed: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if message.role == "user" {
            HStack {
                Spacer()
                MessageView(content: message.content, isNew: false)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                MessageView(content: message.content, isNew: isNew, onBlockRevealed: onBlockRevealed)
                    .textSelection(.enabled)
                
                if !message.content.isEmpty {
                    HStack {
                        CopyButton(text: message.content)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CopyButton: View {
    let text: String
    @State private var isCopied = false
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = text
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isCopied = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isCopied = false
                }
            }
        }) {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 15))
                .foregroundColor(isCopied ? .green : .secondary)
                .frame(width: 32, height: 32)
                .background(Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChatLoadingBubbleView: View {
    var body: some View {
        ChatLoadingIndicator()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChatErrorBubbleView: View {
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16))
                .foregroundColor(.red)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChatLoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .offset(y: isAnimating ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            isAnimating = true
        }
    }
}
