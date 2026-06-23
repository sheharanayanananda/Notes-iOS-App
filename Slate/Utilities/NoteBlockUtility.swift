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
    var block: MarkdownBlock
    
    static func == (lhs: NoteBlockItem, rhs: NoteBlockItem) -> Bool {
        return lhs.isSpecial == rhs.isSpecial && lhs.rawText == rhs.rawText && lhs.block == rhs.block
    }
}

struct NoteBlockUtility {
    
    static func serializeNormalBlock(_ block: MarkdownBlock) -> String {
        switch block {
        case .paragraph(let text):
            return text
        case .header(let level, let text):
            return String(repeating: "#", count: level) + " " + text
        case .blockquote(let blocks):
            return blocks.map { serializeNormalBlock($0) }
                .joined(separator: "\n")
                .components(separatedBy: "\n")
                .map { "> " + $0 }
                .joined(separator: "\n")
        case .list(let items):
            return items.map { item in
                let prefix: String
                if let checkbox = item.checkboxState {
                    prefix = checkbox == .checked ? "- [x] " : "- [ ] "
                } else {
                    switch item.type {
                    case .bullet:
                        prefix = "- "
                    case .numbered(let number):
                        prefix = "\(number). "
                    }
                }
                return String(repeating: "  ", count: item.level) + prefix + item.text
            }.joined(separator: "\n")
        default:
            return ""
        }
    }
    
    static func splitIntoBlockItems(_ text: String) -> [NoteBlockItem] {
        let blocks = MarkdownParser.parse(text)
        var items = [NoteBlockItem]()
        var currentNormalBlocks = [MarkdownBlock]()
        
        func flushNormal() {
            guard !currentNormalBlocks.isEmpty else { return }
            let raw = currentNormalBlocks.map { serializeNormalBlock($0) }.joined(separator: "\n\n")
            if !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items.append(NoteBlockItem(isSpecial: false, rawText: raw, block: .paragraph(text: raw)))
            }
            currentNormalBlocks.removeAll()
        }
        
        for block in blocks {
            switch block {
            case .code, .table, .thematicBreak, .latex, .alert, .image:
                flushNormal()
                let raw: String
                switch block {
                case .code(let lang, let code):
                    raw = "```\(lang ?? "")\n\(code)\n```"
                case .table(let headers, let alignments, let rows):
                    let headerLine = "| " + headers.joined(separator: " | ") + " |"
                    let separatorLine = "| " + alignments.map { align in
                        switch align {
                        case .leading: return ":---"
                        case .center: return ":---:"
                        case .trailing: return "---:"
                        }
                    }.joined(separator: " | ") + " |"
                    let rowLines = rows.map { "| " + $0.joined(separator: " | ") + " |" }
                    raw = ([headerLine, separatorLine] + rowLines).joined(separator: "\n")
                case .thematicBreak:
                    raw = "---"
                case .latex(let isDisplay, let equation):
                    raw = isDisplay ? "$$\n\(equation)\n$$" : "$\(equation)$"
                case .alert(let type, let alertBlocks):
                    let nested = alertBlocks.map { serializeNormalBlock($0) }.joined(separator: "\n")
                    raw = "> [!\(type.rawValue)]\n" + nested.components(separatedBy: "\n").map { "> " + $0 }.joined(separator: "\n")
                case .image(let caption, let url):
                    raw = "![\(caption)](\(url))"
                default:
                    raw = ""
                }
                items.append(NoteBlockItem(isSpecial: true, rawText: raw, block: block))
            default:
                currentNormalBlocks.append(block)
            }
        }
        
        flushNormal()
        
        // If the resulting items are empty, ensure there is at least one editable text block
        if items.isEmpty {
            items.append(NoteBlockItem(isSpecial: false, rawText: "", block: .paragraph(text: "")))
        }
        
        return items
    }
    
    static func combineBlockItems(_ items: [NoteBlockItem]) -> String {
        return items.map { $0.rawText }.joined(separator: "\n\n")
    }
}
