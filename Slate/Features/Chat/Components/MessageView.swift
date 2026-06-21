//
//  MarkdownMessageView.swift
//  Slate
//

import SwiftUI
import WebKit
import Foundation







// MARK: - Views

struct MarkdownStrikethroughKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var markdownStrikethrough: Bool {
        get { self[MarkdownStrikethroughKey.self] }
        set { self[MarkdownStrikethroughKey.self] = newValue }
    }
}

struct IdentifiableBlock: Identifiable {
    let id: String
    let block: MarkdownBlock
}

struct MessageView: View {
    let content: String
    var isNew: Bool = false
    var onBlockRevealed: (() -> Void)? = nil
    
    @State private var visibleBlocksCount: Int = 0
    @State private var hasAnimated: Bool = false
    
    var body: some View {
        let blocks = MarkdownParser.parse(content)
        let wrappedBlocks = blocks.enumerated().map { index, block in
            IdentifiableBlock(id: "\(index)-\(block.id)", block: block)
        }
        
        VStack(alignment: .leading, spacing: 10) {
            ForEach(wrappedBlocks.prefix(visibleBlocksCount)) { wrapped in
                BlockRenderer(block: wrapped.block)
                    .transition(.asymmetric(
                        insertion: .opacity
                            .combined(with: .move(edge: .bottom))
                            .animation(.easeOut(duration: 0.35)),
                        removal: .identity
                    ))
            }
        }
        .onAppear {
            if isNew && !hasAnimated {
                visibleBlocksCount = 0
                animateBlocks(count: blocks.count)
            } else {
                visibleBlocksCount = blocks.count
            }
        }
        .onChange(of: content) {
            if !isNew {
                visibleBlocksCount = blocks.count
            }
        }
    }
    
    private func animateBlocks(count: Int) {
        hasAnimated = true
        Task {
            for i in 1...count {
                try? await Task.sleep(nanoseconds: 120_000_000)
                await MainActor.run {
                    withAnimation {
                        visibleBlocksCount = i
                    }
                    onBlockRevealed?()
                }
            }
        }
    }
}

struct BlockRenderer: View {
    let block: MarkdownBlock
    
    var body: some View {
        switch block {
        case .paragraph(let text):
            ParagraphBlockView(text: text)
        case .header(let level, let text):
            HeaderBlockView(level: level, text: text)
        case .blockquote(let blocks):
            BlockquoteBlockView(blocks: blocks)
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
        case .alert(let type, let blocks):
            AlertBlockView(type: type, blocks: blocks)
        case .image(let caption, let urlString):
            ImageBlockView(caption: caption, urlString: urlString)
        }
    }
}

struct AlertBlockView: View {
    let type: AlertType
    let blocks: [MarkdownBlock]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: type.iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(type.color)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(type.color)
                
                ForEach(blocks) { block in
                    BlockRenderer(block: block)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(type.color.opacity(colorScheme == .dark ? 0.12 : 0.06))
        )
        .overlay(
            HStack {
                Rectangle()
                    .fill(type.color)
                    .frame(width: 4)
                Spacer()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 4)
    }
}

struct ImageBlockView: View {
    let caption: String
    let urlString: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                    case .failure:
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("Failed to load image")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Block Views

struct HeaderBlockView: View {
    let level: Int
    let text: String
    
    var body: some View {
        let isRtl = isRTL(text)
        if isRtl {
            FormattedText(text)
                .font(fontForLevel)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top, topPadding)
                .padding(.bottom, 2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            FormattedText(text)
                .font(fontForLevel)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top, topPadding)
                .padding(.bottom, 2)
                .multilineTextAlignment(.leading)
        }
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
    let blocks: [MarkdownBlock]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(blocks) { block in
                    BlockRenderer(block: block)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
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
                    
                    let nestedBlocks = MarkdownParser.parse(item.text)
                    let isChecked = item.checkboxState == .checked
                    
                    Group {
                        if nestedBlocks.count > 1 || nestedBlocks.first?.isBlockElement == true {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(nestedBlocks) { block in
                                    BlockRenderer(block: block)
                                }
                            }
                        } else {
                            FormattedText(item.text)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                    }
                    .environment(\.markdownStrikethrough, isChecked)
                    .opacity(isChecked ? 0.6 : 1.0)
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
        let isRtl = isRTL(text)
        if isRtl {
            FormattedText(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            FormattedText(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
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
        
        if context.coordinator.lastLoadedHTML != htmlString {
            context.coordinator.lastLoadedHTML = htmlString
            uiView.loadHTMLString(htmlString, baseURL: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: LaTeXWebViewRepresentable
        var lastLoadedHTML: String?
        
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


