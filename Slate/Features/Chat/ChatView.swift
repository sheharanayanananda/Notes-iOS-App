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
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    @State private var selectedModel: ModelMetadata = ModelMetadata.availableModels[0]
    @State private var thinkingLevel: String = "Off"
    @State private var creativity: Double = 0.3
    @State private var memorySize: MemoryLimit = .standard
    @State private var activePreset: ChatPreset = .balanced
    @State private var messages: [OllamaChatMessage] = []
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @FocusState private var isInputFocused: Bool
    
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
                        inputCapsuleView
                            .padding(.bottom, 16)
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            LazyVStack(spacing: 24) {
                                ForEach(messages) { message in
                                    if message.role == "assistant" && message.content.isEmpty && isGenerating {
                                        ChatLoadingBubbleView()
                                            .id("loading")
                                    } else {
                                        ChatBubbleView(message: message)
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
                    .safeAreaInset(edge: .bottom) {
                        inputCapsuleView
                            .padding(.bottom, 16)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: messages) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: isGenerating) {
                        scrollToBottom(proxy: proxy)
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
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .background || newValue == .inactive {
                isDragging = false
                dragOffset = .zero
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    activeTab = .notes
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            
            ToolbarItem(placement: .principal) {
                Menu {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(ModelMetadata.availableModels) { model in
                            Text(model.id).tag(model)
                        }
                    }
                    
                    Picker("Presets", selection: $activePreset) {
                        ForEach(ChatPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(selectedModel.id) • \(activePreset.shortName)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
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
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            messages = loadMessages()
            applyPreset(activePreset)
        }
        .onChange(of: selectedModel) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            selectModel(selectedModel)
        }
        .onChange(of: activePreset) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            applyPreset(activePreset)
        }
    }
    
    @ViewBuilder
    private var inputCapsuleView: some View {
        HStack(spacing: 12) {
            Button(action: {
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            
            // Chat input textfield
            TextField("Ask Slate", text: $chatText)
                .font(.system(size: 16))
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .disabled(isGenerating)
                .onSubmit {
                    sendMessage()
                }
            
            // Voice input microphone button
            Button(action: {
                // Microphone Action
            }) {
                Image(systemName: "mic")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            .disabled(isGenerating)
            
            // Send Button
            Button(action: {
                sendMessage()
            }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16))
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(width: 36, height: 36)
                    .background(chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating ? Color.primary.opacity(0.3) : Color.primary)
                    .clipShape(Circle())
            }
            .disabled(chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
        }
        .padding()
        .padding(.leading, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07), lineWidth: 1)
                )
                .onTapGesture {
                    isInputFocused = true
                }
        )
        .scaleEffect(x: liquidScaleX, y: liquidScaleY)
        .offset(x: dragOffset.width * 0.25, y: dragOffset.height * 0.25)
        .simultaneousGesture(dragGesture)
        .padding(.horizontal, 16)
    }
    
    private var liquidScaleX: CGFloat {
        let stretch = abs(dragOffset.width) * 0.0015 - abs(dragOffset.height) * 0.001
        return min(max(1.0 + stretch, 0.8), 1.2)
    }
    
    private var liquidScaleY: CGFloat {
        let stretch = abs(dragOffset.height) * 0.0015 - abs(dragOffset.width) * 0.001
        return min(max(1.0 + stretch, 0.8), 1.2)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                
                let oldWidth = dragOffset.width
                let newWidth = value.translation.width
                if Int(abs(newWidth) / 20) != Int(abs(oldWidth) / 20) {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.5)
                }
                
                let horizontalTranslation = value.translation.width
                let verticalTranslation = value.translation.height
                dragOffset = CGSize(width: horizontalTranslation, height: verticalTranslation)
            }
            .onEnded { _ in
                if isDragging {
                    isDragging = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                        dragOffset = .zero
                    }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
    }
    
    private func selectModel(_ model: ModelMetadata) {
        selectedModel = model
        applyPreset(activePreset)
    }
    
    private func applyPreset(_ preset: ChatPreset) {
        activePreset = preset
        creativity = preset.creativity
        
        // Clamp memory size to model's max memory size
        if preset.memorySize > selectedModel.maxMemorySize {
            memorySize = selectedModel.maxMemorySize
        } else {
            memorySize = preset.memorySize
        }
        
        // Check if model supports thinking
        if selectedModel.supportsThinking {
            thinkingLevel = preset.thinkingLevel
        } else {
            thinkingLevel = "Off"
        }
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
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            proxy.scrollTo("bottomSpacer", anchor: .bottom)
        }
    }
    
    private func sendMessage() {
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        chatText = ""
        errorMessage = nil
        
        let userMessage = OllamaChatMessage(role: "user", content: trimmed)
        messages.append(userMessage)
        
        // Append an empty assistant message as a placeholder for streaming
        let assistantPlaceholder = OllamaChatMessage(role: "assistant", content: "")
        messages.append(assistantPlaceholder)
        saveMessages(messages)
        
        let sendGenerator = UIImpactFeedbackGenerator(style: .light)
        sendGenerator.impactOccurred()
        
        isGenerating = true
        
        Task {
            do {
                let client = OllamaClient(modelName: selectedModel.systemName)
                
                let finalMessage = try await client.chatStream(
                    messages: messages.dropLast(),
                    reasoningLevel: selectedModel.supportsThinking ? thinkingLevel : "off",
                    creativity: creativity,
                    memorySize: memorySize.rawValue
                ) { chunk in
                    Task { @MainActor in
                        if let lastIndex = messages.indices.last {
                            let currentContent = messages[lastIndex].content
                            messages[lastIndex] = OllamaChatMessage(
                                id: messages[lastIndex].id,
                                role: "assistant",
                                content: currentContent + chunk
                            )
                        }
                    }
                }
                
                await MainActor.run {
                    if let lastIndex = messages.indices.last {
                        messages[lastIndex] = finalMessage
                    }
                    saveMessages(messages)
                    isGenerating = false
                    
                    let replyGenerator = UIImpactFeedbackGenerator(style: .medium)
                    replyGenerator.impactOccurred()
                }
            } catch {
                await MainActor.run {
                    if messages.last?.role == "assistant" && messages.last?.content.isEmpty == true {
                        messages.removeLast()
                    }
                    errorMessage = error.localizedDescription
                    isGenerating = false
                    
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

struct ModelMetadata: Identifiable, Hashable {
    let id: String
    let systemName: String
    let description: String
    
    let supportsThinking: Bool
    let maxMemorySize: MemoryLimit
    let defaultCreativity: Double
}

enum MemoryLimit: Int, Comparable, CaseIterable, Identifiable {
    case short = 4096      // 4K
    case standard = 8192   // 8K
    case detailed = 16384  // 16K
    case maximum = 32768   // 32K
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .short: return "Short (4K)"
        case .standard: return "Standard (8K)"
        case .detailed: return "Detailed (16K)"
        case .maximum: return "Maximum (32K)"
        }
    }
    
    var subLabel: String {
        switch self {
        case .short: return "For quick, simple chats"
        case .standard: return "Good for most tasks"
        case .detailed: return "Better for referencing multiple notes"
        case .maximum: return "Remembers extremely long chats"
        }
    }
    
    static func < (lhs: MemoryLimit, rhs: MemoryLimit) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension ModelMetadata {
    static let availableModels: [ModelMetadata] = [
        ModelMetadata(id: "Gemma 4", systemName: "gemma4:31b", description: "Best for complex note organization, writing code, and automated connections to other apps.", supportsThinking: true, maxMemorySize: .maximum, defaultCreativity: 0.2)
    ]
}

enum ChatPreset: String, CaseIterable, Identifiable {
    case balanced = "Balanced Assistant"
    case deepReasoning = "Deep Reasoning"
    case creativeDrafts = "Creative Drafts"
    case quickCorrections = "Quick Corrections"
    
    var id: String { self.rawValue }
    
    var title: String { self.rawValue }
    
    var shortName: String {
        switch self {
        case .balanced: return "Balanced"
        case .deepReasoning: return "Deep Reasoning"
        case .creativeDrafts: return "Creative"
        case .quickCorrections: return "Quick Fixes"
        }
    }
    
    var subtitle: String {
        switch self {
        case .balanced: return "Balanced creativity, standard 8K memory"
        case .deepReasoning: return "High reasoning depth, maximum 32K memory"
        case .creativeDrafts: return "High creativity, detailed 16K memory"
        case .quickCorrections: return "Low creativity, fast 4K memory"
        }
    }
    
    var creativity: Double {
        switch self {
        case .balanced: return 0.3
        case .deepReasoning: return 0.2
        case .creativeDrafts: return 0.8
        case .quickCorrections: return 0.1
        }
    }
    
    var memorySize: MemoryLimit {
        switch self {
        case .balanced: return .standard
        case .deepReasoning: return .maximum
        case .creativeDrafts: return .detailed
        case .quickCorrections: return .short
        }
    }
    
    var thinkingLevel: String {
        switch self {
        case .balanced: return "Off"
        case .deepReasoning: return "High"
        case .creativeDrafts: return "Low"
        case .quickCorrections: return "Off"
        }
    }
}


struct ChatBubbleView: View {
    let message: OllamaChatMessage
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if message.role == "user" {
            HStack {
                Spacer()
                MarkdownMessageView(content: message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                MarkdownMessageView(content: message.content)
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
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .padding(.top, 8)
        .onAppear {
            isAnimating = true
        }
    }
}
