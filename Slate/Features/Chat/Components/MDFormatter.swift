//
//  MarkdownFormatter.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-21.
//

import SwiftUI
import Foundation

// MARK: - Performance Cache & Regex Cache

final class MarkdownCache {
    private static let lock = NSRecursiveLock()
    private static var parseCache: [String: [MarkdownBlock]] = [:]
    private static var inlineCache: [String: Text] = [:]
    private static let maxParseCacheSize = 100
    private static let maxInlineCacheSize = 400
    
    private static var parseKeys: [String] = []
    private static var inlineKeys: [String] = []
    
    static func getBlocks(for text: String) -> [MarkdownBlock]? {
        lock.lock()
        defer { lock.unlock() }
        return parseCache[text]
    }
    
    static func setBlocks(_ blocks: [MarkdownBlock], for text: String) {
        lock.lock()
        defer { lock.unlock() }
        if parseCache[text] == nil {
            parseKeys.append(text)
            if parseKeys.count > maxParseCacheSize {
                let oldestKey = parseKeys.removeFirst()
                parseCache.removeValue(forKey: oldestKey)
            }
        }
        parseCache[text] = blocks
    }
    
    static func getInlineText(for text: String) -> Text? {
        lock.lock()
        defer { lock.unlock() }
        return inlineCache[text]
    }
    
    static func setInlineText(_ textObj: Text, for text: String) {
        lock.lock()
        defer { lock.unlock() }
        if inlineCache[text] == nil {
            inlineKeys.append(text)
            if inlineKeys.count > maxInlineCacheSize {
                let oldestKey = inlineKeys.removeFirst()
                inlineCache.removeValue(forKey: oldestKey)
            }
        }
        inlineCache[text] = textObj
    }
}

enum RegexCache {
    static let strikethroughRegex = try? NSRegularExpression(pattern: "~~(.*?)~~", options: [])
    static let emailRegex = try? Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")
    static let urlRegex = try? Regex("https?://[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}(/[A-Za-z0-9._%/=&?#~+-]*)*")
}

// MARK: - Markdown Models

enum TableColumnAlignment: String, CaseIterable, Identifiable, Codable {
    case leading
    case center
    case trailing
    
    var id: String { self.rawValue }
}

enum AlertType: String, CaseIterable, Codable {
    case note = "NOTE"
    case tip = "TIP"
    case important = "IMPORTANT"
    case warning = "WARNING"
    case caution = "CAUTION"
    
    var iconName: String {
        switch self {
        case .note: return "info.circle.fill"
        case .tip: return "lightbulb.fill"
        case .important: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .caution: return "flame.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .note: return .blue
        case .tip: return .orange
        case .important: return .purple
        case .warning: return .yellow
        case .caution: return .red
        }
    }
}

enum MarkdownBlock: Identifiable, Equatable {
    var id: String {
        switch self {
        case .paragraph(let text): return "p-\(text.hashValue)"
        case .header(let level, let text): return "h-\(level)-\(text.hashValue)"
        case .blockquote(let nestedBlocks): return "bq-\(nestedBlocks.map { $0.id }.joined().hashValue)"
        case .list(let items): return "list-\(items.map { $0.text }.joined().hashValue)"
        case .code(_, let code): return "code-\(code.hashValue)"
        case .table(let headers, _, let rows): return "table-\((headers.joined() + rows.flatMap { $0 }.joined()).hashValue)"
        case .thematicBreak: return "hr"
        case .latex(let isDisplay, let equation): return "latex-\(isDisplay)-\(equation.hashValue)"
        case .alert(let type, let blocks): return "alert-\(type.rawValue)-\(blocks.map { $0.id }.joined().hashValue)"
        case .image(let caption, let url): return "img-\(caption.hashValue)-\(url.hashValue)"
        }
    }
    
    var isBlockElement: Bool {
        switch self {
        case .paragraph: return false
        default: return true
        }
    }
    
