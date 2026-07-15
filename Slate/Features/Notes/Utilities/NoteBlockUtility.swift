//
//  NoteBlockUtility.swift
//  Slate
//

import Foundation
import SwiftUI

struct NoteBlockItem: Identifiable, Equatable {
    let id = UUID()
    var isSpecial: Bool
    var rawText: String
    var block: SlateBlock
    
    static func == (lhs: NoteBlockItem, rhs: NoteBlockItem) -> Bool {
        return lhs.isSpecial == rhs.isSpecial && lhs.rawText == rhs.rawText && lhs.id == rhs.id
    }
}

class NoteBlockUtility {
    
    static func serializeNormalBlock(_ block: SlateBlock) -> String {
        switch block {
        case .paragraph(let text):
            return text
        case .heading(let level, let text):
            return String(repeating: "#", count: level) + " " + text
        case .bulletList(let items):
            return items.map { item in
                let prefix = "- "
                return String(repeating: "  ", count: item.indent) + prefix + item.text
            }.joined(separator: "\n")
        case .numberedList(let items):
            return items.enumerated().map { index, item in
                let prefix = "\(index + 1). "
                return String(repeating: "  ", count: item.indent) + prefix + item.text
            }.joined(separator: "\n")
        case .checklist(let items):
            return items.map { item in
                let prefix = "- [\(item.checked ? "x" : " ")] "
                return prefix + item.text
            }.joined(separator: "\n")
        default:
            return ""
        }
    }
    
    static func serializeSpecialBlock(_ block: SlateBlock) -> String {
        switch block {
        case .codeBlock(let language, let code):
            return "```\(language ?? "")\n\(code)\n```"
        case .table(let headers, let rows):
            let headerLine = "| " + headers.joined(separator: " | ") + " |"
            let separatorLine = "| " + headers.map { _ in ":---" }.joined(separator: " | ") + " |"
            let rowLines = rows.map { "| " + $0.joined(separator: " | ") + " |" }
            return ([headerLine, separatorLine] + rowLines).joined(separator: "\n")
        case .alert(let style, let title, let body):
            let header = title != nil && !title!.isEmpty ? " [!\(style.rawValue)] \(title!)" : " [!\(style.rawValue)]"
            let nested = body.components(separatedBy: "\n").map { "> " + $0 }.joined(separator: "\n")
            return ">" + header + "\n" + nested
        case .blockquote(let text):
            return text.components(separatedBy: "\n").map { "> " + $0 }.joined(separator: "\n")
        case .latex(let equation, let isDisplay):
            return isDisplay ? "$$\n\(equation)\n$$" : "$\(equation)$"
        case .horizontalRule:
            return "---"
        case .genui(let payload):
            return "<genui>\n\(payload)\n</genui>"
        default:
            return ""
        }
    }
    
    static func splitIntoBlockItems(_ text: String) -> [NoteBlockItem] {
        let blocks = SlateMarkdownParser.parse(text)
        var items = [NoteBlockItem]()
        var currentNormalBlocks = [SlateBlock]()
        
        func flushNormal() {
            guard !currentNormalBlocks.isEmpty else { return }
            
            var raw = ""
            for (idx, block) in currentNormalBlocks.enumerated() {
                let serialized = serializeNormalBlock(block)
                if idx == 0 {
                    raw = serialized
                } else {
                    raw += "\n" + serialized
                }
            }
            
            if !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items.append(NoteBlockItem(isSpecial: false, rawText: raw, block: .paragraph(raw)))
            }
            currentNormalBlocks.removeAll()
        }
        
        for block in blocks {
            switch block {
            case .codeBlock, .table, .alert, .blockquote, .latex, .horizontalRule, .genui:
                flushNormal()
                let raw = serializeSpecialBlock(block)
                items.append(NoteBlockItem(isSpecial: true, rawText: raw, block: block))
            default:
                currentNormalBlocks.append(block)
            }
        }
        
        flushNormal()
        
        // If the resulting items are empty, ensure there is at least one editable text block
        if items.isEmpty {
            items.append(NoteBlockItem(isSpecial: false, rawText: "", block: .paragraph("")))
        }
        
        return items
    }
    
    static func combineBlockItems(_ items: [NoteBlockItem]) -> String {
        return items.map { $0.rawText }.joined(separator: "\n")
    }
}
