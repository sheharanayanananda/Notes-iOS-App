//
//  ChatManager.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI
import Observation
import UIKit
import UserNotifications

struct ChatSession: Identifiable, Codable {
    var id = UUID()
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
@Observable
final class ChatManager {
    static let shared = ChatManager()
    
    var messages: [OllamaChatMessage] = []
    var sessions: [ChatSession] = []
    var activeSessionId: UUID? = nil
    
    var isGenerating = false
    var errorMessage: String? = nil
    var newlyGeneratedMessageId: String? = nil
    
    // Preset and configuration values
    var displayedPreset: ChatPreset = .slateFlash {
        didSet {
            UserDefaults.standard.set(displayedPreset.rawValue, forKey: "active_chat_preset")
            applyPreset(displayedPreset)
            if let activeId = activeSessionId, let index = sessions.firstIndex(where: { $0.id == activeId }) {
                if sessions[index].preset != displayedPreset {
                    sessions[index].preset = displayedPreset
                    saveSessions(sessions)
                }
            }
        }
    }
    
    var thinkingLevel: String = "Off"
    var creativity: Double = 0.3
    var memorySize: MemoryLimit = .standard
    
    private init() {
        // Load stored preset first
        if let storedValue = UserDefaults.standard.string(forKey: "active_chat_preset"),
           let preset = ChatPreset(rawValue: storedValue) {
            self.displayedPreset = preset
        } else {
            self.displayedPreset = .slateFlash
        }
        applyPreset(self.displayedPreset)
        
        let loaded = loadSessions()
        self.sessions = loaded
        let sorted = loaded.sorted(by: { $0.lastUpdated > $1.lastUpdated })
        if let first = sorted.first {
            self.activeSessionId = first.id
            self.messages = first.messages
            self.displayedPreset = first.preset
        } else {
            let newSess = ChatSession(preset: self.displayedPreset)
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
                let decoded = try JSONDecoder().decode([ChatSession].self, from: data)
                return decoded
            } catch {
                print("Failed to load chat sessions: \(error)")
            }
        }
        
        // Migrate legacy active_chat.json to sessions format if it exists
        if let legacyUrl = getFileURL(), FileManager.default.fileExists(atPath: legacyUrl.path) {
            do {
                let legacyData = try Data(contentsOf: legacyUrl)
                let legacyMessages = try JSONDecoder().decode([OllamaChatMessage].self, from: legacyData)
                if !legacyMessages.isEmpty {
                    let legacySession = ChatSession(
                        title: "Migrated Chat",
                        messages: legacyMessages,
                        lastUpdated: Date()
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
        let defaultSession = ChatSession(preset: self.displayedPreset)
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
            sessions[index].preset = displayedPreset
            
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
        displayedPreset = session.preset
    }
    
    func startNewSession(preset: ChatPreset = .slateFlash) {
        saveCurrentState()
        let newSess = ChatSession(preset: preset)
        sessions.append(newSess)
        activeSessionId = newSess.id
        messages = []
        errorMessage = nil
        displayedPreset = preset
        saveSessions(sessions)
    }
    
    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if activeSessionId == id {
            let newSess = ChatSession(preset: self.displayedPreset)
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
        selectedDocuments: [OllamaDocumentAttachment]
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
        
        // Capture parameter values locally so background thread does not access main-actor properties directly
        let currentPreset = displayedPreset
        let currentThinkingLevel = thinkingLevel
        let currentCreativity = creativity
        let currentMemorySize = memorySize.rawValue
        
        Task.detached(priority: .background) {
            do {
                let client = OllamaClient()
                
                let messagesToSend = await MainActor.run {
                    var msgs = [OllamaChatMessage]()
                    msgs.append(OllamaChatMessage(role: "system", content: currentPreset.systemPrompt))
                    
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
                    reasoningLevel: currentThinkingLevel,
                    creativity: currentCreativity,
                    memorySize: currentMemorySize
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
    
    private func applyPreset(_ preset: ChatPreset) {
        creativity = preset.creativity
        memorySize = preset.memorySize
        thinkingLevel = preset.thinkingLevel
    }
    
    private func sendLocalNotification() {
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
