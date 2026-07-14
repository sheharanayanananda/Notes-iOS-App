//
//  SlateMarkdownView.swift
//  Slate
//
//  Reusable wrapper: parses a markdown String and renders it as blocks.
//  Use in Chat (pass messageID for GenUI state) and Notes (no messageID).
//

import SwiftUI

struct SlateMarkdownView: View {
    let content: String
    var messageID: String? = nil
    var isFullWidth: Bool = true

    var body: some View {
        let blocks = SlateMarkdownParser.parse(content)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                SlateBlockView(block: block, messageID: messageID)
            }
        }
        .frame(maxWidth: isFullWidth ? .infinity : nil, alignment: .leading)
    }
}
