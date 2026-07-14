//
//  CreateTabView.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI
import SwiftData
import MarkdownUI

struct CreateTabView: View {
    // MARK: - Properties
    @State private var text: String = ""
    @State private var isEditMode: Bool = true
    
    @Binding var editingNote: SlateModel?
    @Binding var activeTab: ContentView.TabIdentifier

    @Environment(\.modelContext) private var context
    @State private var showEmptyWarning: Bool = false
    @State private var isOrganizing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var wasTitlePreGenerated: Bool = false
    
    // MARK: - UI Code
    var body: some View {
        VStack(spacing: 0) {
            // Edit/Preview Segment Control at the top
            Picker("Mode", selection: $isEditMode) {
                Text("Edit").tag(true)
                Text("Preview").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            
            if isEditMode {
                // Raw Markdown Text Editor
                TextEditor(text: $text)
                    .font(.system(size: 16))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            } else {
                // Rendered Markdown Preview
                ScrollView {
                    Markdown(text)
                        .markdownTheme(.gitHub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
            }
        }
        .onAppear {
            loadNote(editingNote)
        }
        .onChange(of: editingNote) { _, newValue in
            loadNote(newValue)
        }
        .navigationTitle((editingNote == nil || editingNote?.modelContext == nil) ? "New Note" : (editingNote?.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? editingNote!.title : "Edit Note"))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark", role: .cancel) {
                    cancel()
                }
                .disabled(isOrganizing)
            }
                        
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", role: .confirm) {
                    saveNote()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isOrganizing || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Empty Note", isPresented: $showEmptyWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Can't save an empty note.")
        }
        .alert("Organizer Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }
}

// MARK: - Main Functions
extension CreateTabView {
    private func saveNote() {
        let trimmedDesc = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDesc.isEmpty {
            showEmptyWarning = true
            return
        }
        
        let targetNote: SlateModel
        let initialTitle = generateInitialTitle(from: trimmedDesc)
        
        if let note = editingNote {
            note.desc = trimmedDesc
            if note.title.isEmpty {
                note.title = initialTitle
            }
            targetNote = note
            if targetNote.modelContext == nil {
                context.insert(targetNote)
            }
        } else {
            targetNote = SlateModel(title: initialTitle, desc: trimmedDesc)
            context.insert(targetNote)
        }
        
        if !wasTitlePreGenerated {
            Task {
                await generateTitleInBackground(for: targetNote, content: trimmedDesc)
            }
        }
        
        reset()
        activeTab = .notes
    }
    
    private func cancel() {
        reset()
        activeTab = .notes
    }
}

// MARK: - Supporting Functions
extension CreateTabView {
    private func reset() {
        text = ""
        editingNote = nil
    }
    
    private func loadNote(_ note: SlateModel?) {
        if let note = note {
            text = note.desc
            wasTitlePreGenerated = !note.title.isEmpty && note.title != "New Note"
        } else {
            text = ""
            wasTitlePreGenerated = false
        }
    }
    
    private func generateInitialTitle(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
        let words = cleaned.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let firstThree = words.prefix(3).joined(separator: " ")
        return firstThree.isEmpty ? "New Note" : firstThree
    }
    
    private func generateTitleInBackground(for note: SlateModel, content: String) async {
        do {
            let client = OllamaClient()
            let systemPrompt = SystemPrompts.titleGeneration
            let title = try await client.generate(
                prompt: content,
                system: systemPrompt
            )
            let trimmedTitle = title
                .replacingOccurrences(of: "\r", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                await MainActor.run {
                    note.title = trimmedTitle
                }
            }
        } catch {
            print("Failed to generate title in background: \(error.localizedDescription)")
        }
    }
}
