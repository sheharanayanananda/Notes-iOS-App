//
//  ChatBubbleComponents.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI
import SwiftData

struct ChatBubbleView: View {
    let message: OllamaChatMessage
    var isNew: Bool = false
    var isGenerating: Bool = false
    var onBlockRevealed: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    
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
                    let screenWidth = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.width ?? 375
                    MessageView(messageID: message.id, content: message.content, isNew: false, isFullWidth: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                        .textSelection(.enabled)
                        .frame(maxWidth: screenWidth * 0.70, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if message.content.isEmpty && isGenerating {
                    ChatLoadingStatusView()
                } else {
                    MessageView(messageID: message.id, content: message.content, isNew: isNew, onBlockRevealed: onBlockRevealed) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isAnimationCompleted = true
                        }
                    }
                    .textSelection(.enabled)
                    
                    if !message.content.isEmpty && !isGenerating && isAnimationCompleted {
                        HStack(spacing: 8) {
                            CopyButton(text: message.content)
                            if isNoteWorthy(message.content) {
                                SlateNoteButton(text: message.content)
                            }
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
    
    private func isNoteWorthy(_ content: String) -> Bool {
        // Check for common markdown structures using standard string matches
        if content.contains("\n#") || content.hasPrefix("#") { return true }
        if content.contains("\n- ") || content.contains("\n* ") || content.contains("\n1. ") || content.contains("\n[ ]") { return true }
        if content.contains("```") { return true }
        if content.contains("|") { return true }
        if content.contains("$") { return true }
        if content.contains("> [!") { return true }
        if content.contains("<genui>") { return true }
        
        // Word count check (> 80 words)
        let words = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return words.count > 80
    }
}

struct CopyButton: View {
    let text: String
    @State private var isCopied = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = text
            HapticManager.triggerNotification(.success)
            
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

struct SlateNoteButton: View {
    let text: String
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    enum SaveState {
        case idle
        case saving
        case saved
    }
    
    @State private var state: SaveState = .idle
    
    var body: some View {
        Button(action: {
            guard state != .saving else { return }
            saveToNotes()
        }) {
            HStack(spacing: 6) {
                switch state {
                case .idle:
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("Slate")
                        .font(.system(size: 12, weight: .semibold))
                case .saving:
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text("Saving...")
                        .font(.system(size: 12, weight: .semibold))
                case .saved:
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                    Text("In Slate")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .foregroundColor(state == .saved ? .green : .secondary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
                    .overlay(
                        Capsule()
                            .stroke(state == .saved ? Color.green.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(state == .saving)
    }
    
    private func saveToNotes() {
        HapticManager.triggerNotification(.success)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            state = .saving
        }
        
        Task {
            do {
                let client = OllamaClient()
                let messages = SystemPrompts.noteExtractionMessages(for: text)
                
                var extractedTitle = ""
                var extractedBody = ""
                
                // Stream extraction response in background
                let response = try await client.chatStream(messages: messages) { _ in }
                
                let responseText = response.content
                if let titleRange = responseText.range(of: "---TITLE---"),
                   let bodyRange = responseText.range(of: "---BODY---") {
                    let titleStart = titleRange.upperBound
                    let titleEnd = bodyRange.lowerBound
                    let parsedTitle = responseText[titleStart..<titleEnd].trimmingCharacters(in: .whitespacesAndNewlines)
                    let parsedBody = responseText[bodyRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !parsedTitle.isEmpty && !parsedBody.isEmpty {
                        extractedTitle = parsedTitle
                        extractedBody = parsedBody
                    }
                }
                
                if extractedTitle.isEmpty || extractedBody.isEmpty {
                    extractedTitle = "AI Note"
                    extractedBody = responseText.isEmpty ? text : responseText
                }
                
                let finalTitle = extractedTitle
                let finalBody = extractedBody
                
                await MainActor.run {
                    let note = SlateModel(title: finalTitle, desc: finalBody)
                    context.insert(note)
                    try? context.save()
                    
                    // Post a notification to trigger Notes tab badge pulse
                    NotificationCenter.default.post(name: NSNotification.Name("PulseNotesTab"), object: nil)
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state = .saved
                    }
                }
            } catch {
                print("Failed to save to notes: \(error)")
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state = .idle
                    }
                }
            }
        }
    }
}

struct ChatErrorBubbleView: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var parsedError: (title: String, description: String, icon: String, color: Color) {
        let lower = message.lowercased()
        if lower.contains("offline") || lower.contains("internet connection appears to be offline") || lower.contains("network connection") {
            return (
                title: "Connection Offline",
                description: "No internet connection detected. Please check your network connection.",
                icon: "wifi.slash",
                color: .red
            )
        } else if lower.contains("timed out") || lower.contains("timeout") {
            return (
                title: "Request Timeout",
                description: "The request took too long. Please check your network and try again.",
                icon: "timer",
                color: .orange
            )
        } else if lower.contains("api key is missing") || lower.contains("missingapikey") {
            return (
                title: "API Key Required",
                description: "Your API Key is missing. Please configure it in Settings.",
                icon: "key.fill",
                color: .orange
            )
        } else if lower.contains("unauthorized") || lower.contains("401") || lower.contains("incorrect or inactive") {
            return (
                title: "Authentication Failed",
                description: "The API Key is incorrect or inactive. Please verify it in Settings.",
                icon: "exclamationmark.shield.fill",
                color: .red
            )
        } else if lower.contains("limit") || lower.contains("quota") || lower.contains("429") {
            return (
                title: "Limit Reached",
                description: "You have reached the usage limit. Please try again later.",
                icon: "exclamationmark.bubble.fill",
                color: .orange
            )
        } else if lower.contains("host") || lower.contains("cannot connect") || lower.contains("connection refused") {
            return (
                title: "Server Unreachable",
                description: "Unable to connect to the intelligence server. Please try again later.",
                icon: "server.rack",
                color: .red
            )
        } else {
            return (
                title: "Service Issue",
                description: message,
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
        }
    }
    
    var body: some View {
        let err = parsedError
        HStack(alignment: .top, spacing: 14) {
            // Left icon container
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(err.color.opacity(0.12))
                
                Image(systemName: err.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(err.color)
            }
            .frame(width: 38, height: 38)
            
            // Center texts
            VStack(alignment: .leading, spacing: 4) {
                Text(err.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(err.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Dismiss button
            Button(action: {
                HapticManager.trigger(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    ChatManager.shared.errorMessage = nil
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.90))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.11) : Color(white: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(err.color.opacity(0.15), lineWidth: 1.5)
        )
        .padding(.vertical, 4)
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
