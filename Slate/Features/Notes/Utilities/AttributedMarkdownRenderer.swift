//
//  AttributedMarkdownRenderer.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import UIKit

struct AttributedMarkdownRenderer {
    static func getIndentLevel(from line: String) -> Int {
        var spaceCount = 0
        for char in line {
            if char == " " {
                spaceCount += 1
            } else if char == "\t" {
                spaceCount += 2
            } else {
                break
            }
        }
        return spaceCount / 2
    }
    
    static func stripIndent(from line: String, level: Int) -> String {
        return String(line.dropFirst(level * 2))
    }
    
    static func parseInlineMarkdown(_ text: String, font: UIFont) -> NSAttributedString {
        let attrString = NSMutableAttributedString(string: text)
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        attrString.addAttributes(defaultAttributes, range: NSRange(location: 0, length: attrString.length))
        
        // Parse and format colored/styled underline tags
        let colorRegex = try! NSRegularExpression(pattern: #"(?i)<u\s+style="color:\s*([^";\s>]+);?\s*">(.*?)</u>"#, options: [])
        var matchFound = true
        while matchFound {
            let range = NSRange(location: 0, length: attrString.length)
            if let match = colorRegex.firstMatch(in: attrString.string, options: [], range: range) {
                let tagRange = match.range(at: 0)
                let colorRange = match.range(at: 1)
                let contentRange = match.range(at: 2)
                
                let colorName = (attrString.string as NSString).substring(with: colorRange)
                let contentAttrString = attrString.attributedSubstring(from: contentRange)
                let mutableContent = NSMutableAttributedString(attributedString: contentAttrString)
                
                let newRange = NSRange(location: 0, length: mutableContent.length)
                mutableContent.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: newRange)
                if let uiColor = parseUIColor(colorName) {
                    mutableContent.addAttribute(.foregroundColor, value: uiColor, range: newRange)
                }
                
                attrString.replaceCharacters(in: tagRange, with: mutableContent)
            } else {
                matchFound = false
            }
        }
        
        // Parse and format tags
        parseAndReplaceTag(attrString, pattern: #"<u>(.*?)</u>"#, font: font) { mutableContent, range, _ in
            mutableContent.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        parseAndReplaceTag(attrString, pattern: #"~~(.*?)~~"#, font: font) { mutableContent, range, _ in
            mutableContent.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        parseAndReplaceTag(attrString, pattern: #"`(.*?)`"#, font: font) { mutableContent, range, _ in
            mutableContent.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let currentFont = value as? UIFont ?? font
                let isBold = currentFont.isBold
                let codeFont = UIFont.monospacedSystemFont(ofSize: 14, weight: isBold ? .bold : .medium)
                mutableContent.addAttribute(.font, value: codeFont, range: subRange)
                mutableContent.addAttribute(.backgroundColor, value: UIColor.label.withAlphaComponent(0.08), range: subRange)
            }
        }
        
        parseAndReplaceTag(attrString, pattern: #"\*\*(.*?)\*\*"#, font: font) { mutableContent, range, _ in
            mutableContent.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                if let currentFont = value as? UIFont {
                    mutableContent.addAttribute(.font, value: currentFont.bold(), range: subRange)
                }
            }
        }
        
        parseAndReplaceTag(attrString, pattern: #"\*(.*?)\*"#, font: font) { mutableContent, range, _ in
            mutableContent.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                if let currentFont = value as? UIFont {
                    mutableContent.addAttribute(.font, value: currentFont.italic(), range: subRange)
                }
            }
        }
        
        // Parse and format markdown links: [link text](url)
        let linkRegex = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\((https?://[^\)]+)\)"#, options: [])
        var linkMatchFound = true
        while linkMatchFound {
            let range = NSRange(location: 0, length: attrString.length)
            if let match = linkRegex.firstMatch(in: attrString.string, options: [], range: range) {
                let tagRange = match.range(at: 0)
                let textRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                
                let linkText = (attrString.string as NSString).substring(with: textRange)
                let urlString = (attrString.string as NSString).substring(with: urlRange)
                
                let mutableContent = NSMutableAttributedString(string: linkText)
                let newRange = NSRange(location: 0, length: mutableContent.length)
                
                mutableContent.addAttributes([.font: font], range: newRange)
                
                if let url = URL(string: urlString) {
                    mutableContent.addAttribute(.link, value: url, range: newRange)
                    mutableContent.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: newRange)
                }
                
                attrString.replaceCharacters(in: tagRange, with: mutableContent)
            } else {
                linkMatchFound = false
            }
        }
        
        return attrString
    }
    
