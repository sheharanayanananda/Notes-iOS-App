//
//  MarkdownParser.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI
import Foundation

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
    static let uColorRegex = try? NSRegularExpression(pattern: #"(?i)<u\s+style="color:\s*([^";\s>]+);?\s*">(.*?)</u>"#, options: [])
    static let uPlainRegex = try? NSRegularExpression(pattern: #"(?i)<u>(.*?)</u>"#, options: [])
}

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
                    let suffix = trimmed.dropFirst(level)
                    if suffix.hasPrefix(" ") || suffix.isEmpty {
                        flushAll()
                        let headerText = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
                        blocks.append(.header(level: level, text: headerText))
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
                    var stripped = String(contentText.trimmingCharacters(in: .whitespaces).dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Strip redundant bullets/dashes if present (e.g. "- [ ] - text" or "- [ ] * text")
                    while true {
                        let initial = stripped
                        for prefix in ["- ", "– ", "— ", "* ", "• ", "-", "–", "—", "*", "•"] {
                            if stripped.hasPrefix(prefix) {
                                stripped = String(stripped.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                        if stripped == initial { break }
                    }
                    
                    contentText = stripped
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
            
            // 7. Plain Paragraph (Flushing immediately on newline)
            if !trimmed.isEmpty {
                currentParagraphLines.append(line)
                flushParagraph()
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
