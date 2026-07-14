//
//  MessageView.swift
//  Slate
//
//  Chat message renderer. Uses SlateMarkdownView for all content.
//  GenUI and LaTeX are handled natively by the unified parser.
//

import SwiftUI
import WebKit

// MARK: - Main Message View

struct MessageView: View {
    let messageID: String
    let content: String
    var isNew: Bool = false
    var isFullWidth: Bool = true
    var onBlockRevealed: (() -> Void)? = nil
    var onAnimationComplete: (() -> Void)? = nil

    @State private var genuiState: String? = nil
    @State private var visibleBlocksCount: Int = 0
    @State private var hasAnimated: Bool = false

    var body: some View {
        let blocks = SlateMarkdownParser.parse(content)
        
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.prefix(visibleBlocksCount).enumerated()), id: \.offset) { index, block in
                SlateBlockView(block: block, messageID: messageID)
                    .transition(.asymmetric(
                        insertion: .opacity
                            .combined(with: .move(edge: .bottom))
                            .animation(.easeOut(duration: 0.35)),
                        removal: .identity
                    ))
            }
        }
        .frame(maxWidth: isFullWidth ? .infinity : nil, alignment: .leading)
        .onAppear {
            if let index = ChatManager.shared.messages.firstIndex(where: { $0.id == messageID }) {
                self.genuiState = ChatManager.shared.messages[index].genuiState
            }
            
            if isNew && !hasAnimated {
                visibleBlocksCount = 0
                if blocks.isEmpty {
                    onAnimationComplete?()
                } else {
                    animateBlocks(count: blocks.count)
                }
            } else {
                visibleBlocksCount = blocks.count
                onAnimationComplete?()
            }
        }
        .onChange(of: content) { _, _ in
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
                    HapticManager.triggerSelection()
                }
            }
            await MainActor.run {
                onAnimationComplete?()
            }
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

// MARK: - LaTeX WebView Representable

struct LaTeXWebViewRepresentable: UIViewRepresentable {
    let equation: String
    let isDisplay: Bool
    @Binding var height: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

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

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: LaTeXWebViewRepresentable
        var lastLoadedHTML: String?

        init(_ parent: LaTeXWebViewRepresentable) {
            self.parent = parent
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

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "sizeTracker", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.height = max(height, 20)
                }
            }
        }
    }
}