    private static func parseAndReplaceTag(
        _ attrString: NSMutableAttributedString,
        pattern: String,
        font: UIFont,
        applyFormatting: (NSMutableAttributedString, NSRange, String) -> Void
    ) {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        
        var matchFound = true
        while matchFound {
            let range = NSRange(location: 0, length: attrString.length)
            if let match = regex.firstMatch(in: attrString.string, options: [], range: range) {
                let tagRange = match.range(at: 0)
                let contentRange = match.range(at: 1)
                
                let contentAttrString = attrString.attributedSubstring(from: contentRange)
                let mutableContent = NSMutableAttributedString(attributedString: contentAttrString)
                
                guard tagRange.length > 0 else {
                    matchFound = false
                    break
                }
                
                guard mutableContent.length > 0 else {
                    attrString.replaceCharacters(in: tagRange, with: mutableContent)
                    continue
                }
                
                let newRange = NSRange(location: 0, length: mutableContent.length)
                applyFormatting(mutableContent, newRange, mutableContent.string)
                
                attrString.replaceCharacters(in: tagRange, with: mutableContent)
            } else {
                matchFound = false
            }
        }
    }
    
    static func parseToAttributed(text: String, font: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var sanitizedText = text
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
        
        while sanitizedText.contains("\n\n") {
            sanitizedText = sanitizedText.replacingOccurrences(of: "\n\n", with: "\n")
        }
        let lines = sanitizedText.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let level = getIndentLevel(from: line)
            let strippedLine = stripIndent(from: line, level: level)
            let indentOffset = CGFloat(level * 24)
            
            let checklistParagraphStyle = NSMutableParagraphStyle()
            checklistParagraphStyle.headIndent = indentOffset + 32
            checklistParagraphStyle.firstLineHeadIndent = indentOffset
            checklistParagraphStyle.paragraphSpacing = 8
            checklistParagraphStyle.lineSpacing = 3.0
            
            let bulletParagraphStyle = NSMutableParagraphStyle()
            bulletParagraphStyle.headIndent = indentOffset + 18
            bulletParagraphStyle.firstLineHeadIndent = indentOffset
            bulletParagraphStyle.paragraphSpacing = 8
            bulletParagraphStyle.lineSpacing = 3.0
            
            let numberedParagraphStyle = NSMutableParagraphStyle()
            numberedParagraphStyle.headIndent = indentOffset + 24
            numberedParagraphStyle.firstLineHeadIndent = indentOffset
            numberedParagraphStyle.paragraphSpacing = 8
            numberedParagraphStyle.lineSpacing = 3.0
            
            let normalParagraphStyle = NSMutableParagraphStyle()
            normalParagraphStyle.headIndent = indentOffset
            normalParagraphStyle.firstLineHeadIndent = indentOffset
            normalParagraphStyle.paragraphSpacing = 8
            normalParagraphStyle.lineSpacing = 3.0
            
            // --- Headers (h1 / h2 / h3) ---
            if strippedLine.hasPrefix("### ") {
                let headerFont = UIFont.systemFont(ofSize: 18, weight: .bold)
                let text = String(strippedLine.dropFirst(4))
                let attrString = parseInlineMarkdown(text, font: headerFont)
                let mutableAttr = NSMutableAttributedString(attributedString: attrString)
                let headerStyle = NSMutableParagraphStyle()
                headerStyle.headIndent = indentOffset
                headerStyle.firstLineHeadIndent = indentOffset
                headerStyle.paragraphSpacing = 4
                headerStyle.paragraphSpacingBefore = 8
                headerStyle.lineSpacing = 3.0
                mutableAttr.addAttribute(.paragraphStyle, value: headerStyle, range: NSRange(location: 0, length: mutableAttr.length))
                result.append(mutableAttr)
            } else if strippedLine.hasPrefix("## ") {
                let headerFont = UIFont.systemFont(ofSize: 21, weight: .bold)
                let text = String(strippedLine.dropFirst(3))
                let attrString = parseInlineMarkdown(text, font: headerFont)
                let mutableAttr = NSMutableAttributedString(attributedString: attrString)
                let headerStyle = NSMutableParagraphStyle()
                headerStyle.headIndent = indentOffset
                headerStyle.firstLineHeadIndent = indentOffset
                headerStyle.paragraphSpacing = 4
                headerStyle.paragraphSpacingBefore = 10
                headerStyle.lineSpacing = 3.0
                mutableAttr.addAttribute(.paragraphStyle, value: headerStyle, range: NSRange(location: 0, length: mutableAttr.length))
                result.append(mutableAttr)
            } else if strippedLine.hasPrefix("# ") {
                let headerFont = UIFont.systemFont(ofSize: 24, weight: .bold)
                let text = String(strippedLine.dropFirst(2))
                let attrString = parseInlineMarkdown(text, font: headerFont)
                let mutableAttr = NSMutableAttributedString(attributedString: attrString)
                let headerStyle = NSMutableParagraphStyle()
                headerStyle.headIndent = indentOffset
                headerStyle.firstLineHeadIndent = indentOffset
                headerStyle.paragraphSpacing = 6
                headerStyle.paragraphSpacingBefore = 12
                headerStyle.lineSpacing = 3.0
                mutableAttr.addAttribute(.paragraphStyle, value: headerStyle, range: NSRange(location: 0, length: mutableAttr.length))
                result.append(mutableAttr)
            // --- Blockquotes ---
            } else if strippedLine.hasPrefix("> ") {
                let text = String(strippedLine.dropFirst(2))
                let quoteFont = UIFont.systemFont(ofSize: 16).italic()
                let attrString = parseInlineMarkdown(text, font: quoteFont)
                let mutableAttr = NSMutableAttributedString(attributedString: attrString)
                let quoteStyle = NSMutableParagraphStyle()
                quoteStyle.headIndent = indentOffset + 16
                quoteStyle.firstLineHeadIndent = indentOffset + 16
                quoteStyle.paragraphSpacing = 8
                quoteStyle.lineSpacing = 3.0
                mutableAttr.addAttribute(.paragraphStyle, value: quoteStyle, range: NSRange(location: 0, length: mutableAttr.length))
                mutableAttr.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: NSRange(location: 0, length: mutableAttr.length))
                result.append(mutableAttr)
            // --- Checklists, lists, normal text ---
            } else if strippedLine.hasPrefix("- [ ] ") {
                let attachment = CheckboxAttachment(isChecked: false)
                let attrString = NSMutableAttributedString(attachment: attachment)
                var contentText = String(strippedLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Strip redundant bullets/dashes if present (e.g. "- [ ] - text" or "- [ ] * text")
                while true {
                    let initial = contentText
                    for prefix in ["- ", "– ", "— ", "* ", "• ", "-", "–", "—", "*", "•"] {
                        if contentText.hasPrefix(prefix) {
                            contentText = String(contentText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    if contentText == initial { break }
                }
                
                let contentAttr = parseInlineMarkdown(contentText, font: font)
                let spaceAttr = NSAttributedString(string: "  ", attributes: [.font: font, .foregroundColor: UIColor.label])
                attrString.append(spaceAttr)
                attrString.append(contentAttr)
                
                attrString.addAttribute(.paragraphStyle, value: checklistParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                
                result.append(attrString)
            } else if strippedLine.hasPrefix("- [x] ") {
                let attachment = CheckboxAttachment(isChecked: true)
                let attrString = NSMutableAttributedString(attachment: attachment)
                var contentText = String(strippedLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Strip redundant bullets/dashes if present (e.g. "- [x] - text" or "- [x] * text")
                while true {
                    let initial = contentText
                    for prefix in ["- ", "– ", "— ", "* ", "• ", "-", "–", "—", "*", "•"] {
                        if contentText.hasPrefix(prefix) {
                            contentText = String(contentText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    if contentText == initial { break }
                }
                
                let contentAttr = parseInlineMarkdown(contentText, font: font)
                let spaceAttr = NSAttributedString(string: "  ", attributes: [.font: font, .foregroundColor: UIColor.label])
                
                let mutableContent = NSMutableAttributedString(attributedString: contentAttr)
                let textRange = NSRange(location: 0, length: mutableContent.length)
                mutableContent.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
                mutableContent.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: textRange)
                
                attrString.append(spaceAttr)
                attrString.append(mutableContent)
                
                attrString.addAttribute(.paragraphStyle, value: checklistParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                
                result.append(attrString)
            } else if strippedLine.hasPrefix("- ") || strippedLine.hasPrefix("• ") {
                let contentText = String(strippedLine.dropFirst(2))
                let contentAttr = parseInlineMarkdown(contentText, font: font)
                let attrString = NSMutableAttributedString(string: "•  ")
                attrString.append(contentAttr)
                
                attrString.addAttribute(.paragraphStyle, value: bulletParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                attrString.addAttributes([.font: font, .foregroundColor: UIColor.label], range: NSRange(location: 0, length: 3))
                
                result.append(attrString)
            } else if let numberMatch = strippedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let prefix = String(strippedLine[numberMatch])
                let extraSpacePrefix = prefix.replacingOccurrences(of: ". ", with: ".  ")
                let contentText = String(strippedLine[numberMatch.upperBound...])
                let contentAttr = parseInlineMarkdown(contentText, font: font)
                let attrString = NSMutableAttributedString(string: extraSpacePrefix)
                attrString.append(contentAttr)
                
                attrString.addAttribute(.paragraphStyle, value: numberedParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                attrString.addAttributes([.font: font, .foregroundColor: UIColor.label], range: NSRange(location: 0, length: extraSpacePrefix.count))
                
                result.append(attrString)
            } else {
                let contentAttr = parseInlineMarkdown(strippedLine, font: font)
                let attrString = NSMutableAttributedString(attributedString: contentAttr)
                
                attrString.addAttribute(.paragraphStyle, value: normalParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                
                result.append(attrString)
            }
            
            if index < lines.count - 1 {
                let isList = strippedLine.hasPrefix("- [ ] ") || strippedLine.hasPrefix("- [x] ") || strippedLine.hasPrefix("- ") || strippedLine.hasPrefix("• ") || strippedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
                let newlineParagraphStyle = isList ? (strippedLine.hasPrefix("- ") || strippedLine.hasPrefix("• ") ? bulletParagraphStyle : (strippedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil ? numberedParagraphStyle : checklistParagraphStyle)) : normalParagraphStyle
                
                let newlineAttrs: [NSAttributedString.Key: Any] = [
                    .paragraphStyle: newlineParagraphStyle,
                    .font: font,
                    .foregroundColor: UIColor.label
                ]
                result.append(NSAttributedString(string: "\n", attributes: newlineAttrs))
            }
        }
        
        return result
    }
    
    static func serializeToString(attributed: NSAttributedString) -> String {
        var result = ""
        let string = attributed.string as NSString
        
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attrs, range, _ in
            if let attachment = attrs[.attachment] as? CheckboxAttachment {
                result += attachment.isChecked ? "- [x] " : "- [ ] "
            } else {
                let substring = string.substring(with: range)
                let cleaned = substring.replacingOccurrences(of: "\u{FFFC}", with: "")
                
                var prefix = ""
                var suffix = ""
                
                if let font = attrs[.font] as? UIFont {
                    let isMonospaced = font.fontName.contains("Mono") || font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
                    if isMonospaced {
                        prefix += "`"
                        suffix = "`" + suffix
                    }
                    
                    if font.isBold {
                        prefix += "**"
                        suffix = "**" + suffix
                    }
                    if font.isItalic {
                        prefix += "*"
                        suffix = "*" + suffix
                    }
                }
                
                if let underline = attrs[.underlineStyle] as? Int, underline > 0 {
                    if let foregroundColor = attrs[.foregroundColor] as? UIColor,
                       let colorName = parseUIColorName(foregroundColor) {
                        prefix += "<u style=\"color:\(colorName)\">"
                    } else {
                        prefix += "<u>"
                    }
                    suffix = "</u>" + suffix
                }
                
                if let strikethrough = attrs[.strikethroughStyle] as? Int, strikethrough > 0 {
                    var isChecklistStrikethrough = false
                    let lineRange = string.lineRange(for: range)
                    if lineRange.length > 0 {
                        var optRange = NSRange(location: 0, length: 0)
                        if let firstAttr = attributed.attribute(.attachment, at: lineRange.location, effectiveRange: &optRange) as? CheckboxAttachment {
                            if firstAttr.isChecked {
                                isChecklistStrikethrough = true
                            }
                        }
                    }
                    
                    if !isChecklistStrikethrough {
                        prefix += "~~"
                        suffix = "~~" + suffix
                    }
                }
                
                result += prefix + cleaned + suffix
            }
        }
        
        var lines = result.components(separatedBy: "\n")
        for i in 0..<lines.count {
            let lineStart = findLineStartInAttributed(attributed, lineIndex: i)
            if lineStart < attributed.length {
                var optRange = NSRange(location: 0, length: 0)
                if let paraStyle = attributed.attribute(.paragraphStyle, at: lineStart, effectiveRange: &optRange) as? NSParagraphStyle {
                    let level = Int(paraStyle.firstLineHeadIndent / 24)
                    if level > 0 {
                        let spaces = String(repeating: " ", count: level * 2)
                        lines[i] = spaces + lines[i]
                    }
                }
            }
            
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("• ") {
                if let bulletRange = lines[i].range(of: "• ") {
                    lines[i] = lines[i].replacingCharacters(in: bulletRange, with: "- ")
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private static func findLineStartInAttributed(_ attrString: NSAttributedString, lineIndex: Int) -> Int {
        let string = attrString.string as NSString
        var currentLineIndex = 0
        var currentIndex = 0
        
        while currentIndex < string.length {
            let lineRange = string.lineRange(for: NSRange(location: currentIndex, length: 0))
            if currentLineIndex == lineIndex {
                return lineRange.location
            }
            currentIndex = lineRange.location + lineRange.length
            currentLineIndex += 1
        }
        
        return string.length
    }
    
    private static func parseUIColor(_ name: String) -> UIColor? {
        switch name.lowercased() {
        case "red": return .systemRed
        case "green": return .systemGreen
        case "blue": return .systemBlue
        case "yellow": return .systemYellow
        case "orange": return .systemOrange
        case "purple": return .systemPurple
        case "pink": return .systemPink
        case "gray", "grey": return .systemGray
        case "black": return .label
        case "white": return .systemBackground
        default:
            let hex = name.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            if hex.count == 6 {
                var rgbValue: UInt64 = 0
                Scanner(string: hex).scanHexInt64(&rgbValue)
                let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
                let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
                let b = CGFloat(rgbValue & 0x0000FF) / 255.0
                return UIColor(red: r, green: g, blue: b, alpha: 1.0)
            }
            return nil
        }
    }
    
    private static func parseUIColorName(_ color: UIColor) -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        
        if abs(r - 0.2) < 0.15 && abs(g - 0.78) < 0.15 && abs(b - 0.35) < 0.15 { return "green" }
        if r == 0.0 && g > 0.4 && b == 0.0 { return "green" }
        if abs(r - 1.0) < 0.1 && g == 0.0 && b == 0.0 { return "red" }
        if abs(r - 0.99) < 0.15 && abs(g - 0.23) < 0.15 && abs(b - 0.18) < 0.15 { return "red" }
        if r == 0.0 && g == 0.0 && abs(b - 1.0) < 0.1 { return "blue" }
        if abs(r - 0.0) < 0.15 && abs(g - 0.47) < 0.15 && abs(b - 1.0) < 0.15 { return "blue" }
        if abs(r - 1.0) < 0.1 && abs(g - 0.8) < 0.15 && b == 0.0 { return "yellow" }
        if abs(r - 1.0) < 0.1 && abs(g - 0.58) < 0.15 && b == 0.0 { return "orange" }
        
        if color == UIColor.systemGreen { return "green" }
        if color == UIColor.systemRed { return "red" }
        if color == UIColor.systemBlue { return "blue" }
        if color == UIColor.systemYellow { return "yellow" }
        if color == UIColor.systemOrange { return "orange" }
        if color == UIColor.systemPurple { return "purple" }
        if color == UIColor.systemPink { return "pink" }
        if color == UIColor.systemGray { return "gray" }
        
        return nil
    }
}
