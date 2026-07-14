//
//  SlateMarkdownParser.swift
//  Slate
//
//  Unified markdown parser — single source of truth for Chat and Notes rendering.
//

import SwiftUI

// MARK: - Block Model

enum AlertStyle: String {
    case note = "NOTE"
    case tip = "TIP"
    case warning = "WARNING"
    case caution = "CAUTION"
    case important = "IMPORTANT"

    var color: Color {
        switch self {
        case .note, .important: return .blue
        case .tip:              return .green
        case .warning:          return .orange
        case .caution:          return .red
        }
    }

    var icon: String {
        switch self {
        case .note:      return "info.circle.fill"
        case .important: return "exclamationmark.circle.fill"
        case .tip:       return "lightbulb.fill"
        case .warning:   return "exclamationmark.triangle.fill"
        case .caution:   return "xmark.octagon.fill"
        }
    }
}

struct ChecklistItem: Identifiable {
    let id = UUID()
    let checked: Bool
    let text: String
}

struct ListItem: Identifiable {
    let id = UUID()
    let text: String
    let indent: Int
}

enum SlateBlock: Identifiable {
    var id: String {
        switch self {
        case .heading(let level, let text):     return "h\(level)-\(text.hashValue)"
        case .paragraph(let t):                 return "p-\(t.hashValue)"
        case .bulletList(let items):            return "ul-\(items.count)-\(items.first?.text.hashValue ?? 0)"
        case .numberedList(let items):          return "ol-\(items.count)-\(items.first?.text.hashValue ?? 0)"
        case .checklist(let items):             return "cl-\(items.count)-\(items.first?.text.hashValue ?? 0)"
        case .codeBlock(let lang, let code):    return "code-\(lang ?? "")-\(code.hashValue)"
        case .blockquote(let text):             return "bq-\(text.hashValue)"
        case .alert(let style, _, let body):    return "alert-\(style.rawValue)-\(body.hashValue)"
        case .table(let h, _):                  return "table-\(h.hashValue)"
        case .horizontalRule:                   return "hr-\(UUID().uuidString)"
        case .genui(let payload):               return "genui-\(payload.hashValue)"
        case .latex(let eq, let display):       return "latex-\(display)-\(eq.hashValue)"
        }
    }

    case heading(level: Int, text: String)
    case paragraph(String)
    case bulletList([ListItem])
    case numberedList([ListItem])
    case checklist([ChecklistItem])
    case codeBlock(language: String?, code: String)
    case blockquote(String)
    case alert(style: AlertStyle, title: String?, body: String)
    case table(headers: [String], rows: [[String]])
    case horizontalRule
    case genui(payload: String)
    case latex(equation: String, isDisplay: Bool)
}

// MARK: - Parser

enum SlateMarkdownParser {

