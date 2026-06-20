//
//  MarkdownMessageView.swift
//  Slate
//

import SwiftUI
import WebKit

// MARK: - Markdown Models

enum TableColumnAlignment: String, CaseIterable, Identifiable, Codable {
    case leading
    case center
    case trailing
    
    var id: String { self.rawValue }
}

enum MarkdownBlock: Identifiable, Equatable {
    var id: String {
        switch self {
        case .paragraph(let text): return "p-\(text.hashValue)"
        case .header(let level, let text): return "h-\(level)-\(text.hashValue)"
        case .blockquote(let text): return "bq-\(text.hashValue)"
        case .list(let items): return "list-\(items.map { $0.text }.joined().hashValue)"
        case .code(_, let code): return "code-\(code.hashValue)"
        case .table(let headers, _, let rows): return "table-\((headers.joined() + rows.flatMap { $0 }.joined()).hashValue)"
        case .thematicBreak: return "hr"
        case .latex(let isDisplay, let equation): return "latex-\(isDisplay)-\(equation.hashValue)"
        }
    }
    
    case paragraph(text: String)
    case header(level: Int, text: String)
    case blockquote(text: String)
    case list(items: [MarkdownListItem])
    case code(language: String?, code: String)
    case table(headers: [String], alignments: [TableColumnAlignment], rows: [[String]])
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
            
            // 1.5. LaTeX Display Math Blocks (Multi-line)
            if (trimmed.hasPrefix("$$") && !trimmed.hasSuffix("$$")) || (trimmed == "$$" && currentLaTeXBlock == nil) {
                if let latexBlock = currentLaTeXBlock {
                    let equation = latexBlock.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    blocks.append(.latex(isDisplay: true, equation: equation))
                    currentLaTeXBlock = nil
                } else {
                    flushAll()
                    let equationContent = trimmed == "$$" ? "" : String(trimmed.dropFirst(2))
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
        
        let separators = separatorLine.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var cleanedSeparators = separators
        if separatorLine.hasPrefix("|") && !cleanedSeparators.isEmpty {
            cleanedSeparators.removeFirst()
        }
        if separatorLine.hasSuffix("|") && !cleanedSeparators.isEmpty {
            cleanedSeparators.removeLast()
        }
        
        var alignments: [TableColumnAlignment] = []
        for sep in cleanedSeparators {
            if sep.hasPrefix(":") && sep.hasSuffix(":") {
                alignments.append(.center)
            } else if sep.hasSuffix(":") {
                alignments.append(.trailing)
            } else {
                alignments.append(.leading)
            }
        }
        
        while alignments.count < cleanedHeaders.count {
            alignments.append(.leading)
        }
        
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
                case .table(let headers, let alignments, let rows):
                    TableBlockView(headers: headers, alignments: alignments, rows: rows)
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
                HStack(alignment: .center, spacing: 8) {
                    if item.level > 0 {
                        Spacer()
                            .frame(width: CGFloat(item.level) * 16)
                    }
                    
                    if let checkbox = item.checkboxState {
                        Image(systemName: checkbox == .checked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(checkbox == .checked ? Color.blue : Color.secondary.opacity(0.6))
                            .font(.system(size: 20))
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
                    
                    if item.text.trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                        let cleanText = item.text.trimmingCharacters(in: .whitespaces).dropFirst().trimmingCharacters(in: .whitespaces)
                        BlockquoteBlockView(text: cleanText)
                    } else {
                        FormattedText(item.text)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }
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
                if language?.lowercased() == "diff" {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(code.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                            let isDeletion = line.hasPrefix("-")
                            let isAddition = line.hasPrefix("+")
                            let textColor: Color = isDeletion ? .red : (isAddition ? .green : .primary)
                            let bgColor: Color = isDeletion ? Color.red.opacity(0.12) : (isAddition ? Color.green.opacity(0.12) : .clear)
                            Text(line)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(textColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(bgColor)
                        }
                    }
                    .padding(.vertical, 12)
                } else {
                    Text(code)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(12)
                }
            }
            .textSelection(.enabled)
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
    let alignments: [TableColumnAlignment]
    let rows: [[String]]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if headers.count <= 3 {
            gridTable
                .frame(maxWidth: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                gridTable
                    .frame(minWidth: CGFloat(headers.count) * 110)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var gridTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 0.5, verticalSpacing: 0.5) {
            // Header row
            GridRow {
                ForEach(0..<headers.count, id: \.self) { index in
                    let alignment = index < alignments.count ? alignments[index] : .leading
                    FormattedText(headers[index])
                        .font(.system(size: 14, weight: .bold))
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: swiftUIAlignment(alignment))
                        .background(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.92))
                }
            }
            
            // Data rows
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                let row = rows[rowIndex]
                GridRow {
                    ForEach(0..<headers.count, id: \.self) { colIndex in
                        let text = colIndex < row.count ? row[colIndex] : ""
                        let alignment = colIndex < alignments.count ? alignments[colIndex] : .leading
                        FormattedText(text)
                            .font(.system(size: 14))
                            .padding(10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: swiftUIAlignment(alignment))
                            .background(
                                rowIndex % 2 == 0
                                ? (colorScheme == .dark ? Color(white: 0.08) : Color.white)
                                : (colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
                            )
                    }
                }
            }
        }
        .background(colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.8), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
    
    private func swiftUIAlignment(_ alignment: TableColumnAlignment) -> Alignment {
        switch alignment {
        case .leading: return .topLeading
        case .center: return .top
        case .trailing: return .topTrailing
        }
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

// MARK: - Inline Formatting View

enum InlineToken: Equatable {
    case text(String)
    case inlineMath(String)
    case displayMath(String)
}

func tokenize(_ text: String) -> [InlineToken] {
    var tokens: [InlineToken] = []
    var currentText = ""
    let characters = Array(text)
    var i = 0
    
    while i < characters.count {
        if i < characters.count - 1 && characters[i] == "$" && characters[i+1] == "$" {
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
        } else if characters[i] == "$" {
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
        "\\approx": "≈", "\\propto": "∝"
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
        return result
    }
    
    private func parseInlineMarkdown(_ text: String) -> Text {
        var cleanText = text
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            
        if let regex = try? NSRegularExpression(pattern: "~~(.*?)~~", options: []) {
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
                    attrStr[run.range].foregroundColor = .red
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
            return Text(attrStr)
        } else {
            return Text(cleanText)
        }
    }
}
