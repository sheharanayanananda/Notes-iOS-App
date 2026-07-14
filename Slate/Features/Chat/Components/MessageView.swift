//
//  MessageView.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI
import MarkdownUI
import WebKit

// MARK: - Message Segment Types

enum MessageSegment: Identifiable, Equatable {
    var id: String {
        switch self {
        case .markdown(let text): return "md-\(text.hashValue)"
        case .latex(let equation, let isDisplay): return "latex-\(equation.hashValue)-\(isDisplay)"
        case .genui(let payload): return "genui-\(payload.hashValue)"
        }
    }
    
    case markdown(String)
    case latex(equation: String, isDisplay: Bool)
    case genui(payload: String)
}

// MARK: - Message Segment Parser

func parseMessageSegments(_ text: String) -> [MessageSegment] {
    var segments: [MessageSegment] = []
    let nsText = text as NSString
    var currentIndex = 0
    
    // Parse using regex to separate <genui> tags and LaTeX math blocks
    let pattern = #"(?s)(<genui>.*?</genui>)|\$\$(.*?)\$\$|\$(.*?)\$"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        return [.markdown(text)]
    }
    
    let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
    
    for match in matches {
        // Add preceding markdown segment
        if match.range.location > currentIndex {
            let mdText = nsText.substring(with: NSRange(location: currentIndex, length: match.range.location - currentIndex))
            if !mdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.markdown(mdText))
            }
        }
        
        // Check which capture group matched
        if match.range(at: 1).location != NSNotFound {
            let tagContent = nsText.substring(with: match.range(at: 1))
            let payload = tagContent
                .replacingOccurrences(of: "<genui>", with: "")
                .replacingOccurrences(of: "<br>", with: "\n")
                .replacingOccurrences(of: "<br/>", with: "\n")
                .replacingOccurrences(of: "<br />", with: "\n")
                .replacingOccurrences(of: "</genui>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            segments.append(.genui(payload: payload))
        } else if match.range(at: 2).location != NSNotFound {
            let equation = nsText.substring(with: match.range(at: 2))
            segments.append(.latex(equation: equation, isDisplay: true))
        } else if match.range(at: 3).location != NSNotFound {
            let equation = nsText.substring(with: match.range(at: 3))
            segments.append(.latex(equation: equation, isDisplay: false))
        }
        
        currentIndex = match.range.location + match.range.length
    }
    
    // Add remaining segment
    if currentIndex < nsText.length {
        let mdText = nsText.substring(from: currentIndex)
        if !mdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(.markdown(mdText))
        }
    }
    
    return segments.isEmpty ? [.markdown(text)] : segments
}

// MARK: - Main Message View

struct MessageView: View {
    let messageID: String
    let content: String
    var isNew: Bool = false
    var onBlockRevealed: (() -> Void)? = nil
    var onAnimationComplete: (() -> Void)? = nil
    
    @State private var genuiState: String? = nil
    
    var body: some View {
        let segments = parseMessageSegments(content)
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(segments) { segment in
                switch segment {
                case .markdown(let mdText):
                    Markdown(mdText)
                        .markdownTheme(.gitHub)
                        .padding(.vertical, 2)
                    
                case .latex(let equation, let isDisplay):
                    LaTeXMathView(equation: equation, isDisplay: isDisplay)
                    
                case .genui(let payload):
                    GenUIComponentView(
                        payload: payload,
                        messageID: messageID,
                        genuiState: Binding(
                            get: { self.genuiState },
                            set: { newValue in
                                self.genuiState = newValue
                                if let index = ChatManager.shared.messages.firstIndex(where: { $0.id == messageID }) {
                                    ChatManager.shared.messages[index].genuiState = newValue
                                    ChatManager.shared.saveCurrentState()
                                }
                            }
                        )
                    )
                }
            }
        }
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
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let html = generateHTML()
        uiView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func generateHTML() -> String {
        let textColor = colorScheme == .dark ? "#ffffff" : "#000000"
        let escapedEquation = equation
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background-color: transparent;
                    color: \(textColor);
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 16px;
                }
                #math {
                    display: inline-block;
                    width: 100%;
                    text-align: \(isDisplay ? "center" : "left");
                }
            </style>
            <script>
                window.MathJax = {
                    tex: {
                        inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                        displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']]
                    },
                    svg: {
                        scale: 1.0,
                        minScale: 0.5
                    },
                    startup: {
                        pageReady: () => {
                            return MathJax.startup.defaultPageReady().then(() => {
                                notifySize();
                            });
                        }
                    }
                };
            </script>
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
