//
//  SlateBlockView.swift
//  Slate
//
//  Renders a single SlateBlock as a native SwiftUI view.
//  Used in both Chat (MessageView) and Notes (CreateTabView preview).
//

import SwiftUI

// MARK: - Inline Formatting Helper

/// Converts markdown inline syntax to AttributedString.
/// Handles **bold**, *italic*, `code`, ~~strikethrough~~, <u>underline</u>, and $math$ variables.
func slateAttributedString(_ raw: String) -> AttributedString {
    // 1. Process inline math: replace $x$ with *x* to italicize it
    var processed = raw
    let mathPattern = #"\\?(?<!\$)\$(?!\s)(.+?)(?<!\s)\$(?!\$)"#
    if let regex = try? NSRegularExpression(pattern: mathPattern, options: []) {
        let range = NSRange(processed.startIndex..., in: processed)
        processed = regex.stringByReplacingMatches(in: processed, options: [], range: range, withTemplate: "*$1*")
    }

    // 2. Parse Markdown
    var options = AttributedString.MarkdownParsingOptions()
    options.interpretedSyntax = .inlineOnlyPreservingWhitespace
    options.failurePolicy = .returnPartiallyParsedIfPossible
    
    var attrStr = (try? AttributedString(
        markdown: processed,
        options: options
    )) ?? AttributedString(processed)

    // 3. Process underline <u>...</u> tags
    while let startRange = attrStr.range(of: "<u>"),
          let endRange = attrStr.range(of: "</u>") {
        if startRange.lowerBound < endRange.lowerBound {
            let textRange = startRange.upperBound..<endRange.lowerBound
            attrStr[textRange].underlineStyle = .single
            
            // Remove the tags in reverse order to preserve indexes
            attrStr.removeSubrange(endRange)
            attrStr.removeSubrange(startRange)
        } else {
            break
        }
    }

    return attrStr
}

func containsRichLaTeX(_ text: String) -> Bool {
    guard text.contains("$") else { return false }
    // A block of text containing '$' has math. If it also contains backslashes '\'
    // or subscripts/superscripts like '_', '^', it's a real LaTeX expression which
    // must be rendered by KaTeX. Simple single-letter variables can be handled by AttributedString.
    return text.contains("\\") || text.contains("_") || text.contains("^")
}

// MARK: - Individual Block Views

// ── Heading ────────────────────────────────────────────────────────────────

struct SlateHeadingView: View {
    let level: Int
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(headingFont)
                .fontWeight(level <= 2 ? .bold : .semibold)
                .tracking(level == 1 ? -0.3 : 0)
                .foregroundStyle(.primary)

            if level == 1 {
                Divider()
                    .padding(.top, 2)
            }
        }
        .padding(.top, level == 1 ? 18 : (level == 2 ? 14 : 10))
        .padding(.bottom, level == 1 ? 6 : (level == 2 ? 4 : 2))
    }

    private var headingFont: Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        case 5: return .subheadline
        default: return .footnote
        }
    }
}

// ── Paragraph ──────────────────────────────────────────────────────────────

struct SlateParagraphView: View {
    let text: String

