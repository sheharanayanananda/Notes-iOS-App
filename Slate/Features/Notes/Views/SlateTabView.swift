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
        let lines = text.components(separatedBy: .newlines)
            .map { line -> String in
                let cleaned = line.trimmingCharacters(in: .whitespaces)
                if cleaned.hasPrefix("#") {
                    return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
                } else if cleaned.hasPrefix("- [ ]") {
                    return "☐ " + cleaned.dropFirst(5).trimmingCharacters(in: .whitespaces)
                } else if cleaned.hasPrefix("- [x]") {
                    return "☑ " + cleaned.dropFirst(5).trimmingCharacters(in: .whitespaces)
                } else if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") {
                    return "• " + cleaned.dropFirst(2).trimmingCharacters(in: .whitespaces)
                }
                return cleaned
            }
            .filter { !$0.isEmpty }
        
        let previewText = lines.prefix(3).joined(separator: "\n")
        let mdOptions = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attrStr = try? AttributedString(markdown: previewText, options: mdOptions) {
            return attrStr
        }
        return AttributedString(previewText)
    }
    

}

// MARK: - Previews
#Preview {
  ContentView()
}