    case paragraph(text: String)
    case header(level: Int, text: String)
    case blockquote(blocks: [MarkdownBlock])
    case list(items: [MarkdownListItem])
    case code(language: String?, code: String)
    case table(headers: [String], alignments: [TableColumnAlignment], rows: [[String]])
    case thematicBreak
    case latex(isDisplay: Bool, equation: String)
    case alert(type: AlertType, blocks: [MarkdownBlock])
    case image(caption: String, urlString: String)
}

struct MarkdownListItem: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let type: ListType
    let checkboxState: CheckboxState?
    let text: String
    
    enum ListType: Equatable {
        case bullet
        case numbered(number: Int)
    }
    
    enum CheckboxState: Equatable {
        case checked
        case unchecked
    }
}

// MARK: - Markdown Parser

struct MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        if let cached = MarkdownCache.getBlocks(for: text) {
            return cached
        }
        let parsed = parseRaw(text)
        MarkdownCache.setBlocks(parsed, for: text)
        return parsed
    }
    
    private static func parseRaw(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentCodeBlock: (language: String?, lines: [String])? = nil
        var currentLaTeXBlock: [String]? = nil
        var currentBlockquoteLines: [String] = []
        var currentListItems: [MarkdownListItem] = []
        var currentTableLines: [String] = []
        var currentParagraphLines: [String] = []
        
        func flushParagraph() {
            guard !currentParagraphLines.isEmpty else { return }
            let paragraphText = currentParagraphLines.joined(separator: "\n")
            let trimmed = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect display math blocks starting/ending with $$
            if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count >= 4 {
                let equation = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(.latex(isDisplay: true, equation: equation))
            } else if trimmed.hasPrefix("$") && trimmed.hasSuffix("$") && trimmed.count >= 2 && !trimmed.contains("\n") {
                let equation = String(trimmed.dropFirst(1).dropLast(1)).trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(.latex(isDisplay: false, equation: equation))
            } else {
                blocks.append(.paragraph(text: paragraphText))
            }
            currentParagraphLines.removeAll()
        }
        
        func flushBlockquote() {
            guard !currentBlockquoteLines.isEmpty else { return }
            
            // Check if this blockquote is a GitHub-style alert callout
            let blockquoteText = currentBlockquoteLines.joined(separator: "\n")
            let trimmedText = blockquoteText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedText.hasPrefix("[!") {
                if let closeBracketIdx = trimmedText.firstIndex(of: "]") {
                    let typeStart = trimmedText.index(trimmedText.startIndex, offsetBy: 2)
                    let typeStr = String(trimmedText[typeStart..<closeBracketIdx]).uppercased()
                    
                    if let alertType = AlertType(rawValue: typeStr) {
                        let contentStart = trimmedText.index(after: closeBracketIdx)
                        let remainingContent = String(trimmedText[contentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let alertBlocks = MarkdownParser.parse(remainingContent)
                        blocks.append(.alert(type: alertType, blocks: alertBlocks))
                        currentBlockquoteLines.removeAll()
                        return
                    }
                }
            }
            
            let nested = MarkdownParser.parse(blockquoteText)
            blocks.append(.blockquote(blocks: nested))
            currentBlockquoteLines.removeAll()
        }
        
        func flushList() {
            guard !currentListItems.isEmpty else { return }
            blocks.append(.list(items: currentListItems))
            currentListItems.removeAll()
        }
        
        func flushTable() {
            guard !currentTableLines.isEmpty else { return }
            if let tableBlock = parseTableRaw(currentTableLines) {
                blocks.append(tableBlock)
            } else {
                // Fallback to paragraphs if table parsing fails
                for line in currentTableLines {
                    blocks.append(.paragraph(text: line))
                }
            }
            currentTableLines.removeAll()
        }
        
        func flushAll() {
            flushParagraph()
            flushBlockquote()
            flushList()
            flushTable()
        }
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Single-line LaTeX Display Math Block
            if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count >= 4 {
                flushAll()
                let equation = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(.latex(isDisplay: true, equation: equation))
                i += 1
                continue
            }
            
            // Single-line LaTeX Inline Math Block
            if trimmed.hasPrefix("$") && trimmed.hasSuffix("$") && !trimmed.hasPrefix("$$") && trimmed.count >= 2 {
                flushAll()
                let equation = String(trimmed.dropFirst(1).dropLast(1)).trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(.latex(isDisplay: false, equation: equation))
                i += 1
                continue
            }
            
            // Image Block Detection
            if trimmed.hasPrefix("![") && trimmed.contains("](") && trimmed.hasSuffix(")") {
                flushAll()
                if let closeBracketIdx = trimmed.firstIndex(of: "]"),
                   let openParenIdx = trimmed.firstIndex(of: "(") {
                    let captionStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
                    let caption = String(trimmed[captionStart..<closeBracketIdx])
                    
                    let urlStart = trimmed.index(after: openParenIdx)
                    let urlEnd = trimmed.index(before: trimmed.endIndex)
                    let urlString = String(trimmed[urlStart..<urlEnd])
                    
                    blocks.append(.image(caption: caption, urlString: urlString))
                    i += 1
                    continue
                }
            }
            
            // 1. Code Blocks
            if trimmed.hasPrefix("```") {
                if let codeBlock = currentCodeBlock {
                    // Close the code block
                    blocks.append(.code(language: codeBlock.language, code: codeBlock.lines.joined(separator: "\n")))
                    currentCodeBlock = nil
                } else {
                    // Open a new code block
                    flushAll()
                    let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    currentCodeBlock = (language: language.isEmpty ? nil : language, lines: [])
                }
                i += 1
                continue
            }
            
            if let codeBlock = currentCodeBlock {
                var newLines = codeBlock.lines
                newLines.append(line)
                currentCodeBlock = (language: codeBlock.language, lines: newLines)
                i += 1
                continue
            }
            
            // 1.5. LaTeX Display Math Blocks (Multi-line)
            if (trimmed.hasPrefix("$$") && !trimmed.hasSuffix("$$")) || (trimmed == "$$" && currentLaTeXBlock == nil) {
                if let latexBlock = currentLaTeXBlock {
                    let equation = latexBlock.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    blocks.append(.latex(isDisplay: true, equation: equation))
                    currentLaTeXBlock = nil
                } else {
                    flushAll()
                    let equationContent = String(trimmed.dropFirst(2))
                    currentLaTeXBlock = [equationContent]
                }
                i += 1
                continue
            } else if (trimmed.hasSuffix("$$") && !trimmed.hasPrefix("$$")) || (trimmed == "$$" && currentLaTeXBlock != nil) {
                if var latexBlock = currentLaTeXBlock {
                    if trimmed != "$$" {
                        latexBlock.append(String(trimmed.dropLast(2)))
                    }
                    let equation = latexBlock.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    blocks.append(.latex(isDisplay: true, equation: equation))
                    currentLaTeXBlock = nil
                }
                i += 1
                continue
            }
            
            if let latexBlock = currentLaTeXBlock {
                var newLines = latexBlock
                newLines.append(line)
                currentLaTeXBlock = newLines
                i += 1
                continue
            }
            
            // 2. Blockquotes
            if line.hasPrefix(">") {
                flushParagraph()
                flushList()
                flushTable()
                
                // Extract blockquote line content
                let contentIndex = line.index(after: line.startIndex)
                let blockquoteLine = String(line[contentIndex...])
                
                // Strip one leading space if present
                let formattedLine = blockquoteLine.hasPrefix(" ") ? String(blockquoteLine.dropFirst()) : blockquoteLine
                currentBlockquoteLines.append(formattedLine)
                i += 1
                continue
            } else if !currentBlockquoteLines.isEmpty {
                flushBlockquote()
            }
            
            // 3. Horizontal Rules (Thematic Breaks)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushAll()
                blocks.append(.thematicBreak)
                i += 1
                continue
            }
            
            // 4. Headers
            if trimmed.hasPrefix("#") {
                var level = 0
                for char in trimmed {
                    if char == "#" { level += 1 }
                    else { break }
                }
                if level > 0 && level <= 6 {
                    let contentStart = trimmed.index(trimmed.startIndex, offsetBy: level)
                    let headerText = String(trimmed[contentStart...]).trimmingCharacters(in: .whitespaces)
                    if headerText.first == " " || headerText.isEmpty {
                        flushAll()
                        blocks.append(.header(level: level, text: headerText.trimmingCharacters(in: .whitespacesAndNewlines)))
                        i += 1
                        continue
                    }
                }
            }
            
            // 5. Lists (unordered, ordered, tasks)
            let leadingSpaces = line.prefix(while: { $0 == " " })
            let level = leadingSpaces.count / 2
            
            var isListItem = false
            var listType: MarkdownListItem.ListType = .bullet
            var checkboxState: MarkdownListItem.CheckboxState? = nil
            
            // Check for unordered list (- or *)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                isListItem = true
                listType = .bullet
                
                // Detect tasks checklist
                let taskText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if taskText.hasPrefix("[ ]") {
                    checkboxState = .unchecked
                } else if taskText.hasPrefix("[x]") {
                    checkboxState = .checked
                }
            } else if let numberMatch = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                // Check for ordered list
                let prefix = String(trimmed[numberMatch])
                if let number = Int(prefix.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".")))) {
                    isListItem = true
                    listType = .numbered(number: number)
                }
            }
            
            if isListItem {
                flushParagraph()
                flushBlockquote()
                flushTable()
                
                var contentText = ""
                switch listType {
                case .bullet:
                    contentText = String(trimmed.dropFirst(2))
                case .numbered(let number):
                    contentText = String(trimmed.dropFirst(String(number).count + 2))
                }
                
                if checkboxState != nil {
                    // Strip the checkbox prefix [ ] or [x] from contentText
                    contentText = String(contentText.trimmingCharacters(in: .whitespaces).dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                currentListItems.append(MarkdownListItem(
                    level: level,
                    type: listType,
                    checkboxState: checkboxState,
                    text: contentText
                ))
                i += 1
                continue
            } else if !currentListItems.isEmpty && leadingSpaces.count >= 2 && !trimmed.isEmpty {
                // Continuation line for the active list item (e.g. indented table or code block)
                let lastIdx = currentListItems.count - 1
                let continuationText = String(line.dropFirst(2))
                currentListItems[lastIdx] = MarkdownListItem(
                    level: currentListItems[lastIdx].level,
                    type: currentListItems[lastIdx].type,
                    checkboxState: currentListItems[lastIdx].checkboxState,
                    text: currentListItems[lastIdx].text + "\n" + continuationText
                )
                i += 1
                continue
            } else if !currentListItems.isEmpty {
                flushList()
            }
            
            // 6. Tables
            if trimmed.hasPrefix("|") || (trimmed.contains("|") && i < lines.count - 1 && lines[i+1].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("|")) {
                flushParagraph()
                flushBlockquote()
                flushList()
                
                currentTableLines.append(line)
                i += 1
                continue
            } else if !currentTableLines.isEmpty {
                flushTable()
            }
            
            // 7. Plain Paragraph (Accumulating text lines)
            if !trimmed.isEmpty {
                currentParagraphLines.append(line)
            } else {
                flushParagraph()
            }
            
            i += 1
        }
        
        flushAll()
        return blocks
    }
    
    private static func parseTableRaw(_ lines: [String]) -> MarkdownBlock? {
        guard lines.count >= 2 else { return nil }
        
        let headerLine = lines[0]
        let separatorLine = lines[1]
        
        let headers = headerLine.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let separators = separatorLine.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Remove empty edge cells if using pipe borders
        var cleanedHeaders = headers
        if headerLine.hasPrefix("|") && !cleanedHeaders.isEmpty {
            cleanedHeaders.removeFirst()
        }
        if headerLine.hasSuffix("|") && !cleanedHeaders.isEmpty {
            cleanedHeaders.removeLast()
        }
        
        var cleanedSeparators = separators
        if separatorLine.hasPrefix("|") && !cleanedSeparators.isEmpty {
            cleanedSeparators.removeFirst()
        }
        if separatorLine.hasSuffix("|") && !cleanedSeparators.isEmpty {
            cleanedSeparators.removeLast()
        }
        
        // Verify separator syntax (contains dashes and optional colons)
        for sep in cleanedSeparators {
            let stripped = sep.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
            if !stripped.isEmpty {
                return nil // Not a valid separator line
            }
        }
        
        // Determine column alignment
        var alignments: [TableColumnAlignment] = []
        for sep in cleanedSeparators {
            let hasStartColon = sep.hasPrefix(":")
            let hasEndColon = sep.hasSuffix(":")
            if hasStartColon && hasEndColon {
                alignments.append(.center)
            } else if hasEndColon {
                alignments.append(.trailing)
            } else {
                alignments.append(.leading)
            }
        }
        
        // Fill up rows
        var rows: [[String]] = []
        for j in 2..<lines.count {
            let rowLine = lines[j]
            let cells = rowLine.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            var cleanedCells = cells
            if rowLine.hasPrefix("|") && !cleanedCells.isEmpty {
                cleanedCells.removeFirst()
            }
            if rowLine.hasSuffix("|") && !cleanedCells.isEmpty {
                cleanedCells.removeLast()
            }
            rows.append(cleanedCells)
        }
        
        return .table(headers: cleanedHeaders, alignments: alignments, rows: rows)
    }
}

