//
//  CreateTabView.swift
//  Slate
//

import SwiftUI
import SwiftData

struct CreateTabView: View {
    // MARK: - Properties
    @State private var text: String = ""
    @State private var blockItems: [NoteBlockItem] = []
    @State private var focusedBlockID: UUID? = nil
    @State private var cursorPosition: Int? = nil
    @State private var selectedBlockID: UUID? = nil
    
    @Binding var editingNote: SlateModel?
    @Binding var activeTab: ContentView.TabIdentifier

    @Environment(\.modelContext) private var context
    @State private var showEmptyWarning: Bool = false
    @State private var isOrganizing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var wasTitlePreGenerated: Bool = false
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var isAnimatingText: Bool = false
    @State private var skeletonSessionID = UUID()
    
    private var typedLinesCount: Int {
        if text.isEmpty { return 0 }
        return text.components(separatedBy: "\n").count
    }

    // MARK: - UI Code
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($blockItems) { $item in
                        Group {
                            if item.isSpecial {
                                SpecialBlockWrapper(
                                    isSelected: selectedBlockID == item.id,
                                    onTap: {
                                        selectedBlockID = item.id
                                        focusedBlockID = nil
                                    },
                                    onBackspace: {
                                        handleDeleteSpecialBlock(id: item.id)
                                    }
                                ) {
                                    MarkdownStaticPreview(block: item.block)
                                }
                            } else {
                                NativeTextView(
                                    id: item.id,
                                    text: $item.rawText,
                                    focusedBlockID: $focusedBlockID,
                                    cursorPosition: $cursorPosition,
                                    onEditingEnded: { handleEditingEnded() },
                                    onBackspaceAtStart: {
                                        handleBackspaceAtStart(item: item)
                                    },
                                    onDeleteAtEnd: {
                                        handleDeleteAtEnd(item: item)
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .simultaneousGesture(TapGesture().onEnded {
                                    selectedBlockID = nil
                                })
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity
                                .combined(with: .move(edge: .bottom))
                                .animation(.spring(response: 0.35, dampingFraction: 0.75)),
                            removal: .identity
                        ))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            
            if isAnimatingText || isOrganizing {
                SkeletonView(typedLinesCount: typedLinesCount)
                    .id(skeletonSessionID)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            loadNote(editingNote)
        }
        .onChange(of: editingNote) { _, newValue in
            loadNote(newValue)
        }
        .onChange(of: text) { _, newValue in
            if isOrganizing {
                blockItems = NoteBlockUtility.splitIntoBlockItems(newValue)
            }
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
                .disabled(isAnimatingText || isOrganizing || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        text = NoteBlockUtility.combineBlockItems(blockItems)
        let trimmedDesc = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDesc.isEmpty {
            showEmptyWarning = true
            return
        }
        
        let targetNote: SlateModel
        // Placeholder title — AI will overwrite this immediately in background.
        let initialTitle = generateInitialTitle(from: trimmedDesc)
        
        if let note = editingNote {
            note.desc = trimmedDesc
            // Only set a placeholder title if the note doesn't have one yet.
            if note.title.isEmpty {
                note.title = initialTitle
            }
            targetNote = note
            // Draft notes from chat are not in the DB yet — insert them now.
            if targetNote.modelContext == nil {
                context.insert(targetNote)
            }
        } else {
            targetNote = SlateModel(title: initialTitle, desc: trimmedDesc)
            context.insert(targetNote)
        }
        
        // AI generates the real title in background; wasTitlePreGenerated is only
        // true for notes whose titles were set by the "Organize with AI" flow.
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
        blockItems = NoteBlockUtility.splitIntoBlockItems("")
        editingNote = nil
        isAnimatingText = false
        animationTask?.cancel()
    }
    
    private func loadNote(_ note: SlateModel?) {
        if let note = note {
            text = note.desc
            blockItems = NoteBlockUtility.splitIntoBlockItems(note.desc)
            wasTitlePreGenerated = !note.title.isEmpty && note.title != "New Note"
        } else {
            text = ""
            blockItems = NoteBlockUtility.splitIntoBlockItems("")
            wasTitlePreGenerated = false
        }
    }
    
    private func handleEditingEnded() {
        let combined = NoteBlockUtility.combineBlockItems(blockItems)
        text = combined
        let parsed = NoteBlockUtility.splitIntoBlockItems(combined)
        if parsed != blockItems {
            withAnimation(.easeInOut(duration: 0.25)) {
                blockItems = parsed
            }
        }
    }
    
    private func generateInitialTitle(from text: String) -> String {
        // Skip any leading # characters so they don't leak into the title
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
    

    
    private func animateBlocksOneByOne(_ fullText: String) {
        animationTask?.cancel()
        
        let finalBlocks = NoteBlockUtility.splitIntoBlockItems(fullText)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimatingText = true
            blockItems = []
            text = ""
        }
        
        animationTask = Task { @MainActor in
            for blockItem in finalBlocks {
                guard !Task.isCancelled else { break }
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    blockItems.append(blockItem)
                }
                
                // Keep the 'text' property in sync with the current combined blocks
                text = NoteBlockUtility.combineBlockItems(blockItems)
                
                HapticManager.triggerSelection()
                
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimatingText = false
            }
        }
    }
}


// MARK: - Special Block Deletion/Merging Helpers
extension CreateTabView {
    private func handleBackspaceAtStart(item: NoteBlockItem) {
        guard let index = blockItems.firstIndex(where: { $0.id == item.id }) else { return }
        guard index > 0 else { return }
        
        let precedingIndex = index - 1
        let precedingItem = blockItems[precedingIndex]
        
        if precedingItem.isSpecial {
            HapticManager.trigger(.medium)
            
            withAnimation(.easeInOut(duration: 0.2)) {
                _ = blockItems.remove(at: precedingIndex)
            }
            
            let newPrecedingIndex = precedingIndex - 1
            if newPrecedingIndex >= 0 {
                let aboveItem = blockItems[newPrecedingIndex]
                if !aboveItem.isSpecial {
                    let currentBlockIndex = precedingIndex
                    let currentItem = blockItems[currentBlockIndex]
                    
                    let originalLength = aboveItem.rawText.count
                    let mergedText = aboveItem.rawText + (currentItem.rawText.isEmpty ? "" : "\n" + currentItem.rawText)
                    
                    blockItems[newPrecedingIndex].rawText = mergedText
                    blockItems.remove(at: currentBlockIndex)
                    
                    focusedBlockID = aboveItem.id
                    cursorPosition = originalLength
                } else {
                    focusedBlockID = item.id
                    cursorPosition = 0
                }
            } else {
                focusedBlockID = item.id
                cursorPosition = 0
            }
            
            text = NoteBlockUtility.combineBlockItems(blockItems)
        }
    }
    
    private func handleDeleteAtEnd(item: NoteBlockItem) {
        guard let index = blockItems.firstIndex(where: { $0.id == item.id }) else { return }
        guard index < blockItems.count - 1 else { return }
        
        let succeedingIndex = index + 1
        let succeedingItem = blockItems[succeedingIndex]
        
        if succeedingItem.isSpecial {
            HapticManager.trigger(.medium)
            
            withAnimation(.easeInOut(duration: 0.2)) {
                _ = blockItems.remove(at: succeedingIndex)
            }
            
            if succeedingIndex < blockItems.count {
                let belowItem = blockItems[succeedingIndex]
                if !belowItem.isSpecial {
                    let originalLength = item.rawText.count
                    let mergedText = item.rawText + (belowItem.rawText.isEmpty ? "" : "\n" + belowItem.rawText)
                    
                    blockItems[index].rawText = mergedText
                    blockItems.remove(at: succeedingIndex)
                    
                    focusedBlockID = item.id
                    cursorPosition = originalLength
                } else {
                    focusedBlockID = item.id
                    cursorPosition = item.rawText.count
                }
            } else {
                focusedBlockID = item.id
                cursorPosition = item.rawText.count
            }
            
            text = NoteBlockUtility.combineBlockItems(blockItems)
        }
    }
    
    private func handleDeleteSpecialBlock(id: UUID) {
        guard let index = blockItems.firstIndex(where: { $0.id == id }) else { return }
        let item = blockItems[index]
        guard item.isSpecial else { return }
        
        HapticManager.trigger(.medium)
        
        selectedBlockID = nil
        
        var targetFocusBlockID: UUID? = nil
        var targetCursorPos: Int? = nil
        
        let hasAboveText = index > 0 && !blockItems[index - 1].isSpecial
        let hasBelowText = index < blockItems.count - 1 && !blockItems[index + 1].isSpecial
        
        if hasAboveText && hasBelowText {
            let aboveItem = blockItems[index - 1]
            let belowItem = blockItems[index + 1]
            let originalLength = aboveItem.rawText.count
            let mergedText = aboveItem.rawText + (belowItem.rawText.isEmpty ? "" : "\n" + belowItem.rawText)
            
            blockItems[index - 1].rawText = mergedText
            blockItems.remove(at: index + 1)
            blockItems.remove(at: index)
            
            targetFocusBlockID = aboveItem.id
            targetCursorPos = originalLength
        } else if hasAboveText {
            targetFocusBlockID = blockItems[index - 1].id
            targetCursorPos = blockItems[index - 1].rawText.count
            blockItems.remove(at: index)
        } else if hasBelowText {
            targetFocusBlockID = blockItems[index + 1].id
            targetCursorPos = 0
            blockItems.remove(at: index)
        } else {
            blockItems.remove(at: index)
        }
        
        if blockItems.isEmpty {
            let newTextItem = NoteBlockItem(isSpecial: false, rawText: "", block: .paragraph(text: ""))
            blockItems.append(newTextItem)
            targetFocusBlockID = newTextItem.id
            targetCursorPos = 0
        }
        
        if let focusID = targetFocusBlockID {
            focusedBlockID = focusID
            cursorPosition = targetCursorPos
        }
        
        text = NoteBlockUtility.combineBlockItems(blockItems)
    }
}

