//
//  MarkdownMessageView.swift
//  Slate
//

import SwiftUI
import WebKit

// MARK: - Markdown Models

enum MarkdownBlock: Identifiable, Equatable {
    var id: String {
        switch self {
        case .paragraph(let text): return "p-\(text.hashValue)"
        case .header(let level, let text): return "h-\(level)-\(text.hashValue)"
        case .blockquote(let text): return "bq-\(text.hashValue)"
        case .list(let items): return "list-\(items.map { $0.text }.joined().hashValue)"
        case .code(let language, let code): return "code-\(code.hashValue)"
        case .table(let headers, let rows): return "table-\((headers.joined() + rows.flatMap { $0 }.joined()).hashValue)"
        case .thematicBreak: return "hr"
        case .latex(let isDisplay, let equation): return "latex-\(isDisplay)-\(equation.hashValue)"
        }
    }
    
    case paragraph(text: String)
    case header(level: Int, text: String)
    case blockquote(text: String)
    case list(items: [MarkdownListItem])
    case code(language: String?, code: String)
    case table(headers: [String], rows: [[String]])
    case thematicBreak
    case latex(isDisplay: Bool, equation: String)
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
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentCodeBlock: (language: String?, lines: [String])? = nil
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
            let text = currentBlockquoteLines.joined(separator: "\n")
            blocks.append(.blockquote(text: text))
            currentBlockquoteLines.removeAll()
        }
        
        func flushList() {
            guard !currentListItems.isEmpty else { return }
            blocks.append(.list(items: currentListItems))
            currentListItems.removeAll()
        }
        
        func flushTable() {
            guard !currentTableLines.isEmpty else { return }
            if let tableBlock = parseTable(currentTableLines) {
                blocks.append(tableBlock)
            } else {
                for line in currentTableLines {
                    currentParagraphLines.append(line)
                }
                flushParagraph()
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
            
            // 1. Code Blocks
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if let codeBlock = currentCodeBlock {
                    blocks.append(.code(language: codeBlock.language, code: codeBlock.lines.joined(separator: "\n")))
                    currentCodeBlock = nil
                } else {
                    flushAll()
                    let langLine = line.trimmingCharacters(in: .whitespaces).dropFirst(3)
                    let lang = langLine.isEmpty ? nil : String(langLine)
                    currentCodeBlock = (language: lang, lines: [])
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
            
            // 2. Horizontal Rules
            if trimmed == "***" || trimmed == "---" || trimmed == "___" {
                flushAll()
                blocks.append(.thematicBreak)
                i += 1
                continue
            }
            
            // 3. Headings
            if trimmed.hasPrefix("#") {
                let temp = trimmed.prefix(while: { $0 == "#" })
                let level = temp.count
                let suffix = trimmed.dropFirst(level)
                if level >= 1 && level <= 6 && suffix.hasPrefix(" ") {
                    flushAll()
                    let headerText = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
                    blocks.append(.header(level: level, text: headerText))
                    i += 1
                    continue
                }
            }
            
            // 4. Blockquotes
            if trimmed.hasPrefix(">") {
                flushParagraph()
                flushList()
                flushTable()
                var content = trimmed.dropFirst()
                if content.hasPrefix(" ") {
                    content = content.dropFirst()
                }
                currentBlockquoteLines.append(String(content))
                i += 1
                continue
            } else if !currentBlockquoteLines.isEmpty {
                flushBlockquote()
            }
            
            // 5. Lists (unordered, ordered, tasks)
            let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" })
            let lineWithoutIndentation = line.dropFirst(leadingSpaces.count)
            let trimmedLine = String(lineWithoutIndentation)
            
            var isListItem = false
            var listType: MarkdownListItem.ListType = .bullet
            var checkboxState: MarkdownListItem.CheckboxState? = nil
            var itemText = ""
            
            if trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("+ ") {
                isListItem = true
                listType = .bullet
                itemText = String(trimmedLine.dropFirst(2))
            } else if let dotIndex = trimmedLine.firstIndex(of: "."),
                      dotIndex != trimmedLine.startIndex {
                let prefix = trimmedLine[..<dotIndex]
                let suffix = trimmedLine[trimmedLine.index(after: dotIndex)...]
                if prefix.allSatisfy({ $0.isNumber }) && suffix.hasPrefix(" ") {
                    isListItem = true
                    let number = Int(prefix) ?? 1
                    listType = .numbered(number: number)
                    itemText = String(suffix.dropFirst())
                }
            }
            
            if isListItem {
                flushParagraph()
                flushTable()
                
                if itemText.hasPrefix("[ ] ") || itemText.hasPrefix("[] ") {
                    checkboxState = .unchecked
                    itemText = String(itemText.dropFirst(itemText.hasPrefix("[ ] ") ? 4 : 3))
                } else if itemText.hasPrefix("[x] ") || itemText.hasPrefix("[X] ") {
                    checkboxState = .checked
                    itemText = String(itemText.dropFirst(4))
                }
                
                let level = leadingSpaces.count / 2
                
                currentListItems.append(MarkdownListItem(
                    level: level,
                    type: listType,
                    checkboxState: checkboxState,
                    text: itemText
                ))
                i += 1
                continue
            } else if !currentListItems.isEmpty {
                flushList()
            }
            
            // 6. Tables
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 1 {
                flushParagraph()
                currentTableLines.append(trimmed)
                i += 1
                continue
            } else if !currentTableLines.isEmpty {
                flushTable()
            }
            
            // 7. Paragraphs
            if trimmed.isEmpty {
                flushParagraph()
            } else {
                currentParagraphLines.append(line)
            }
            
            i += 1
        }
        
        flushAll()
        return blocks
    }
    
    private static func parseTable(_ lines: [String]) -> MarkdownBlock? {
        guard lines.count >= 2 else { return nil }
        
        let headerLine = lines[0]
        let separatorLine = lines[1]
        
        let allowedCharacters = CharacterSet(charactersIn: "|- :")
        let sepClean = separatorLine.trimmingCharacters(in: allowedCharacters)
        guard sepClean.isEmpty else { return nil }
        
        let headers = headerLine.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        var cleanedHeaders = headers
        if headerLine.hasPrefix("|") && !cleanedHeaders.isEmpty {
            cleanedHeaders.removeFirst()
        }
        if headerLine.hasSuffix("|") && !cleanedHeaders.isEmpty {
            cleanedHeaders.removeLast()
        }
        
        guard !cleanedHeaders.isEmpty else { return nil }
        
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
        
        return .table(headers: cleanedHeaders, rows: rows)
    }
}

