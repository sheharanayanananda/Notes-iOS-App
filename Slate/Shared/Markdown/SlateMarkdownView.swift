//
//  SlateMarkdownView.swift
//  Slate
//
//  Reusable wrapper: parses a markdown String and renders it as blocks.
//  Use in Chat (pass messageID for GenUI state) and Notes (no messageID).
//

import SwiftUI

enum BlockCategory {
    case heading
    case paragraph
    case list
    case code
    case blockquote
    case alert
    case table
    case hr
    case genui
    case latexDisplay
    case latexInline
}

struct SlateMarkdownView: View {
    let content: String
    var messageID: String? = nil
    var isFullWidth: Bool = true

    var body: some View {
        let blocks = SlateMarkdownParser.parse(content)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                SlateBlockView(block: block, messageID: messageID)
                
                if index < blocks.count - 1 {
                    Spacer()
                        .frame(height: spacing(between: block, and: blocks[index + 1]))
                }
            }
        }
        .frame(maxWidth: isFullWidth ? .infinity : nil, alignment: .leading)
    }

    private func category(for block: SlateBlock) -> BlockCategory {
        switch block {
        case .heading: return .heading
        case .paragraph: return .paragraph
        case .checklist, .bulletList, .numberedList: return .list
        case .codeBlock: return .code
        case .blockquote: return .blockquote
        case .alert: return .alert
        case .table: return .table
        case .horizontalRule: return .hr
        case .genui: return .genui
        case .latex(_, let isDisplay): return isDisplay ? .latexDisplay : .latexInline
        }
    }

    private func padding(for cat: BlockCategory) -> CGFloat {
        switch cat {
        case .heading, .paragraph: return 0
        case .list: return 4
        case .blockquote: return 6
        case .hr: return 6
        case .code, .alert, .table, .genui, .latexDisplay: return 8
        case .latexInline: return 2
        }
    }

    private func spacing(between current: SlateBlock, and next: SlateBlock) -> CGFloat {
        let cat1 = category(for: current)
        let cat2 = category(for: next)
        
        let pad1 = padding(for: cat1)
        let pad2 = padding(for: cat2)
        
        // If they are of the same type, we selectively reduce the gap
        if cat1 == cat2 {
            switch cat1 {
            case .alert:
                return 8  // Reduced gap for consecutive alerts
            case .list:
                return 4  // Reduced gap for consecutive lists (like task lists)
            case .blockquote:
                return 6  // Reduced gap for consecutive blockquotes
            default:
                // For other matching categories (like consecutive paragraphs), preserve the original gap
                return pad1 + 10 + pad2
            }
        }
        
        // Default spacing matches the original ad-hoc layout spacing exactly
        return pad1 + 10 + pad2
    }
}
