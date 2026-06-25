//
//  SlateModel.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-08.
//

import Foundation
import SwiftData

@Model
final class SlateModel: Identifiable {
    @Attribute(.unique) var id: String
    var title: String
    var desc: String
    var created_at: Date

    init(id: String = UUID().uuidString, title: String, desc: String, created_at: Date = .now) {
        self.id = id
        self.title = title
        self.desc = desc
        self.created_at = created_at
    }
}

import UIKit

extension SlateModel {
    var attributedDesc: NSAttributedString {
        let mdOptions = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attrStr = try? AttributedString(markdown: desc, options: mdOptions) {
            return NSAttributedString(attrStr)
        }
        
        return NSAttributedString(string: desc)
    }
    
    var previewText: String {
        let lines = desc.components(separatedBy: .newlines)
        var cleanedLines = [String]()
        for line in lines {
            var tempLine = line
            while tempLine.hasPrefix("    ") {
                tempLine = String(tempLine.dropFirst(4))
            }
            while tempLine.hasPrefix("\t") {
                tempLine = String(tempLine.dropFirst(1))
            }
            let trimmed = tempLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            
            var cleanedContent = trimmed
            if cleanedContent.hasPrefix("# ") {
                cleanedContent = String(cleanedContent.dropFirst(2))
            } else if cleanedContent.hasPrefix("## ") {
                cleanedContent = String(cleanedContent.dropFirst(3))
            } else if cleanedContent.hasPrefix("### ") {
                cleanedContent = String(cleanedContent.dropFirst(4))
            } else if cleanedContent.hasPrefix("- [ ] ") {
                cleanedContent = String(cleanedContent.dropFirst(6))
            } else if cleanedContent.hasPrefix("- [x] ") {
                cleanedContent = String(cleanedContent.dropFirst(6))
            } else if cleanedContent.hasPrefix("☐ ") || cleanedContent.hasPrefix("☑ ") {
                cleanedContent = String(cleanedContent.dropFirst(2))
            } else if cleanedContent.hasPrefix("- ") || cleanedContent.hasPrefix("* ") {
                cleanedContent = String(cleanedContent.dropFirst(2))
            } else if cleanedContent.range(of: "^\\d+\\.\\s", options: .regularExpression) != nil {
                if let dotRange = cleanedContent.range(of: ". ") {
                    cleanedContent = String(cleanedContent[dotRange.upperBound...])
                }
            }
            
            cleanedContent = cleanedContent
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "~~", with: "")
            
            if !cleanedContent.isEmpty {
                cleanedLines.append(cleanedContent)
            }
        }
        return cleanedLines.joined(separator: " ")
    }
}
