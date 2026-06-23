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
    @AppStorage("is_demo_mode") private var isDemoMode = false
    
    private var displayedNotes: [SlateModel] {
        if isDemoMode {
            return SlateTabView.makeDemoNotes()
        } else {
            return notes
        }
    }
    
    @State private var noteToShare: SlateModel?
    @State private var showShareOptions = false
    @State private var showShareSheet = false
    @Binding var showSettings: Bool
    @State private var shareItems: [Any] = []

    let onOpenSettings: () -> Void
    let onCreate: () -> Void
    let onSelect: (SlateModel) -> Void
    let onSmartLens: () -> Void
    let onScribe: () -> Void

    // MARK: - Initializer
    init(
        showSettings: Binding<Bool>,
        onOpenSettings: @escaping () -> Void = {},
        onCreate: @escaping () -> Void = {},
        onSelect: @escaping (SlateModel) -> Void = { _ in },
        onSmartLens: @escaping () -> Void = {},
        onScribe: @escaping () -> Void = {}
    ) {
        self._showSettings = showSettings
        self.onOpenSettings = onOpenSettings
        self.onCreate = onCreate
        self.onSelect = onSelect
        self.onSmartLens = onSmartLens
        self.onScribe = onScribe
    }

    // MARK: - UI Code
    var body: some View {
        ZStack {
            List {
                ForEach(displayedNotes) { note in
                    Button {
                        onSelect(note)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(note.title.count > 20 ? String(note.title.prefix(20)) + "…" : note.title)
                                    .font(.system(size: 17))
                                    .truncationMode(.tail)
                                Spacer()
                                Text(note.created_at.formatted(date: .abbreviated, time: .shortened))
                                  .font(.caption)
                            }
                            Text(AttributedString(NativeTextView.parseToAttributed(text: note.desc, font: .systemFont(ofSize: 12))))
                              .lineLimit(3)
                              .lineHeight(.loose)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            if !isDemoMode {
                                context.delete(note)
                            }
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
                if displayedNotes.isEmpty {
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
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button("Scribe", systemImage: "waveform") {
                        onScribe()
                    }
//                    Button("Smart Lens", systemImage: "text.viewfinder") {
//                        onSmartLens()
//                    }
                }
            }
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
    static func makeDemoNotes() -> [SlateModel] {
        let note1 = SlateModel(title: "Welcome to Slate", desc: "Welcome to Slate! This is an intelligent, offline-first notes application.\n\n- [x] Create a new note\n- [ ] Try the AI Note Organizer\n- [ ] Explore the Smart Lens scanner\n- [ ] Customize settings\n\nDouble tap or tap directly on these checkboxes to toggle them!")
        note1.created_at = Date()
        
        let note2 = SlateModel(title: "Interactive Checklists", desc: "Checklists in Slate are fully interactive. Instead of manually entering edit mode, you can toggle checkboxes directly from the note list preview or the viewer.\n\nWrite checklist items using standard Markdown syntax:\n- [ ] Task 1\n- [x] Task 2\n\nSlate handles the rest!")
        note2.created_at = Date().addingTimeInterval(-60)
        
        let note3 = SlateModel(title: "AI Note Organizer", desc: "Unstructured notes are hard to read. Write down your messy thoughts, and tap the Sparkles icon in the editor toolbar. The AI will automatically clean up typos, fix grammar, and organize your text into structured bullet points and checklist items.")
        note3.created_at = Date().addingTimeInterval(-120)
        
        let note4 = SlateModel(title: "Smart Lens Visual AI", desc: "Tap the Smart Lens button to scan documents, whiteboards, or receipts. The app uses on-device Vision OCR to extract text and image classification to identify objects. The user-selected Gemma model then synthesizes a clean, context-aware note. If no text is found, it fallbacks to describing the visual scene.")
        note4.created_at = Date().addingTimeInterval(-180)
        
        let note5 = SlateModel(title: "Note Export Options", desc: "Need your note elsewhere? Swipe left on any note to open the share options:\n\n1. Share as Rich Text (RTF)\n2. Save and share as PDF document\n3. Export as plain text (.txt)")
        note5.created_at = Date().addingTimeInterval(-240)
        
        return [note1, note2, note3, note4, note5]
    }
}

// MARK: - Previews
#Preview {
  ContentView()
}
