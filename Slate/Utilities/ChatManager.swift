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

@MainActor
class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    @Published var messages: [OllamaChatMessage] = []
    @Published var isGenerating = false
    @Published var errorMessage: String? = nil
    @Published var newlyGeneratedMessageId: String? = nil
    
    private init() {
        self.messages = loadMessages()
    }
    
    func getFileURL() -> URL? {
        try? FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("active_chat.json")
    }
    
    func loadMessages() -> [OllamaChatMessage] {
        guard let url = getFileURL() else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([OllamaChatMessage].self, from: data)
        } catch {
            return []
        }
    }
    
    func saveMessages(_ msgs: [OllamaChatMessage]) {
        guard let url = getFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(msgs)
            try data.write(to: url)
        } catch {
            print("Failed to save chat messages: \(error)")
        }
    }
    
    func clearChat() {
        messages = []
        saveMessages([])
        errorMessage = nil
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
        saveMessages(messages)
        
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
                    self.saveMessages(self.messages)
                    
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
