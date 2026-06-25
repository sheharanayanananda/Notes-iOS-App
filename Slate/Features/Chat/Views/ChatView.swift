//
//  ChatView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-20.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Binding var activeTab: ContentView.TabIdentifier
    @Binding var editingNote: SlateModel?
    
    @State private var chatText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var selectedDocuments: [OllamaDocumentAttachment] = []
    
    @State private var thinkingLevel: String = "Off"
    @State private var creativity: Double = 0.3
    @State private var memorySize: MemoryLimit = .standard
    
    // Persisted storage — only written to, never read for UI rendering
    @AppStorage("active_chat_preset") private var storedPreset: ChatPreset = .slateFlash
    // State-driven — drives the UI instantly without SwiftUI animation transactions
    @State private var displayedPreset: ChatPreset = .slateFlash

    @ObservedObject private var chatManager = ChatManager.shared
    
    private var messages: [OllamaChatMessage] { chatManager.messages }
    private var isGenerating: Bool { chatManager.isGenerating }
    private var errorMessage: String? { chatManager.errorMessage }
    private var newlyGeneratedMessageId: String? { chatManager.newlyGeneratedMessageId }
    
    @FocusState private var isInputFocused: Bool
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
                            selectedImages: $selectedImages,
                            selectedDocuments: $selectedDocuments,
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
                                    ChatBubbleView(
                                        message: message,
                                        isNew: message.id == newlyGeneratedMessageId,
                                        isGenerating: isGenerating && message.id == messages.last?.id,
                                        activeTab: $activeTab,
                                        editingNote: $editingNote
                                    ) {
                                        self.scrollToBottom(proxy: proxy, delay: 0.0, animate: true)
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
                            selectedImages: $selectedImages,
                            selectedDocuments: $selectedDocuments,
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
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Menu {
                    Picker("Preset", selection: $displayedPreset) {
                        ForEach(ChatPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(Text("Slate ").font(.system(size: 17, weight: .semibold)))\(Text(displayedPreset.modelTierName).font(.system(size: 16, weight: .regular)))")
                            .foregroundColor(.primary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: displayedPreset) {
                    selectPreset(displayedPreset)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    chatManager.clearChat()
                    chatText = ""
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    chatManager.clearChat()
                    chatText = ""
                }) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
            }
        }
        .onChange(of: chatManager.isGenerating) { _, newValue in
            if !newValue {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    isTextFieldDisabled = false
                }
            }
        }
        .onAppear {
            // Load persisted preset into @State on first appear
            displayedPreset = storedPreset
            applyPreset(storedPreset)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Main Functions
extension ChatView {
    /// Selects a preset instantly in UI state, persists without animation
    private func selectPreset(_ preset: ChatPreset) {
        displayedPreset = preset
        applyPreset(preset)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        DispatchQueue.main.async {
            storedPreset = preset
        }
    }
    
    private func sendMessage() {
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !selectedImages.isEmpty || !selectedDocuments.isEmpty else { return }
        
        isInputFocused = false
        
        let imagesCopy = selectedImages
        let documentsCopy = selectedDocuments
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            chatText = ""
            selectedImages = []
            selectedDocuments = []
            chatManager.newlyGeneratedMessageId = nil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isTextFieldDisabled = true
            }
        }
        
        let sendGenerator = UIImpactFeedbackGenerator(style: .light)
        sendGenerator.impactOccurred()
        
        chatManager.sendMessage(
            chatText: trimmed,
            selectedImages: imagesCopy,
            selectedDocuments: documentsCopy,
            displayedPreset: displayedPreset,
            thinkingLevel: thinkingLevel,
            creativity: creativity,
            memorySize: memorySize
        )
    }
}

// MARK: - Supporting Functions
extension ChatView {
    private func applyPreset(_ preset: ChatPreset) {
        creativity = preset.creativity
        memorySize = preset.memorySize
        thinkingLevel = preset.thinkingLevel
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
}

#Preview {
    NavigationStack {
        ChatView(activeTab: .constant(.notes), editingNote: .constant(nil))
    }
}




