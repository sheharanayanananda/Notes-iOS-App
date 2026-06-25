//
//  SettingsViewModel.swift
//  Slate
//
//  Created by Antigravity on 2026-06-14.
//

import SwiftUI
import Observation

enum KeyValidationStatus: Equatable {
    case empty
    case checking
    case valid
    case invalid(String)
    case limitExceeded
    
    var iconName: String {
        switch self {
        case .empty: return ""
        case .checking: return ""
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        case .limitExceeded: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .empty: return .clear
        case .checking: return .gray
        case .valid: return .green
        case .invalid: return .red
        case .limitExceeded: return .orange
        }
    }
    
    var message: String {
        switch self {
        case .empty: return ""
        case .checking: return "Checking API key..."
        case .valid: return "Active & Valid"
        case .invalid(let reason): return reason
        case .limitExceeded: return "Usage Limit Exceeded"
        }
    }
}

@Observable
final class SettingsViewModel {
    var apiKey: String = ""
    var validationStatus: KeyValidationStatus = .empty

    
    private var savedApiKey: String = ""
    private var validationTask: Task<Void, Never>?
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {

        
        // Read key from Keychain asynchronously to avoid blocking UI during VM init
        Task(priority: .userInitiated) {
            let key = KeychainHelper.shared.readApiKey() ?? ""
            await MainActor.run {
                self.apiKey = key
                self.savedApiKey = key
                if !key.isEmpty {
                    self.validationStatus = .valid
                }
            }
        }
        

    }
    
    func handleApiKeyChange() {
        validationTask?.cancel()
        
        guard apiKey != savedApiKey else {
            validationStatus = apiKey.isEmpty ? .empty : .valid
            return
        }
        
        validationTask = Task {
            do {
                // Debounce save and validation check by 800ms
                try await Task.sleep(nanoseconds: 800_000_000)
                
                let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Write to Keychain off the main actor to prevent stutters
                await Task(priority: .userInitiated) {
                    if trimmedKey.isEmpty {
                        KeychainHelper.shared.deleteApiKey()
                    } else {
                        KeychainHelper.shared.saveApiKey(trimmedKey)
                    }
                }.value
                
                await MainActor.run {
                    savedApiKey = apiKey
                }
                
                await performValidation()
            } catch {
                // Task cancelled
            }
        }
    }
    

    
    func savePendingChanges() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey != savedApiKey {
            if trimmedKey.isEmpty {
                KeychainHelper.shared.deleteApiKey()
            } else {
                KeychainHelper.shared.saveApiKey(trimmedKey)
            }
            savedApiKey = apiKey
        }
        

    }
    
    private func performValidation() async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationStatus = .empty
            return
        }
        
        validationStatus = .checking
        
        let client = OllamaClient(modelName: "gemma4:31b", apiKey: trimmed)
        do {
            _ = try await client.generate(prompt: "", system: "Validation Check", image: nil)
            validationStatus = .valid
        } catch OllamaError.apiError(let message) {
            if message.localizedCaseInsensitiveContains("limit") || message.localizedCaseInsensitiveContains("quota") {
                validationStatus = .limitExceeded
            } else {
                validationStatus = .invalid(message)
            }
        } catch {
            validationStatus = .invalid(error.localizedDescription)
        }
    }
    

}
