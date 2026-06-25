//
//  MarkdownToRTFConverter.swift
//  Slate
//

import UIKit

struct MarkdownToRTFConverter {
    
    /// Converts a raw markdown string into a base64-encoded RTF string prefixed with "rtf:"
    static func convert(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        let result = NSMutableAttributedString()
        
        for (index, line) in lines.enumerated() {
            var processedLine = line
            var attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.label
            ]
            
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 1. Parse Headings
            if trimmed.hasPrefix("### ") {
                let text = String(trimmed.dropFirst(4))
                attributes[.font] = UIFont.systemFont(ofSize: 18, weight: .bold)
                processedLine = text
            } else if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                attributes[.font] = UIFont.systemFont(ofSize: 20, weight: .bold)
                processedLine = text
            } else if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                attributes[.font] = UIFont.systemFont(ofSize: 24, weight: .bold)
                processedLine = text
            }
            // 2. Parse Checkboxes & Lists
            else if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [] ") {
                let dropCount = trimmed.hasPrefix("- [ ] ") ? 6 : 5
                let text = String(trimmed.dropFirst(dropCount))
                processedLine = "☐  " + text
            } else if trimmed.hasPrefix("- [x] ") {
                let text = String(trimmed.dropFirst(6))
                processedLine = "☑  " + text
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2))
                processedLine = "•  " + text
            }
            
            // 3. Clean up inline formatting tags to ensure clean presentation
            processedLine = processedLine
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
            
            let nsLine = NSAttributedString(
                string: processedLine + (index < lines.count - 1 ? "\n" : ""),
                attributes: attributes
            )
            result.append(nsLine)
        }
        
        if let rtfData = try? result.data(
            from: NSRange(location: 0, length: result.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            return "rtf:" + rtfData.base64EncodedString()
        }
        
        return markdown
    }
}