struct ChatBubbleView: View {
    let message: OllamaChatMessage
    var isNew: Bool = false
    var isGenerating: Bool = false
    @Binding var activeTab: ContentView.TabIdentifier
    @Binding var editingNote: SlateModel?
    var onBlockRevealed: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context
    
    @State private var isAnimationCompleted: Bool = false
    
    var body: some View {
        if message.role == "user" {
            VStack(alignment: .trailing, spacing: 8) {
                // Render Images
                if let images = message.images, !images.isEmpty {
                    let cardSize: CGFloat = 100
                    let spacing: CGFloat = 8
                    let maxW: CGFloat = 300
                    let contentWidth = CGFloat(images.count) * cardSize + CGFloat(images.count - 1) * spacing
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            ForEach(images, id: \.self) { base64Str in
                                if let data = Data(base64Encoded: base64Str), let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: cardSize, height: cardSize)
                                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .frame(width: min(contentWidth, maxW))
                }
                
                // Render Documents
                if let documents = message.documents, !documents.isEmpty {
                    let cardW: CGFloat = 120
                    let cardH: CGFloat = 85
                    let spacing: CGFloat = 8
                    let maxW: CGFloat = 300
                    let contentWidth = CGFloat(documents.count) * cardW + CGFloat(documents.count - 1) * spacing
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            ForEach(documents) { doc in
                                VStack(alignment: .leading, spacing: 4) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    
                                    Text(doc.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .frame(width: cardW, height: cardH, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .frame(width: min(contentWidth, maxW))
                }
                
                if !message.content.isEmpty {
                    MessageView(content: message.content, isNew: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                        .textSelection(.enabled)
                        .lineHeight(.loose)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if message.content.isEmpty && isGenerating {
                    ChatLoadingStatusView()
                } else {
                    MessageView(content: message.content, isNew: isNew, onBlockRevealed: onBlockRevealed) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isAnimationCompleted = true
                        }
                    }
                    .textSelection(.enabled)
                    
                    if !message.content.isEmpty && !isGenerating && isAnimationCompleted {
                        HStack(spacing: 8) {
                            CopyButton(text: message.content)
                            AddToNoteButton(text: message.content, activeTab: $activeTab, editingNote: $editingNote, context: context)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                isAnimationCompleted = !isNew
            }
            .onChange(of: isNew) { _, newValue in
                if newValue {
                    isAnimationCompleted = false
                } else {
                    isAnimationCompleted = true
                }
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CopyButton: View {
    let text: String
    @State private var isCopied = false
    @Environment(\.colorScheme) private var colorScheme
    
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
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isCopied ? .green : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct AddToNoteButton: View {
    let text: String
    @Binding var activeTab: ContentView.TabIdentifier
    @Binding var editingNote: SlateModel?
    let context: ModelContext
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            // Create an in-memory note (NOT inserted into the DB) with a placeholder title.
            // CreateTabView will intercept this title onAppear/onChange and perform background Ollama extraction.
            let draft = SlateModel(title: "ChatDraft_PendingExtraction", desc: text)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            editingNote = draft
            activeTab = .create
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text("Slate")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
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

struct ChatLoadingStatusView: View {
    @State private var entranceOpacity = 0.0
    
    var body: some View {
        TimelineView(.animation) { timelineContext in
            let date = timelineContext.date
            let timeInterval = date.timeIntervalSinceReferenceDate
            let phase = CGFloat((timeInterval).truncatingRemainder(dividingBy: 1.8) / 1.8)
            
            HStack(spacing: 8) {
                Text("Thinking")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                
                HStack(spacing: 3) {
                    ForEach(0..<3) { index in
                        let dotOffset = sin((timeInterval * 5.0) - Double(index) * 1.2) * 4.0
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 4, height: 4)
                            .offset(y: dotOffset)
                    }
                }
                .frame(width: 20, height: 10)
            }
            .padding(.leading, 8)
            .padding(.vertical, 8)
            .mask(
                GeometryReader { geo in
                    let size = geo.size
                    ZStack(alignment: .leading) {
                        Color.black.opacity(0.35)
                        
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .black,
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: size.width / 1.2)
                        .offset(x: -size.width + (size.width * 2) * phase)
                    }
                }
            )
            .opacity(entranceOpacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    entranceOpacity = 1.0
                }
            }
        }
    }
}