    static func parse(_ raw: String) -> [SlateBlock] {
        var blocks: [SlateBlock] = []
        let lines = raw.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // ── GenUI tag ──────────────────────────────────────────────────
            if trimmed.hasPrefix("<genui>") || trimmed == "<genui>" {
                var payload = ""
                var j = i
                // Collect until </genui>
                var full = ""
                while j < lines.count {
                    full += lines[j] + "\n"
                    if lines[j].contains("</genui>") { break }
                    j += 1
                }
                payload = full
                    .replacingOccurrences(of: "<genui>", with: "")
                    .replacingOccurrences(of: "</genui>", with: "")
                    .replacingOccurrences(of: "<br>", with: "\n")
                    .replacingOccurrences(of: "<br/>", with: "\n")
                    .replacingOccurrences(of: "<br />", with: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(.genui(payload: payload))
                i = j + 1
                continue
            }

            // ── Display LaTeX $$...$$ ──────────────────────────────────────
            if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count > 4 {
                let eq = String(trimmed.dropFirst(2).dropLast(2))
                blocks.append(.latex(equation: eq, isDisplay: true))
                i += 1
                continue
            }

            // ── Multi-line display LaTeX ───────────────────────────────────
            if trimmed == "$$" {
                var eqLines: [String] = []
                i += 1
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces) != "$$" {
                    eqLines.append(lines[i])
                    i += 1
                }
                blocks.append(.latex(equation: eqLines.joined(separator: "\n"), isDisplay: true))
                i += 1 // skip closing $$
                continue
            }

            // ── Inline LaTeX $...$ in standalone paragraph ─────────────────
            if trimmed.hasPrefix("$") && trimmed.hasSuffix("$") && !trimmed.hasPrefix("$$") && trimmed.count > 2 {
                let eq = String(trimmed.dropFirst().dropLast())
                blocks.append(.latex(equation: eq, isDisplay: false))
                i += 1
                continue
            }

            // ── Fenced code block ──────────────────────────────────────────
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(language: lang.isEmpty ? nil : lang, code: codeLines.joined(separator: "\n")))
                i += 1 // skip closing ```
                continue
            }

            // ── Horizontal rule ────────────────────────────────────────────
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // ── Heading ────────────────────────────────────────────────────
            if trimmed.hasPrefix("#") {
                var level = 0
                var rest = trimmed
                while rest.hasPrefix("#") { level += 1; rest = String(rest.dropFirst()) }
                let headingText = rest.trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 6), text: headingText))
                i += 1
                continue
            }

            // ── Alert card (GitHub-flavored blockquote) ────────────────────
            // Matches: > [!NOTE], > [!TIP], etc.
            if trimmed.hasPrefix("> [!") {
                let alertMatch = parseAlert(lines: lines, startIndex: i)
                blocks.append(alertMatch.block)
                i = alertMatch.nextIndex
                continue
            }

            // ── Blockquote ─────────────────────────────────────────────────
            if trimmed.hasPrefix(">") {
                var bqLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    let stripped = lines[i].trimmingCharacters(in: .whitespaces)
                    bqLines.append(String(stripped.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.blockquote(bqLines.joined(separator: "\n")))
                continue
            }

            // ── Table ──────────────────────────────────────────────────────
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                let tableResult = parseTable(lines: lines, startIndex: i)
                if let block = tableResult.block {
                    blocks.append(block)
                    i = tableResult.nextIndex
                    continue
                }
            }

            // ── Checklist (must come before bullet) ────────────────────────
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                var items: [ChecklistItem] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("- [ ]") {
                        items.append(ChecklistItem(checked: false, text: String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces)))
                        i += 1
                    } else if t.hasPrefix("- [x]") || t.hasPrefix("- [X]") {
                        items.append(ChecklistItem(checked: true, text: String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces)))
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty { blocks.append(.checklist(items)) }
                continue
            }

            // ── Bullet list ────────────────────────────────────────────────
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var items: [ListItem] = []
                while i < lines.count {
                    let rawLine = lines[i]
                    let t = rawLine.trimmingCharacters(in: .whitespaces)
                    let indent = rawLine.prefix(while: { $0 == " " }).count / 2
                    if t.hasPrefix("- ") {
                        items.append(ListItem(text: String(t.dropFirst(2)), indent: indent))
                        i += 1
                    } else if t.hasPrefix("* ") || t.hasPrefix("+ ") {
                        items.append(ListItem(text: String(t.dropFirst(2)), indent: indent))
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty { blocks.append(.bulletList(items)) }
                continue
            }

            // ── Numbered list ──────────────────────────────────────────────
            if let _ = trimmed.range(of: #"^\d+\. "#, options: .regularExpression) {
                var items: [ListItem] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if let range = t.range(of: #"^\d+\. "#, options: .regularExpression) {
                        items.append(ListItem(text: String(t[range.upperBound...]), indent: 0))
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty { blocks.append(.numberedList(items)) }
                continue
            }

            // ── Empty line — skip ──────────────────────────────────────────
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // ── Paragraph (collect consecutive non-empty, non-special lines) ─
            var paraLines: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty { break }
                if isSpecialLine(t) && !paraLines.isEmpty { break }
                paraLines.append(t)
                i += 1
            }
            let joined = paraLines.joined(separator: " ")
            if !joined.isEmpty { blocks.append(.paragraph(joined)) }
        }

        return blocks
    }

    // MARK: - Helpers

    private static func isSpecialLine(_ t: String) -> Bool {
        return t.hasPrefix("#") || t.hasPrefix("```") || t.hasPrefix(">") ||
               t.hasPrefix("- [ ]") || t.hasPrefix("- [x]") || t.hasPrefix("- [X]") ||
               t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") ||
               t.hasPrefix("|") || t.hasPrefix("<genui>") ||
               t.hasPrefix("$$") || t == "---" || t == "***" || t == "___" ||
               (t.range(of: #"^\d+\. "#, options: .regularExpression) != nil)
    }

    private static func parseAlert(lines: [String], startIndex: Int) -> (block: SlateBlock, nextIndex: Int) {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        // Extract style: > [!NOTE], > [!TIP], etc.
        var styleStr = ""
        if let match = trimmed.range(of: #"(?<=\[!)[\w]+"#, options: .regularExpression) {
            styleStr = String(trimmed[match])
        }
        let style = AlertStyle(rawValue: styleStr.uppercased()) ?? .note

        var bodyLines: [String] = []
        var i = startIndex + 1
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix(">") {
                bodyLines.append(String(t.dropFirst()).trimmingCharacters(in: .whitespaces))
                i += 1
            } else {
                break
            }
        }
        return (.alert(style: style, title: nil, body: bodyLines.joined(separator: "\n")), i)
    }

    private static func parseTable(lines: [String], startIndex: Int) -> (block: SlateBlock?, nextIndex: Int) {
        var i = startIndex
        guard i < lines.count else { return (nil, startIndex + 1) }

        // Parse header row
        let headerLine = lines[i].trimmingCharacters(in: .whitespaces)
        let headers = headerLine
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        i += 1

        // Skip separator row (---|---|---)
        if i < lines.count {
            let sepLine = lines[i].trimmingCharacters(in: .whitespaces)
            if sepLine.contains("---") || sepLine.contains(":--") || sepLine.contains("--:") {
                i += 1
            }
        }

        // Parse data rows
        var rows: [[String]] = []
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("|") && t.hasSuffix("|") else { break }
            let cells = t
                .split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            rows.append(cells)
            i += 1
        }

        guard !headers.isEmpty else { return (nil, i) }
        return (.table(headers: headers, rows: rows), i)
    }
}
