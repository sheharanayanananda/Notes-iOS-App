import Foundation

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
    case codeArchitect = "Code Architect"
    case academicResearcher = "Academic Researcher"
    
    var id: String { self.rawValue }
    
    var title: String { self.rawValue }
    
    var shortName: String {
        switch self {
        case .balanced: return "Balanced"
        case .deepReasoning: return "Deep Reasoning"
        case .creativeDrafts: return "Creative"
        case .quickCorrections: return "Quick Fixes"
        case .codeArchitect: return "Coder"
        case .academicResearcher: return "Academic"
        }
    }
    
    var subtitle: String {
        switch self {
        case .balanced: return "Balanced creativity, standard 8K memory"
        case .deepReasoning: return "High reasoning depth, maximum 32K memory"
        case .creativeDrafts: return "High creativity, detailed 16K memory"
        case .quickCorrections: return "Low creativity, fast 4K memory"
        case .codeArchitect: return "Code expert, high reasoning, 32K memory"
        case .academicResearcher: return "Formal tone, deep analysis, 16K memory"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .balanced: return "You are a highly capable and helpful assistant. Provide clear, accurate, and structured responses. Use markdown formatting where appropriate to improve readability."
        case .deepReasoning: return "You are an expert analyst and critical thinker. Break down complex problems step-by-step. Explore multiple angles, provide comprehensive explanations, and ensure your logical deductions are sound before arriving at a conclusion."
        case .creativeDrafts: return "You are a creative writer and brainstormer. Prioritize novel ideas, engaging storytelling, and expressive language. Feel free to explore unconventional concepts and use an inspiring tone."
        case .quickCorrections: return "You are an expert editor. Focus strictly on fixing grammar, syntax, spelling, and formatting. Be as brief as possible and provide only the corrected text unless an explanation is explicitly requested."
        case .codeArchitect: return "You are a senior software engineer. Write clean, efficient, and well-documented code. Always explain your technical decisions and follow best practices for the language being used."
        case .academicResearcher: return "You are a meticulous researcher. Maintain a formal, academic tone. Cite sources implicitly, be precise with terminology, and structure responses like a research paper."
        }
    }
    
    var creativity: Double {
        switch self {
        case .balanced: return 0.3
        case .deepReasoning: return 0.2
        case .creativeDrafts: return 0.8
        case .quickCorrections: return 0.1
        case .codeArchitect: return 0.1
        case .academicResearcher: return 0.2
        }
    }
    
    var memorySize: MemoryLimit {
        switch self {
        case .balanced: return .standard
        case .deepReasoning: return .maximum
        case .creativeDrafts: return .detailed
        case .quickCorrections: return .short
        case .codeArchitect: return .maximum
        case .academicResearcher: return .detailed
        }
    }
    
    var thinkingLevel: String {
        switch self {
        case .balanced: return "Off"
        case .deepReasoning: return "High"
        case .creativeDrafts: return "Low"
        case .quickCorrections: return "Off"
        case .codeArchitect: return "High"
        case .academicResearcher: return "High"
        }
    }
}