    var body: some View {
        if containsRichLaTeX(text) {
            LaTeXMathView(equation: text, isDisplay: false)
        } else {
            Text(slateAttributedString(text))
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// ── Checklist ──────────────────────────────────────────────────────────────

struct SlateChecklistView: View {
    let items: [ChecklistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(item.checked ? Color.blue : Color.secondary.opacity(0.55))
                        .padding(.top, 1)

                    if containsRichLaTeX(item.text) {
                        LaTeXMathView(equation: item.text, isDisplay: false)
                    } else {
                        Text(slateAttributedString(item.text))
                            .font(.body)
                            .lineSpacing(4)
                            .foregroundStyle(item.checked ? .secondary : .primary)
                            .strikethrough(item.checked, color: .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// ── Bullet List ────────────────────────────────────────────────────────────

struct SlateBulletListView: View {
    let items: [ListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 0)

                    if containsRichLaTeX(item.text) {
                        LaTeXMathView(equation: item.text, isDisplay: false)
                    } else {
                        Text(slateAttributedString(item.text))
                            .font(.body)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, CGFloat(item.indent * 16))
            }
        }
    }
}

// ── Numbered List ──────────────────────────────────────────────────────────

struct SlateNumberedListView: View {
    let items: [ListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    if containsRichLaTeX(item.text) {
                        LaTeXMathView(equation: item.text, isDisplay: false)
                    } else {
                        Text(slateAttributedString(item.text))
                            .font(.body)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// ── Code Block ─────────────────────────────────────────────────────────────

// MARK: - Native Syntax Highlighter

struct SyntaxHighlighter {
    static func highlight(_ code: String, language: String?) -> AttributedString {
        let nsAttr = NSMutableAttributedString(string: code)
        let fullRange = NSRange(location: 0, length: code.utf16.count)
        
        nsAttr.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)
        nsAttr.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        guard let lang = language?.lowercased(), !lang.isEmpty else {
            return AttributedString(nsAttr)
        }
        
        let keywords = [
            "func", "function", "fn", "def", "let", "var", "const", "struct", "class", "enum", "protocol",
            "if", "else", "switch", "case", "default", "for", "while", "in", "return", "import", "pub", "use",
            "impl", "mut", "self", "Self", "static", "true", "false", "nil", "null", "break", "continue",
            "try", "catch", "throw", "throws", "async", "await", "guard", "defer", "typealias", "associatedtype",
            "and", "or", "not", "elif", "as", "is", "where"
        ]
        
        let typePattern = #"\b[A-Z][a-zA-Z0-9_]*\b"#
        let commentPattern = #"//.*|/\*[\s\S]*?\*/"#
        let stringPattern = #"\"(\\.|[^\"])*\"|\'(\\.|[^\'])*\'"#
        let numberPattern = #"\b\d+(\.\d+)?\b"#
        let keywordPattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        
        let numberRegex = try? NSRegularExpression(pattern: numberPattern, options: [])
        let typeRegex = try? NSRegularExpression(pattern: typePattern, options: [])
        let keywordRegex = try? NSRegularExpression(pattern: keywordPattern, options: [])
        let stringRegex = try? NSRegularExpression(pattern: stringPattern, options: [])
        let commentRegex = try? NSRegularExpression(pattern: commentPattern, options: [])
        
        let keywordColor = UIColor.systemOrange
        let typeColor = UIColor.systemTeal
        let stringColor = UIColor.systemGreen
        let commentColor = UIColor.secondaryLabel
        let numberColor = UIColor.systemPurple
        
        numberRegex?.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                nsAttr.addAttribute(.foregroundColor, value: numberColor, range: range)
            }
        }
        
        typeRegex?.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                nsAttr.addAttribute(.foregroundColor, value: typeColor, range: range)
            }
        }
        
        keywordRegex?.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                nsAttr.addAttribute(.foregroundColor, value: keywordColor, range: range)
            }
        }
        
        stringRegex?.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                nsAttr.addAttribute(.foregroundColor, value: stringColor, range: range)
            }
        }
        
        commentRegex?.enumerateMatches(in: code, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                nsAttr.addAttribute(.foregroundColor, value: commentColor, range: range)
                if let italicFont = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular).italic() {
                    nsAttr.addAttribute(.font, value: italicFont, range: range)
                }
            }
        }
        
        return AttributedString(nsAttr)
    }
}

extension UIFont {
    func italic() -> UIFont? {
        if let desc = fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: desc, size: 0)
        }
        return nil
    }
}

// ── Code Block ─────────────────────────────────────────────────────────────

