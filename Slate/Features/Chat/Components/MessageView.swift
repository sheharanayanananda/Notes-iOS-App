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

    var body: some View {
        SlateMarkdownView(content: content, messageID: messageID, isFullWidth: isFullWidth)
            .onAppear {
                if let index = ChatManager.shared.messages.firstIndex(where: { $0.id == messageID }) {
                    self.genuiState = ChatManager.shared.messages[index].genuiState
                }
                onAnimationComplete?()
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "sizeTracker")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.loadHTMLString(makeHTML(), baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func makeHTML() -> String {
        let escapedEquation = equation
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        return """
        <html>
        <head>
            <style>
                body {
                    margin: 0; padding: 4px 0;
                    background: transparent;
                    font-size: 16px;
                    \(isDisplay ? "text-align: center;" : "display: inline;")
                }
            </style>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <script>
                function notifySize() {
                    setTimeout(() => {
                        const width = document.body.scrollWidth;
                        const height = document.body.scrollHeight;
                        window.webkit.messageHandlers.sizeTracker.postMessage({width: width, height: height});
                    }, 100);
                }
            </script>
        </head>
        <body>
            <div id="math">
                \(isDisplay ? "$$\(escapedEquation)$$" : "$\(escapedEquation)$")
            </div>
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: LaTeXWebViewRepresentable

        init(_ parent: LaTeXWebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("notifySize()", completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let height = dict["height"] as? CGFloat else { return }

            DispatchQueue.main.async {
                self.parent.height = max(height, 20)
            }
        }
    }
}
