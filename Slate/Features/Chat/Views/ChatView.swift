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
    
    @State private var chatText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var selectedDocuments: [OllamaDocumentAttachment] = []
    
    @State private var chatManager = ChatManager.shared
    
    private var messages: [OllamaChatMessage] { chatManager.messages }
    private var isGenerating: Bool { chatManager.isGenerating }
    private var errorMessage: String? { chatManager.errorMessage }
    private var newlyGeneratedMessageId: String? { chatManager.newlyGeneratedMessageId }
    
    @FocusState private var isInputFocused: Bool
    @State private var isTextFieldDisabled = false
    @State private var scrollTask: Task<Void, Never>? = nil
    @State private var hasAppeared = false
    @State private var showHistory = false
    
    var body: some View {
        @Bindable var chatManager = chatManager
        
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
                                        isGenerating: isGenerating && message.id == messages.last?.id
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
                    Picker("Preset", selection: $chatManager.displayedPreset) {
                        ForEach(ChatPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(Text("Slate ").font(.system(size: 17, weight: .semibold)))\(Text(chatManager.displayedPreset.modelTierName).font(.system(size: 16, weight: .regular)))")
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: chatManager.displayedPreset) {
                    HapticManager.trigger(.medium)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 15) {
                    Button(action: {
                        HapticManager.trigger(.medium)
                        chatManager.startNewSession(preset: chatManager.displayedPreset)
                        chatText = ""
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        HapticManager.trigger(.medium)
                        showHistory = true
                    }) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .sheet(isPresented: $showHistory) {
            ChatHistoryView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .onChange(of: chatManager.isGenerating) { _, newValue in
            if !newValue {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    isTextFieldDisabled = false
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Main Functions
extension ChatView {
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
        
        HapticManager.trigger(.light)
        
        chatManager.sendMessage(
            chatText: trimmed,
            selectedImages: imagesCopy,
            selectedDocuments: documentsCopy
        )
    }
}

// MARK: - Supporting Functions
extension ChatView {
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
        ChatView(activeTab: .constant(.notes))
    }
}