// MARK: - Inline Formatting View

enum InlineToken: Equatable {
    case text(String)
    case inlineMath(String)
    case displayMath(String)
}

func tokenize(_ text: String) -> [InlineToken] {
    var processedText = text
    let dollarCount = text.filter { $0 == "$" }.count
    if dollarCount % 2 != 0 {
        if text.contains("\\text") || text.contains("\\quad") || text.contains("\\") {
            processedText.append("$")
        }
    }
    
    var tokens: [InlineToken] = []
    var currentText = ""
    let characters = Array(processedText)
    var i = 0
    var insideCode = false
    
    while i < characters.count {
        if characters[i] == "`" {
            insideCode.toggle()
            currentText.append("`")
            i += 1
        } else if !insideCode && i < characters.count - 1 && characters[i] == "$" && characters[i+1] == "$" {
            if !currentText.isEmpty {
                tokens.append(.text(currentText))
                currentText = ""
            }
            
            var j = i + 2
            var found = false
            while j < characters.count - 1 {
                if characters[j] == "$" && characters[j+1] == "$" {
                    found = true
                    break
                }
                j += 1
            }
            
            if found {
                let formula = String(characters[(i+2)..<j])
                tokens.append(.displayMath(formula))
                i = j + 2
            } else {
                currentText.append("$$")
                i += 2
            }
        } else if !insideCode && characters[i] == "$" {
            if !currentText.isEmpty {
                tokens.append(.text(currentText))
                currentText = ""
            }
            
            var j = i + 1
            var found = false
            while j < characters.count {
                if characters[j] == "$" {
                    found = true
                    break
                }
                j += 1
            }
            
            if found {
                let formula = String(characters[(i+1)..<j])
                tokens.append(.inlineMath(formula))
                i = j + 1
            } else {
                currentText.append("$")
                i += 1
            }
        } else {
            currentText.append(characters[i])
            i += 1
        }
    }
    
    if !currentText.isEmpty {
        tokens.append(.text(currentText))
    }
    
    return tokens
}

