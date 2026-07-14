//
//  SlateTabView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-07.
//

import SwiftUI
import SwiftData

struct SlateTabView: View {
    // MARK: - Properties
    @Environment(\.modelContext) private var context
    @Query(sort: \SlateModel.created_at, order: .reverse) private var notes: [SlateModel]
    
    @State private var noteToShare: SlateModel?
    @State private var showShareOptions = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    let onOpenSettings: () -> Void
    let onCreate: () -> Void
    let onSelect: (SlateModel) -> Void

    // MARK: - Initializer
    init(
        onOpenSettings: @escaping () -> Void = {},
        onCreate: @escaping () -> Void = {},
        onSelect: @escaping (SlateModel) -> Void = { _ in }
    ) {
        self.onOpenSettings = onOpenSettings
        self.onCreate = onCreate
        self.onSelect = onSelect
    }

    // MARK: - UI Code
    var body: some View {
        ZStack {
            List {
                ForEach(notes) { note in
                    Button {
                        onSelect(note)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(note.title)
                                .font(.system(size: 17))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(renderPreview(for: note.desc))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                                .lineHeight(.loose)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            context.delete(note)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("Share", systemImage: "square.and.arrow.up") {
                            noteToShare = note
                            showShareOptions = true
                        }
                        .tint(.accentColor)
                    }
                    .confirmationDialog("Share Slate", isPresented: Binding(
                        get: { showShareOptions && noteToShare == note },
                        set: { if !$0 { showShareOptions = false; noteToShare = nil } }
                    ), titleVisibility: .visible) {
                        Button("Share Richtext") {
                            let itemSource = NoteItemSource(note: note)
                            shareItems = [itemSource]
                            showShareSheet = true
                        }
                        
                        Button("Save as PDF") {
                            if let pdfURL = NoteSharingHelper.generatePDF(for: note) {
                                shareItems = [pdfURL]
                                showShareSheet = true
                            }
                        }
                        
                        Button("Save as Text") {
                            if let textURL = NoteSharingHelper.generateTextFile(for: note) {
                                shareItems = [textURL]
                                showShareSheet = true
                            }
                        }
                    }
                }
            }
            .overlay {
                if notes.isEmpty {
                    ContentUnavailableView(
                        "Hello !",
                        systemImage: "scribble.variable",
                        description: Text("Let's slate down something useful!")
                    )
                }
            }
        }
        .navigationTitle("Slate")
        .toolbarTitleDisplayMode(.automatic)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    onOpenSettings()
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
                .presentationDetents([.medium, .large])
        }
    }
    // MARK: - Supporting Functions
    
    private func renderPreview(for text: String) -> AttributedString {
        let blocks = MarkdownParser.parse(text)
        var markdownParts: [String] = []
        
        func processBlocks(_ blocks: [MarkdownBlock]) {
            for block in blocks {
                switch block {
                case .paragraph(let text):
                    markdownParts.append(text)
                    
                case .header(_, let text):
                    markdownParts.append("**\(text)**")
                    
                case .blockquote(let nestedBlocks):
                    let currentCount = markdownParts.count
                    processBlocks(nestedBlocks)
                    let addedRange = currentCount..<markdownParts.count
                    for idx in addedRange {
                        markdownParts[idx] = "*\(markdownParts[idx])*"
                    }
                    
                case .list(let items):
                    for item in items {
                        let prefix: String
                        if let state = item.checkboxState {
                            prefix = state == .checked ? "☑ ~~\(item.text)~~" : "☐ \(item.text)"
                            markdownParts.append(prefix)
                        } else {
                            switch item.type {
                            case .bullet:
                                prefix = "• \(item.text)"
                            case .numbered(let number):
                                prefix = "\(number). \(item.text)"
                            }
                            markdownParts.append(prefix)
                        }
                    }
                    
                case .code(let language, let code):
                    let displayLang = language?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? language! : "Plain"
                    let firstLine = code.components(separatedBy: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
                    markdownParts.append("**💻 Code (\(displayLang))**: `\(firstLine)`")
                    
                case .table(let headers, _, _):
                    let headerString = headers.joined(separator: " | ")
                    markdownParts.append("**📊 Table**: \(headerString)")
                    
                case .thematicBreak:
                    markdownParts.append("---")
                    
                case .latex(_, let equation):
                    let singleLineEq = equation.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                    markdownParts.append("**🧮 Math**: `\(singleLineEq)`")
                    
                case .alert(let type, let nestedBlocks):
                    let emoji: String
                    switch type {
                    case .note: emoji = "ℹ️"
                    case .tip: emoji = "💡"
                    case .important: emoji = "⚠️"
                    case .warning: emoji = "⚠️"
                    case .caution: emoji = "🛑"
                    }
                    let alertTitle = "**\(emoji) \(type.rawValue.capitalized)**: "
                    let currentCount = markdownParts.count
                    processBlocks(nestedBlocks)
                    let addedRange = currentCount..<markdownParts.count
                    if addedRange.isEmpty {
                        markdownParts.append(alertTitle)
                    } else {
                        markdownParts[addedRange.lowerBound] = alertTitle + markdownParts[addedRange.lowerBound]
                    }
                    
                case .image(let caption, _):
                    let displayCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? caption : "photo"
                    markdownParts.append("**🖼️ Image**: \(displayCaption)")
                }
            }
        }
        
        processBlocks(blocks)
        let cleanedText = markdownParts.joined(separator: "\n")
        
        var options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        options.allowsExtendedAttributes = true
        
        if let attrStr = try? AttributedString(markdown: cleanedText, options: options) {
            return attrStr
        } else {
            return AttributedString(cleanedText)
        }
    }
    

}

// MARK: - Previews
#Preview {
  ContentView()
}
