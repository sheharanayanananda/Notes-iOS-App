//
//  FormattedText.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI

struct FormattedText: View {
    @Environment(\.markdownStrikethrough) private var isStrikethrough
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        let parsed = parseInlineMarkdown(content)
        if isStrikethrough {
            parsed.strikethrough(true)
        } else {
            parsed
        }
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
        
        if let regex = RegexCache.uColorRegex {
            let range = NSRange(cleanText.startIndex..., in: cleanText)
            cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: "[$2](u-color://$1)")
        }
        
        if let regex = RegexCache.uPlainRegex {
            let range = NSRange(cleanText.startIndex..., in: cleanText)
            cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: "[$1](underline://true)")
        }
        
        var options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        options.allowsExtendedAttributes = true
        
        if var attrStr = try? AttributedString(markdown: cleanText, options: options) {
            for run in attrStr.runs {
                if let link = run.link {
                    if link.scheme == "strikethrough" {
                        attrStr[run.range].link = nil
                        attrStr[run.range].strikethroughStyle = .single
                    } else if link.scheme == "underline" {
                        attrStr[run.range].link = nil
                        attrStr[run.range].underlineStyle = .single
                    } else if link.scheme == "u-color", let host = link.host {
                        attrStr[run.range].link = nil
                        attrStr[run.range].underlineStyle = .single
                        if let resolvedColor = parseColor(host) {
                            attrStr[run.range].foregroundColor = resolvedColor
                        }
                    }
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
                let plainText = String(attrStr.characters)
                let matches = plainText.matches(of: emailRegex)
                for match in matches {
                    let range = match.range
                    if let startIdx = AttributedString.Index(range.lowerBound, within: attrStr),
                       let endIdx = AttributedString.Index(range.upperBound, within: attrStr) {
                        let attrRange = startIdx..<endIdx
                        let email = String(plainText[range])
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
                let plainText = String(attrStr.characters)
                let matches = plainText.matches(of: urlRegex)
                for match in matches {
                    let range = match.range
                    if let startIdx = AttributedString.Index(range.lowerBound, within: attrStr),
                       let endIdx = AttributedString.Index(range.upperBound, within: attrStr) {
                        let attrRange = startIdx..<endIdx
                        if attrStr[attrRange].link == nil {
                            let urlStr = String(plainText[range])
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

fileprivate func parseColor(_ name: String) -> Color? {
    switch name.lowercased() {
    case "red": return .red
    case "green": return .green
    case "blue": return .blue
    case "yellow": return .yellow
    case "orange": return .orange
    case "purple": return .purple
    case "pink": return .pink
    case "gray", "grey": return .gray
    case "black": return .black
    case "white": return .white
    default:
        let hex = name.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 6 {
            var rgbValue: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgbValue)
            let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = Double(rgbValue & 0x0000FF) / 255.0
            return Color(red: r, green: g, blue: b)
        }
        return nil
    }
}