func formatMathString(_ formula: String) -> String {
    var result = formula
    
    // Replace \text{some content} with "some content"
    if let regex = try? NSRegularExpression(pattern: #"\\text\{([^}]+)\}"#, options: []) {
        let range = NSRange(result.startIndex..., in: result)
        result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
    }
    
    let superscripts = [
        "^0": "⁰", "^1": "¹", "^2": "²", "^3": "³", "^4": "⁴",
        "^5": "⁵", "^6": "⁶", "^7": "⁷", "^8": "⁸", "^9": "⁹",
        "^+": "⁺", "^-": "⁻", "^=": "⁼", "^(": "⁽", "^)": "⁾",
        "^n": "ⁿ", "^x": "ˣ", "^i": "ⁱ"
    ]
    let subscripts = [
        "_0": "₀", "_1": "₁", "_2": "₂", "_3": "₃", "_4": "₄",
        "_5": "₅", "_6": "₆", "_7": "₇", "_8": "₈", "_9": "₉",
        "_+": "₊", "_-": "₋", "_=": "₌", "_(": "₍", "_)": "₎"
    ]
    let symbols = [
        "\\pm": "±", "\\times": "×", "\\div": "÷", "\\alpha": "α",
        "\\beta": "β", "\\gamma": "γ", "\\theta": "θ", "\\pi": "π",
        "\\infty": "∞", "\\neq": "≠", "\\leq": "≤", "\\geq": "≥",
        "\\delta": "δ", "\\lambda": "λ", "\\mu": "μ", "\\sigma": "σ",
        "\\phi": "φ", "\\omega": "ω", "\\partial": "∂", "\\nabla": "∇",
        "\\sum": "∑", "\\prod": "∏", "\\int": "∫", "\\sqrt": "√",
        "\\approx": "≈", "\\propto": "∝", "\\langle": "⟨", "\\rangle": "⟩",
        "\\hbar": "ħ", "\\implies": "⟹", "\\to": "→", "\\psi": "ψ", "\\Psi": "Ψ",
        "\\rightarrow": "→", "\\leftarrow": "←", "\\leftrightarrow": "↔",
        "\\uparrow": "↑", "\\downarrow": "↓", "\\cdot": "·", "\\bullet": "•",
        "\\checkmark": "✓", "\\quad": "  ", "\\qquad": "    "
    ]
    
    for (key, val) in superscripts {
        result = result.replacingOccurrences(of: key, with: val)
    }
    for (key, val) in subscripts {
        result = result.replacingOccurrences(of: key, with: val)
    }
    for (key, val) in symbols {
        result = result.replacingOccurrences(of: key, with: val)
    }
    
    return result
}

