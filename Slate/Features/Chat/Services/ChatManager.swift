//
//  ChatManager.swift
//  Slate
//
//  Created by Antigravity on 6/23/26.
//

import Foundation
import SwiftUI
import UserNotifications
import UIKit
import Combine

struct ChatSession: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var messages: [OllamaChatMessage]
    var lastUpdated: Date
    var preset: ChatPreset
    
    init(id: UUID = UUID(), title: String = "New Chat", messages: [OllamaChatMessage] = [], lastUpdated: Date = Date(), preset: ChatPreset = .slateFlash) {
        self.id = id
        self.title = title
        self.messages = messages
        self.lastUpdated = lastUpdated
        self.preset = preset
    }
}

@MainActor
final class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    @Published var messages: [OllamaChatMessage] = []
    @Published var sessions: [ChatSession] = []
    @Published var activeSessionId: UUID? = nil
    
    @Published var isGenerating = false
    @Published var errorMessage: String? = nil
    @Published var newlyGeneratedMessageId: String? = nil
    
    private init() {
        let loaded = loadSessions()
        self.sessions = loaded
        let sorted = loaded.sorted(by: { $0.lastUpdated > $1.lastUpdated })
        if let first = sorted.first {
            self.activeSessionId = first.id
            self.messages = first.messages
        } else {
            let newSess = ChatSession()
            self.sessions = [newSess]
            self.activeSessionId = newSess.id
            self.messages = []
        }
    }
    
    private func getFileURL() -> URL? {
        try? FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("active_chat.json")
    }
    
    private func getSessionsFileURL() -> URL? {
        try? FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("chat_sessions.json")
    }
    
    private func loadSessions() -> [ChatSession] {
        guard let url = getSessionsFileURL() else { return [] }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([ChatSession].self, from: data)
            } catch {
                print("Failed to load sessions: \(error)")
            }
        }
        
        // Legacy migration
        if let legacyUrl = getFileURL(), FileManager.default.fileExists(atPath: legacyUrl.path) {
            do {
                let data = try Data(contentsOf: legacyUrl)
                let legacyMessages = try JSONDecoder().decode([OllamaChatMessage].self, from: data)
                if !legacyMessages.isEmpty {
                    var title = "Saved Chat"
                    if let firstUserMsg = legacyMessages.first(where: { $0.role == "user" }) {
                        let content = firstUserMsg.content.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !content.isEmpty {
                            title = String(content.prefix(30)) + (content.count > 30 ? "..." : "")
                        }
                    }
                    let legacySession = ChatSession(
                        id: UUID(),
                        title: title,
                        messages: legacyMessages,
                        lastUpdated: Date(),
                        preset: .slateFlash
                    )
                    try? FileManager.default.removeItem(at: legacyUrl)
                    let sessions = [legacySession]
                    saveSessions(sessions)
                    return sessions
                }
            } catch {
                print("Failed to migrate legacy messages: \(error)")
            }
        }
        
        // Default session if nothing exists
        let defaultSession = ChatSession()
        let sessions = [defaultSession]
        saveSessions(sessions)
        return sessions
    }
    
    private func saveSessions(_ targetSessions: [ChatSession]) {
        guard let url = getSessionsFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(targetSessions)
            try data.write(to: url)
        } catch {
            print("Failed to save chat sessions: \(error)")
        }
    }
    
    func saveCurrentState() {
        guard let activeId = activeSessionId else { return }
        if let index = sessions.firstIndex(where: { $0.id == activeId }) {
            sessions[index].messages = messages
            sessions[index].lastUpdated = Date()
            
            // Auto-update title if it is the default "New Chat" or empty
            if sessions[index].title == "New Chat" || sessions[index].title.isEmpty {
                if let firstUserMsg = messages.first(where: { $0.role == "user" }) {
                    let content = firstUserMsg.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !content.isEmpty {
                        sessions[index].title = String(content.prefix(30)) + (content.count > 30 ? "..." : "")
                    }
                }
            }
            saveSessions(sessions)
        }
    }
    
    func selectSession(_ session: ChatSession) {
        saveCurrentState()
        activeSessionId = session.id
        messages = session.messages
        errorMessage = nil
    }
    
    func startNewSession(preset: ChatPreset = .slateFlash) {
        saveCurrentState()
        let newSess = ChatSession(preset: preset)
        sessions.append(newSess)
        activeSessionId = newSess.id
        messages = []
        errorMessage = nil
        saveSessions(sessions)
    }
    
    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if activeSessionId == id {
            let newSess = ChatSession()
            sessions.append(newSess)
            activeSessionId = newSess.id
            messages = []
            errorMessage = nil
        }
        saveSessions(sessions)
    }
    
    func clearChat() {
        messages = []
        errorMessage = nil
        saveCurrentState()
    }
    
    func sendMessage(
        chatText: String,
        selectedImages: [UIImage],
        selectedDocuments: [OllamaDocumentAttachment],
        displayedPreset: ChatPreset,
        thinkingLevel: String,
        creativity: Double,
        memorySize: MemoryLimit
    ) {
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !selectedImages.isEmpty || !selectedDocuments.isEmpty else { return }
        
        var base64Images: [String]? = nil
        if !selectedImages.isEmpty {
            base64Images = selectedImages.compactMap { img in
                img.jpegData(compressionQuality: 0.7)?.base64EncodedString()
            }
        }
        
        let userMessage = OllamaChatMessage(role: "user", content: trimmed, images: base64Images, documents: selectedDocuments)
        messages.append(userMessage)
        
        let assistantPlaceholder = OllamaChatMessage(role: "assistant", content: "")
        messages.append(assistantPlaceholder)
        saveCurrentState()
        
        isGenerating = true
        errorMessage = nil
        newlyGeneratedMessageId = nil
        
        // Start background task to keep app alive if minimized
        var bgTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
        bgTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "AIChatGeneration") {
            UIApplication.shared.endBackgroundTask(bgTaskIdentifier)
            bgTaskIdentifier = .invalid
        }
        
        Task.detached(priority: .background) {
            do {
                let client = await MainActor.run {
                    OllamaClient(modelName: "gemma4:31b")
                }
                
                let messagesToSend = await MainActor.run {
                    var msgs = [OllamaChatMessage]()
                    msgs.append(OllamaChatMessage(role: "system", content: displayedPreset.systemPrompt))
                    
                    for msg in self.messages.dropLast() {
                        if let docs = msg.documents, !docs.isEmpty {
                            var injectedContent = ""
                            for doc in docs {
                                injectedContent += "[Attached Document: \(doc.name)]\n"
                                injectedContent += doc.contentText
                                injectedContent += "\n--------------------------------------\n\n"
                            }
                            injectedContent += msg.content
                            msgs.append(OllamaChatMessage(role: msg.role, content: injectedContent, images: msg.images))
                        } else {
                            msgs.append(msg)
                        }
                    }
                    return msgs
                }
                
                let finalMessage = try await client.chat(
                    messages: messagesToSend,
                    reasoningLevel: thinkingLevel,
                    creativity: creativity,
                    memorySize: memorySize.rawValue
                )
                
                await MainActor.run {
                    if let lastIndex = self.messages.indices.last {
                        self.messages[lastIndex] = finalMessage
                    }
                    self.isGenerating = false
                    self.saveCurrentState()
                    
                    self.newlyGeneratedMessageId = finalMessage.id
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if self.newlyGeneratedMessageId == finalMessage.id {
                            self.newlyGeneratedMessageId = nil
                        }
                    }
                    
                    if bgTaskIdentifier != .invalid {
                        UIApplication.shared.endBackgroundTask(bgTaskIdentifier)
                        bgTaskIdentifier = .invalid
                    }
                    
                    // Trigger notification
                    self.sendLocalNotification()
                }
            } catch {
                await MainActor.run {
                    if self.messages.last?.role == "assistant" && self.messages.last?.content.isEmpty == true {
                        self.messages.removeLast()
                    }
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                    
                    if bgTaskIdentifier != .invalid {
                        UIApplication.shared.endBackgroundTask(bgTaskIdentifier)
                        bgTaskIdentifier = .invalid
                    }
                }
            }
        }
    }
    
    private func sendLocalNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Slate AI"
            content.body = "Your AI response is ready."
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling local notification: \(error)")
                }
            }
        }
    }
}