// MARK: - Views

struct MarkdownMessageView: View {
    let content: String
    
    var body: some View {
        let blocks = MarkdownParser.parse(content)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                switch block {
                case .paragraph(let text):
                    ParagraphBlockView(text: text)
                case .header(let level, let text):
                    HeaderBlockView(level: level, text: text)
                case .blockquote(let text):
                    BlockquoteBlockView(text: text)
                case .list(let items):
                    ListBlockView(items: items)
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                case .table(let headers, let rows):
                    TableBlockView(headers: headers, rows: rows)
                case .thematicBreak:
                    ThematicBreakView()
                case .latex(let isDisplay, let equation):
                    LaTeXMathView(equation: equation, isDisplay: isDisplay)
                }
            }
        }
    }
}

// MARK: - Block Views

struct HeaderBlockView: View {
    let level: Int
    let text: String
    
    var body: some View {
        FormattedText(text)
            .font(fontForLevel)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .padding(.top, topPadding)
            .padding(.bottom, 2)
    }
    
    private var fontForLevel: Font {
        switch level {
        case 1: return .system(size: 24)
        case 2: return .system(size: 21)
        case 3: return .system(size: 18)
        case 4: return .system(size: 16)
        case 5: return .system(size: 15)
        default: return .system(size: 14)
        }
    }
    
    private var topPadding: CGFloat {
        switch level {
        case 1: return 12
        case 2: return 8
        default: return 4
        }
    }
}

struct ThematicBreakView: View {
    var body: some View {
        Divider()
            .background(Color.secondary.opacity(0.2))
            .padding(.vertical, 8)
    }
}

struct BlockquoteBlockView: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 3)
            
            FormattedText(text)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.96))
        .cornerRadius(4)
        .padding(.vertical, 2)
    }
}

struct ListBlockView: View {
    let items: [MarkdownListItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 6) {
                    if item.level > 0 {
                        Spacer()
                            .frame(width: CGFloat(item.level) * 16)
                    }
                    
                    if let checkbox = item.checkboxState {
                        Image(systemName: checkbox == .checked ? "checkmark.square.fill" : "square")
                            .foregroundColor(checkbox == .checked ? .green : .secondary)
                            .font(.system(size: 14))
                            .padding(.top, 2)
                    } else {
                        switch item.type {
                        case .bullet:
                            Text("•")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 8)
                        case .numbered(let number):
                            Text("\(number).")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                                .frame(width: 18, alignment: .trailing)
                        }
                    }
                    
