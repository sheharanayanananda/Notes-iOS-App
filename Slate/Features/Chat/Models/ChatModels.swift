//
//  ChatModels.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import Foundation

struct OllamaDocumentAttachment: Codable, Equatable, Hashable, Identifiable {
    var id = UUID()
    let name: String
    let contentText: String
    
    enum CodingKeys: String, CodingKey {
        case name, contentText
    }
    
    init(id: UUID = UUID(), name: String, contentText: String) {
        self.id = id
        self.name = name
        self.contentText = contentText
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.contentText = try container.decode(String.self, forKey: .contentText)
        self.id = UUID()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(contentText, forKey: .contentText)
    }
}

struct OllamaChatMessage: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    let role: String      // "user", "assistant", "system"
    let content: String
    var images: [String]? // Base64 encoded JPEG representations
    var documents: [OllamaDocumentAttachment]?
    var genuiState: String? // Persistent interactive state
    
    enum CodingKeys: String, CodingKey {
        case role, content, images, documents, genuiState
    }
    
    init(id: String = UUID().uuidString, role: String, content: String, images: [String]? = nil, documents: [OllamaDocumentAttachment]? = nil, genuiState: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.images = images
        self.documents = documents
        self.genuiState = genuiState
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
        self.images = try container.decodeIfPresent([String].self, forKey: .images)
        self.documents = try container.decodeIfPresent([OllamaDocumentAttachment].self, forKey: .documents)
        self.genuiState = try container.decodeIfPresent(String.self, forKey: .genuiState)
        self.id = UUID().uuidString
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(documents, forKey: .documents)
        try container.encodeIfPresent(genuiState, forKey: .genuiState)
    }
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

enum ChatPreset: String, CaseIterable, Identifiable, Codable {
    case slateLite = "Slate Lite"
    case slateFlash = "Slate Flash"
    case slateCreative = "Slate Creative"
    case slateScholar = "Slate Scholar"
    case slateCoder = "Slate Coder"
    case slatePro = "Slate Pro"
    
    var id: String { self.rawValue }
    
    var title: String { self.rawValue }
    
    var modelTierName: String {
        switch self {
        case .slateLite: return "Lite"
        case .slateFlash: return "Flash"
        case .slateCreative: return "Creative"
        case .slateScholar: return "Scholar"
        case .slateCoder: return "Coder"
        case .slatePro: return "Pro"
        }
    }
    
    var shortName: String {
        switch self {
        case .slateLite: return "Slate Lite"
        case .slateFlash: return "Slate Flash"
        case .slateCreative: return "Slate Creative"
        case .slateScholar: return "Slate Scholar"
        case .slateCoder: return "Slate Coder"
        case .slatePro: return "Slate Pro"
        }
    }
    
    var subtitle: String {
        switch self {
        case .slateLite: return "Fast editing, short 4K memory"
        case .slateFlash: return "Balanced general purpose, standard 8K memory"
        case .slateCreative: return "Brainstorming and drafting, detailed 16K memory"
        case .slateScholar: return "Academic research, detailed 16K memory"
        case .slateCoder: return "Coding expert, high reasoning, 32K memory"
        case .slatePro: return "Deep reasoning, maximum 32K memory"
        }
    }
    
    var systemPrompt: String {
        SystemPrompts.chatPresetPrompt(for: self)
    }
    
    var creativity: Double {
        switch self {
        case .slateLite: return 0.1
        case .slateFlash: return 0.3
        case .slateCreative: return 0.8
        case .slateScholar: return 0.2
        case .slateCoder: return 0.1
        case .slatePro: return 0.2
        }
    }
    
    var memorySize: MemoryLimit {
        switch self {
        case .slateLite: return .short
        case .slateFlash: return .standard
        case .slateCreative: return .detailed
        case .slateScholar: return .detailed
        case .slateCoder: return .maximum
        case .slatePro: return .maximum
        }
    }
    
    var thinkingLevel: String {
        switch self {
        case .slateLite: return "Low"
        case .slateFlash: return "Low"
        case .slateCreative: return "Low"
        case .slateScholar: return "High"
        case .slateCoder: return "High"
        case .slatePro: return "High"
        }
    }
}
