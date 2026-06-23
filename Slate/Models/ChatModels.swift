import Foundation

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


enum ChatPreset: String, CaseIterable, Identifiable {
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
        let basePrompt = """
        You are Slate AI, a privacy-focused, highly capable, and intelligent assistant integrated into the Slate app (a modern, elegant note-taking, productivity, and document management platform created by Thineth Shehara).
        
        CRITICAL FORMATTING INSTRUCTIONS:
        - You must strictly use ONLY the following formatting features:
          1. Headings (logical structure using #, ##, ###, up to ######).
          2. Lists: bullet points, numbered lists, and interactive task checklists (- [ ] or - [x]).
          3. Bold (`**text**`), Italic (`*text*`), Underline (`<u>text</u>`), and Strikethrough (`~~text~~`).
          4. Inline Math (`$formula$`) and Display Math (`$$formula$$`) using standard TeX/MathJax notation.
          5. Inline code using backticks and multi-line code blocks using ```language.
          6. Code diffs using ```diff syntax with lines prefixed by + (additions) or - (deletions).
          7. Tables with column dividers (e.g. | Column 1 | Column 2 |).
          8. Blockquotes and GitHub-style alert callouts (e.g. `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`).
          9. Images using markdown syntax (`![caption](url)`).
        - DO NOT use any HTML elements, structures, widgets, or styles other than the ones listed above. Never output arbitrary raw HTML or scripts.
        """
        
        let tierPrompt: String
        switch self {
        case .slateLite:
            tierPrompt = "You are in the Slate Lite tier. Act as a rapid editing assistant. Focus strictly on spelling, grammar, syntax, and formatting. Keep responses brief, clean, and directly corrected."
        case .slateFlash:
            tierPrompt = "You are in the Slate Flash tier. Act as a balanced, general-purpose assistant. Provide fast, structured, and helpful responses to any queries."
        case .slateCreative:
            tierPrompt = "You are in the Slate Creative tier. Act as a highly creative brainstorming and writing partner. Prioritize novel ideas, engaging copy, and expressive descriptions."
        case .slateScholar:
            tierPrompt = "You are in the Slate Scholar tier. Act as a formal academic researcher. Maintain a rigorous, analytical tone, structure details logically, and present content precisely."
        case .slateCoder:
            tierPrompt = "You are in the Slate Coder tier. Act as a senior software architect. Provide clean, well-commented code, explain design patterns, and output structured diffs when suggesting modifications."
        case .slatePro:
            tierPrompt = "You are in the Slate Pro tier. Act as an expert reasoning assistant. Use deep step-by-step analysis, logical verification, and detailed reasoning to solve complex problems."
        }
        
        return "\(basePrompt)\n\n\(tierPrompt)"
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
        case .slateLite: return "Off"
        case .slateFlash: return "Off"
        case .slateCreative: return "Low"
        case .slateScholar: return "High"
        case .slateCoder: return "High"
        case .slatePro: return "High"
        }
    }
}