                    FormattedText(item.text)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct CodeBlockView: View {
    let language: String?
    let code: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language?.uppercased() ?? "CODE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = code
                    withAnimation {
                        isCopied = true
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.94))
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.97))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

struct TableBlockView: View {
    let headers: [String]
    let rows: [[String]]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(0..<headers.count, id: \.self) { index in
                        FormattedText(headers[index])
                            .font(.system(size: 14, weight: .bold))
                            .padding(10)
                            .frame(minWidth: 100, alignment: .leading)
                            .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92))
                            .border(Color.secondary.opacity(0.3), width: 0.5)
                    }
                }
                
                ForEach(0..<rows.count, id: \.self) { rowIndex in
                    let row = rows[rowIndex]
                    HStack(spacing: 0) {
                        ForEach(0..<headers.count, id: \.self) { colIndex in
                            let text = colIndex < row.count ? row[colIndex] : ""
                            FormattedText(text)
                                .font(.system(size: 14))
                                .padding(10)
                                .frame(minWidth: 100, alignment: .leading)
                                .background(
                                    rowIndex % 2 == 0
                                    ? (colorScheme == .dark ? Color(white: 0.08) : Color.white)
                                    : (colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
                                )
                                .border(Color.secondary.opacity(0.2), width: 0.5)
                        }
                    }
                }
            }
            .border(Color.secondary.opacity(0.3), width: 1)
        }
        .padding(.vertical, 6)
    }
}

struct ParagraphBlockView: View {
    let text: String
    
    var body: some View {
        FormattedText(text)
            .font(.system(size: 16))
            .foregroundColor(.primary)
    }
}

// MARK: - LaTeX Math View

struct LaTeXMathView: View {
    let equation: String
    let isDisplay: Bool
    @State private var webViewHeight: CGFloat = 35
    
    var body: some View {
        LaTeXWebViewRepresentable(equation: equation, isDisplay: isDisplay, height: $webViewHeight)
            .frame(height: webViewHeight)
            .padding(.vertical, isDisplay ? 4 : 0)
    }
}

struct LaTeXWebViewRepresentable: UIViewRepresentable {
    let equation: String
    let isDisplay: Bool
    @Binding var height: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "sizeTracker")
        
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        let colorHex = colorScheme == .dark ? "#FFFFFF" : "#000000"
        let wrappedEquation = isDisplay ? "$$\(equation)$$" : "$\(equation)$"
        
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            body {
              font-family: -apple-system, sans-serif;
              margin: 0;
              padding: 4px;
              background-color: transparent;
              color: \(colorHex);
              font-size: 16px;
            }
            .math-container {
              display: flex;
              justify-content: \(isDisplay ? "center" : "flex-start");
              align-items: center;
              overflow-x: auto;
              white-space: nowrap;
            }
          </style>
          <script>
            window.MathJax = {
              startup: {
                pageReady: () => {
                  return MathJax.startup.defaultPageReady().then(() => {
                    setTimeout(sendHeight, 100);
                  });
                }
              },
              tex: {
                inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                displayMath: [['$$', '$$'], ['\\\\[', \\\\]']]
              }
            };
            
            function sendHeight() {
              let height = document.documentElement.scrollHeight || document.body.scrollHeight;
              window.webkit.messageHandlers.sizeTracker.postMessage(height);
            }
          </script>
          <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
        </head>
        <body>
          <div class="math-container">
            \(wrappedEquation)
          </div>
        </body>
        </html>
        """
        uiView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: LaTeXWebViewRepresentable
        
        init(_ parent: LaTeXWebViewRepresentable) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "sizeTracker", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.height = max(height, 20)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight || document.body.scrollHeight") { (result, error) in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.height = max(height, 20)
                    }
                }
            }
        }
    }
}

// MARK: - Inline Formatting View

struct FormattedText: View {
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        let parts = content.components(separatedBy: "$")
        if parts.count >= 3 {
            var result = Text("")
            for (index, part) in parts.enumerated() {
                if index % 2 == 1 {
                    result = result + Text(part)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .italic()
                } else {
                    result = result + parseInlineMarkdown(part)
                }
            }
            return result
        } else {
            return parseInlineMarkdown(content)
        }
    }
    
    private func parseInlineMarkdown(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attrStr = try? AttributedString(markdown: text, options: options) {
            return Text(attrStr)
        } else {
            return Text(text)
        }
    }
}