struct FormattedText: View {
    @Environment(\.markdownStrikethrough) private var isStrikethrough
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        let elements = preprocess(content)
        
        VStack(alignment: .leading, spacing: 6) {
            ForEach(elements) { element in
                switch element.type {
                case .inline(let tokens):
                    renderInline(tokens)
                case .display(let formula):
                    LaTeXMathView(equation: formula, isDisplay: true)
                }
            }
        }
    }
    
    private struct ParagraphElement: Identifiable {
        let id = UUID()
        enum ElementType {
            case inline([InlineToken])
            case display(String)
        }
        let type: ElementType
    }
    
    private func preprocess(_ text: String) -> [ParagraphElement] {
        let tokens = tokenize(text)
        var elements: [ParagraphElement] = []
        var currentInline: [InlineToken] = []
        
        for token in tokens {
            switch token {
            case .displayMath(let formula):
                if !currentInline.isEmpty {
                    elements.append(ParagraphElement(type: .inline(currentInline)))
                    currentInline.removeAll()
                }
                elements.append(ParagraphElement(type: .display(formula)))
            default:
                currentInline.append(token)
            }
        }
        
        if !currentInline.isEmpty {
            elements.append(ParagraphElement(type: .inline(currentInline)))
        }
        
        return elements
    }
    
    private func renderInline(_ tokens: [InlineToken]) -> Text {
        var result = Text("")
        for token in tokens {
            switch token {
            case .text(let str):
                result = Text("\(result)\(parseInlineMarkdown(str))")
            case .inlineMath(let formula):
                let formatted = formatMathString(formula)
                let mathText = Text(formatted)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .italic()
                result = Text("\(result)\(mathText)")
            default:
                break
            }
        }
        if isStrikethrough {
            return result.strikethrough(true)
        }
        return result
    }
    
    private func parseInlineMarkdown(_ text: String) -> Text {
        if let cached = MarkdownCache.getInlineText(for: text) {
            return cached
        }
        let parsed = FormattedText.parseInlineMarkdownRaw(text)
        MarkdownCache.setInlineText(parsed, for: text)
        return parsed
    }
    
    fileprivate static func parseInlineMarkdownRaw(_ text: String) -> Text {
        var cleanText = text
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            
        if let regex = RegexCache.strikethroughRegex {
            let range = NSRange(cleanText.startIndex..., in: cleanText)
            cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: "[$1](strikethrough://true)")
        }
        
        var options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        options.allowsExtendedAttributes = true
        
        if var attrStr = try? AttributedString(markdown: cleanText, options: options) {
            for run in attrStr.runs {
                if let link = run.link, link.scheme == "strikethrough" {
                    attrStr[run.range].link = nil
                    attrStr[run.range].strikethroughStyle = .single
                }
                
                if run.inlinePresentationIntent?.contains(.code) == true {
                    attrStr[run.range].foregroundColor = .primary
                    attrStr[run.range].backgroundColor = Color.primary.opacity(0.08)
                    let isBold = run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
                    let isItalic = run.inlinePresentationIntent?.contains(.emphasized) == true
                    var font = Font.system(size: 14, weight: isBold ? .bold : .medium, design: .monospaced)
                    if isItalic {
                        font = font.italic()
                    }
                    attrStr[run.range].font = font
                }
            }
            
            // Auto-linkify emails
            if let emailRegex = RegexCache.emailRegex {
                let matches = cleanText.matches(of: emailRegex)
                for match in matches {
                    let range = match.range
                    if let startIdx = AttributedString.Index(range.lowerBound, within: attrStr),
                       let endIdx = AttributedString.Index(range.upperBound, within: attrStr) {
                        let attrRange = startIdx..<endIdx
                        let email = String(cleanText[range])
                        if let mailURL = URL(string: "mailto:\(email)") {
                            attrStr[attrRange].link = mailURL
                            // Clear code formatting so it displays as standard blue link
                            attrStr[attrRange].foregroundColor = .blue
                            attrStr[attrRange].backgroundColor = nil
                            attrStr[attrRange].font = nil
                            attrStr[attrRange].inlinePresentationIntent = nil
                        }
                    }
                }
            }
            
            // Auto-linkify raw URLs (excluding ones already in links)
            if let urlRegex = RegexCache.urlRegex {
                let matches = cleanText.matches(of: urlRegex)
                for match in matches {
                    let range = match.range
                    if let startIdx = AttributedString.Index(range.lowerBound, within: attrStr),
                       let endIdx = AttributedString.Index(range.upperBound, within: attrStr) {
                        let attrRange = startIdx..<endIdx
                        if attrStr[attrRange].link == nil {
                            let urlStr = String(cleanText[range])
                            if let url = URL(string: urlStr) {
                                attrStr[attrRange].link = url
                                attrStr[attrRange].foregroundColor = .blue
                                attrStr[attrRange].backgroundColor = nil
                                attrStr[attrRange].font = nil
                                attrStr[attrRange].inlinePresentationIntent = nil
                            }
                        }
                    }
                }
            }
            
            return Text(attrStr)
        } else {
            return Text(cleanText)
        }
    }
}

func isRTL(_ text: String) -> Bool {
    guard let firstLetter = text.first(where: { $0.isLetter }) else { return false }
    for scalar in firstLetter.unicodeScalars {
        let value = scalar.value
        if (value >= 0x0590 && value <= 0x05FF) || // Hebrew
           (value >= 0x0600 && value <= 0x06FF) || // Arabic
           (value >= 0x0750 && value <= 0x077F) || // Arabic Supplement
           (value >= 0x08A0 && value <= 0x08FF) {   // Arabic Extended-A
            return true
        }
    }
    return false
}
