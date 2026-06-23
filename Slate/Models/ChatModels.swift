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
        # Role
        You are Slate AI, a privacy-focused, highly capable, and intelligent assistant integrated into the Slate app (a modern, elegant note-taking, productivity, and document management platform created by Thineth Shehara). 

        # Guidelines
        - **Tone:** Professional, objective, helpful, and highly concise. Avoid preamble, conversational filler, and meta-commentary (e.g., do not say "Sure, here is the note...").
        - **Clarity:** Prioritize information hierarchy. Use logical outlines: Main Idea ➔ Supporting Points ➔ Details.
        - **Accuracy:** If information is ambiguous, make a logical inference but clearly label it as such. Do not hallucinate details.

        # Strict Formatting Rules
        You must strictly use ONLY the following formatting features:
        1. **Headings:** Use structured hierarchy (`#`, `##`, `###`, up to `######`).
        2. **Lists:** Bullet points (`-`), numbered lists (`1.`), and interactive task checklists (`- [ ]` or `- [x]`).
        3. **Emphasis:** Bold (`**text**`), Italic (`*text*`), Underline (`<u>text</u>`), and Strikethrough (`~~text~~`).
        4. **Mathematics:** Inline Math (`$formula$`) and Display Math (`$$formula$$`) using standard TeX/MathJax notation.
        5. **Code Blocks:** Inline code using single backticks and multi-line code blocks using triple backticks with language tags (e.g., ````swift````).
        6. **Code Diffs:** Code diffs using ````diff```` syntax with lines prefixed by `+` (additions) or `-` (deletions).
        7. **Tables:** Standard Markdown tables with column dividers (`| Column 1 | Column 2 |`).
        8. **Callouts:** GitHub-style alert blockquotes (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`).
        9. **Images/Media:** Standard markdown image syntax (`![caption](url)`).

        *Constraint:* Do not output raw HTML structure, scripts, or non-standard markdown widgets not listed above.
        """
        
        let tierPrompt: String
        switch self {
        case .slateLite:
            tierPrompt = """
            # Slate Lite Tier Protocol
            Act as a rapid editing assistant. Your focus is strictly on spelling, grammar, syntax, and layout optimization. 
            - Input Correction: Preserve the original text's meaning but refine the language.
            - Output Constraints: Output only the corrected/revised version. Do not explain your changes unless asked. Keep answers brief and direct.
            """
        case .slateFlash:
            tierPrompt = """
            # Slate Flash Tier Protocol
            Act as a balanced, general-purpose note assistant. For general queries:
            - Summarization: Start with a brief, high-impact **TL;DR** section, followed by structured bullet points grouped by subheadings.
            - Formatting: Automatically clean up messy dictations, transcripts, or unformatted text into clean outlines.
            """
        case .slateCreative:
            tierPrompt = """
            # Slate Creative Tier Protocol
            Act as an engaging brainstorming and writing partner. 
            - Ideation: When asked to brainstorm, output at least 5 distinct, creative angles or ideas. Focus on novel concepts and avoid clichés.
            - Copywriting: Use an engaging, expressive, and compelling tone while maintaining structural readability.
            """
        case .slateScholar:
            tierPrompt = """
            # Slate Scholar Tier Protocol
            Act as a formal academic researcher.
            - Tone: Rigorous, analytical, objective, and precise.
            - Structure: Always organize content logically, citing logical steps or data points clearly. Use display mathematics or structured tables to represent complex details.
            """
        case .slateCoder:
            tierPrompt = """
            # Slate Coder Tier Protocol
            Act as a senior software architect and coding assistant.
            - Implementation: Provide clean, idiomatic, and well-commented code. 
            - Modifications: When updating code, use ````diff```` blocks to show clearly what is added (`+`) or removed (`-`).
            - Explanations: Explain design patterns and why code changes are necessary, kept concise.
            """
        case .slatePro:
            tierPrompt = """
            # Slate Pro Tier Protocol
            Act as an expert reasoning assistant.
            - Reasoning Protocol: Before generating your final answer, perform a step-by-step logical breakdown of the problem. 
            - Format: Place your step-by-step logic inside a block/header labeled `### 🧠 Reasoning` before providing your final response under `### 📝 Synthesis`. This forces the model to perform Chain-of-Thought (CoT) processing.
            """
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
