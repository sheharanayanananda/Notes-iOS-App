//
//  MarkdownModels.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI

enum TableColumnAlignment: String, CaseIterable, Identifiable, Codable {
    case leading
    case center
    case trailing
    
    var id: String { self.rawValue }
}

enum AlertType: String, CaseIterable, Codable {
    case note = "NOTE"
    case tip = "TIP"
    case important = "IMPORTANT"
    case warning = "WARNING"
    case caution = "CAUTION"
    
    var iconName: String {
        switch self {
        case .note: return "info.circle.fill"
        case .tip: return "lightbulb.fill"
        case .important: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .caution: return "flame.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .note: return .blue
        case .tip: return .orange
        case .important: return .teal
        case .warning: return .yellow
        case .caution: return .red
        }
    }
}

enum MarkdownBlock: Identifiable, Equatable {
    var id: String {
        switch self {
        case .paragraph(let text): return "p-\(text.hashValue)"
        case .header(let level, let text): return "h-\(level)-\(text.hashValue)"
        case .blockquote(let nestedBlocks): return "bq-\(nestedBlocks.map { $0.id }.joined().hashValue)"
        case .list(let items): return "list-\(items.map { $0.text }.joined().hashValue)"
        case .code(_, let code): return "code-\(code.hashValue)"
        case .table(let headers, _, let rows): return "table-\((headers.joined() + rows.flatMap { $0 }.joined()).hashValue)"
        case .thematicBreak: return "hr"
        case .latex(let isDisplay, let equation): return "latex-\(isDisplay)-\(equation.hashValue)"
        case .alert(let type, let blocks): return "alert-\(type.rawValue)-\(blocks.map { $0.id }.joined().hashValue)"
        case .image(let caption, let url): return "img-\(caption.hashValue)-\(url.hashValue)"
        }
    }
    
    var isBlockElement: Bool {
        switch self {
        case .paragraph: return false
        default: return true
        }
    }
    
    case paragraph(text: String)
    case header(level: Int, text: String)
    case blockquote(blocks: [MarkdownBlock])
    case list(items: [MarkdownListItem])
    case code(language: String?, code: String)
    case table(headers: [String], alignments: [TableColumnAlignment], rows: [[String]])
    case thematicBreak
    case latex(isDisplay: Bool, equation: String)
    case alert(type: AlertType, blocks: [MarkdownBlock])
    case image(caption: String, urlString: String)
}

struct MarkdownListItem: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let type: ListType
    let checkboxState: CheckboxState?
    let text: String
    
    enum ListType: Equatable {
        case bullet
        case numbered(number: Int)
    }
    
    enum CheckboxState: Equatable {
        case checked
        case unchecked
    }
}