struct SlateCodeBlockView: View {
    let language: String?
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lang = language, !lang.isEmpty {
                HStack {
                    Text(lang.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

                Divider()
                    .opacity(0.4)
            }

            if language?.lowercased() == "diff" {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(code.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        let isAddition = line.hasPrefix("+")
                        let isDeletion = line.hasPrefix("-")
                        let bgColor = isAddition ? Color.green.opacity(0.12) : (isDeletion ? Color.red.opacity(0.12) : Color.clear)
                        let fgColor = isAddition ? Color.green : (isDeletion ? Color.red : Color.primary)
                        
                        Text(line)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(fgColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(bgColor)
                    }
                }
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(SyntaxHighlighter.highlight(code, language: language))
                        .lineSpacing(4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// ── Blockquote ─────────────────────────────────────────────────────────────

struct SlateBlockquoteView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.2))
                .frame(width: 3)

            Text(slateAttributedString(text))
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .italic()
                .padding(.leading, 12)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

// ── Alert Card ─────────────────────────────────────────────────────────────

struct SlateAlertCardView: View {
    let style: AlertStyle
    let title: String?
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left accent border
            RoundedRectangle(cornerRadius: 2)
                .fill(style.color)
                .frame(width: 4)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: style.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(style.color)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    if let t = title, !t.isEmpty {
                        Text(t)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(style.color)
                    } else {
                        Text(style.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(style.color)
                    }

                    if !bodyText.isEmpty {
                        if containsRichLaTeX(bodyText) {
                            LaTeXMathView(equation: bodyText, isDisplay: false)
                                .padding(.vertical, 2)
                        } else {
                            Text(slateAttributedString(bodyText))
                                .font(.subheadline)
                                .lineSpacing(4)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(style.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// ── Table ──────────────────────────────────────────────────────────────────

struct SlateTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        let screenWidth = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.width ?? 375
        let columnWidth = max(110, (screenWidth - 32) / CGFloat(headers.count))
        
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { colIndex, header in
                        Group {
                            if containsRichLaTeX(header) {
                                LaTeXMathView(equation: header, isDisplay: false, isTableStyle: true)
                                    .padding(.vertical, 4)
                            } else {
                                Text(header)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(width: columnWidth, alignment: .leading)

                        if colIndex < headers.count - 1 {
                            Divider()
                                .frame(maxHeight: 36)
                        }
                    }
                }
                .background(Color.primary.opacity(0.06))

                Divider()

                // Data rows
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                            Group {
                                if containsRichLaTeX(cell) {
                                    LaTeXMathView(equation: cell, isDisplay: false, isTableStyle: true)
                                        .padding(.vertical, 4)
                                } else {
                                    Text(slateAttributedString(cell))
                                        .font(.subheadline)
                                        .lineSpacing(3)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(width: columnWidth, alignment: .leading)

                            if colIndex < row.count - 1 {
                                Divider()
                                    .frame(maxHeight: 36)
                            }
                        }
                    }
                    .background(rowIndex % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))

                    if rowIndex < rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Main Block Dispatcher

struct SlateBlockView: View {
    let block: SlateBlock
    var messageID: String? = nil

    var body: some View {
        switch block {
        case .heading(let level, let text):
            SlateHeadingView(level: level, text: text)

        case .paragraph(let text):
            SlateParagraphView(text: text)

        case .checklist(let items):
            SlateChecklistView(items: items)

        case .bulletList(let items):
            SlateBulletListView(items: items)

        case .numberedList(let items):
            SlateNumberedListView(items: items)

        case .codeBlock(let language, let code):
            SlateCodeBlockView(language: language, code: code)

        case .blockquote(let text):
            SlateBlockquoteView(text: text)

        case .alert(let style, let title, let body):
            SlateAlertCardView(style: style, title: title, bodyText: body)

        case .table(let headers, let rows):
            SlateTableView(headers: headers, rows: rows)

        case .horizontalRule:
            Divider()

        case .genui(let payload):
            if let msgID = messageID {
                GenUIComponentView(
                    payload: payload,
                    messageID: msgID,
                    genuiState: .constant(nil)
                )
            } else {
                // In Notes context — render as static label
                Text("Interactive component")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

        case .latex(let equation, let isDisplay):
            LaTeXMathView(equation: equation, isDisplay: isDisplay)
        }
    }
}
