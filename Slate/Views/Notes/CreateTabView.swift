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
    @Binding var isLensProcessing: Bool
    @Binding var lensStatus: String
    @Binding var lensResultText: String

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
                                BlockRenderer(block: item.block)
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
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            
            if isLensProcessing || isAnimatingText || isOrganizing {
                SkeletonView(typedLinesCount: typedLinesCount)
                    .id(skeletonSessionID)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            if let note = editingNote {
                text = note.desc
                blockItems = NoteBlockUtility.splitIntoBlockItems(note.desc)
                wasTitlePreGenerated = !note.title.isEmpty && note.title != "New Note"
            } else {
                text = ""
                blockItems = NoteBlockUtility.splitIntoBlockItems("")
                wasTitlePreGenerated = false
            }
        }
        .onChange(of: editingNote) { _, newValue in
            if let note = newValue {
                text = note.desc
                blockItems = NoteBlockUtility.splitIntoBlockItems(note.desc)
                wasTitlePreGenerated = !note.title.isEmpty && note.title != "New Note"
            } else {
                text = ""
                blockItems = NoteBlockUtility.splitIntoBlockItems("")
                wasTitlePreGenerated = false
            }
        }
        .onChange(of: text) { _, newValue in
            if isAnimatingText || isOrganizing {
                blockItems = NoteBlockUtility.splitIntoBlockItems(newValue)
            }
        }
        .onChange(of: lensResultText) { _, newValue in
            if !newValue.isEmpty {
                animateTextLineByLine(newValue)
            }
        }
        .onChange(of: isLensProcessing) { _, newValue in
            if newValue {
                skeletonSessionID = UUID()
            }
        }
        .navigationTitle((editingNote == nil || editingNote?.modelContext == nil) ? "New Note" : "Edit Note")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark", role: .cancel) {
                    cancel()
                }
                .disabled(isOrganizing)
            }
                        
            ToolbarItem(placement: .primaryAction) {
                if isOrganizing {
                    ProgressView()
                } else {
                    Button {
                        organizeNoteWithAI()
                    } label: {
                        Label("Organize with AI", systemImage: "sparkles")
                    }
                    .disabled(isAnimatingText || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
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
    
    private func organizeNoteWithAI() {
        let trimmedDesc = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDesc.isEmpty {
            errorMessage = "Can't organize an empty note."
            showErrorAlert = true
            return
        }
        
        animationTask?.cancel()
        skeletonSessionID = UUID()
        withAnimation(.easeInOut(duration: 0.3)) {
            isOrganizing = true
            isAnimatingText = false
            text = "" // Clear text immediately to display the skeleton loader
            blockItems = NoteBlockUtility.splitIntoBlockItems("")
        }
        
        Task {
            do {
                let client = OllamaClient()
                let organizedText = try await client.generate(
                    prompt: trimmedDesc,
                    system: aiSystemPrompt
                )
                let cleanedText = sanitizeMarkdown(organizedText)
                if !cleanedText.isEmpty {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isOrganizing = false
                        }
                        animateTextLineByLine(cleanedText)
                    }
                } else {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            text = trimmedDesc
                            isOrganizing = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        text = trimmedDesc
                        isOrganizing = false
                    }
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
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
        isLensProcessing = false
        isAnimatingText = false
        lensResultText = ""
        animationTask?.cancel()
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
            let systemPrompt = """
            You are a helpful assistant. Provide a highly concise, suitable title (maximum 4 words) for the following note content. 
            Respond ONLY with the title, without any quotes or punctuation around it.
            """
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
    
    private var aiSystemPrompt: String {
        """
        You are an expert note organizer. Your task is to analyze the content and context of the provided note and reorganize/summarize it to make it highly readable, clear, structured, and easy to use.
        
        You can use all Markdown formatting features supported by our editor:
        1. Headers: Use `#`, `##`, `###` for main headers and section titles.
        2. Checklists: `- [ ] Item` (use for tasks, todos, shopping items, checklists).
        3. Bullet lists: `- Item` (use for lists, details, brainstorms).
        4. Numbered lists: `1. Item` (use for sequences, chronological steps, recipes).
        5. Inline formatting: Bold `**text**`, Italic `*text*`, Underline `<u>text</u>`, Strikethrough `~~text~~`.
        6. Tables: Use standard Markdown table syntax `| header 1 | header 2 |` to organize structured tabular data.
        7. Code blocks: Use triple backticks ``` for snippets, calculations, or monospaced text segments.
        8. LaTeX: Use inline `$` or display `$$` blocks for mathematical equations and formulas.
        9. Alerts: Use GitHub-style alerts for important callouts (e.g., `> [!NOTE]` or `> [!TIP]`).
        10. Blockquotes: Use `>` for quotes or citations.
        
        ### Strictly Forbidden:
        - No HTML tags except `<u>` and `</u>`.
        - No Emojis anywhere in the note.
        - No Fenced Code Blocks around your entire output (do NOT wrap your entire response in triple backticks).
        - No Conversational Preamble or explanations. Output ONLY the raw note.
        """
    }
    
    private func sanitizeMarkdown(_ response: String) -> String {
        var textToParse = response
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let blockRange = textToParse.range(of: "```markdown") {
            let afterBlock = textToParse[blockRange.upperBound...]
            if let endBlockRange = afterBlock.range(of: "```") {
                textToParse = String(afterBlock[..<endBlockRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                textToParse = String(afterBlock).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if let blockRange = textToParse.range(of: "```") {
            let afterBlock = textToParse[blockRange.upperBound...]
            if let endBlockRange = afterBlock.range(of: "```") {
                textToParse = String(afterBlock[..<endBlockRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                textToParse = String(afterBlock).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return textToParse
    }
    
    private func animateTextLineByLine(_ fullText: String) {
        animationTask?.cancel()
        text = ""
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimatingText = true
        }
        
        let lines = fullText.components(separatedBy: "\n")
        
        animationTask = Task { @MainActor in
            for (index, line) in lines.enumerated() {
                guard !Task.isCancelled else { break }
                
                withAnimation(.easeOut(duration: 0.12)) {
                    if index == 0 {
                        text = line
                    } else {
                        text += "\n" + line
                    }
                }
                
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
                
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimatingText = false
            }
            lensResultText = ""
        }
    }
}

struct SkeletonLine: View {
    let width: CGFloat
    let delay: Double
    @State private var entranceOpacity: Double = 0.0
    
    var body: some View {
        TimelineView(.animation) { timelineContext in
            let date = timelineContext.date
            let timeInterval = date.timeIntervalSinceReferenceDate
            
            // Calculate phase from 0 to 1 based on time
            let phase = CGFloat((timeInterval).truncatingRemainder(dividingBy: 1.8) / 1.8)
            
            // Calculate pulse (breathing effect) from 0 to 1 using a sine wave
            let pulseFactor = CGFloat((sin(timeInterval * .pi / 0.6) + 1.0) / 2.0) // loops every 1.2s
            let fillOpacity = 0.04 + (0.04 * pulseFactor) // ranges from 0.04 to 0.08
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(fillOpacity))
                .frame(width: width, height: 16)
                .overlay(
                    GeometryReader { geo in
                        let size = geo.size
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear, 
                                Color.primary.opacity(0.12), 
                                Color.primary.opacity(0.04), 
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: size.width / 1.2)
                        .offset(x: -size.width + (size.width * 2) * phase)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(entranceOpacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.45).delay(delay)) {
                        entranceOpacity = 1.0
                    }
                }
        }
    }
}

struct SkeletonView: View {
    let typedLinesCount: Int
    @State private var appearanceOpacity: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let widths: [CGFloat] = [
                140, 300, 260, 280, 120, 240, 270, 180, 290, 250, 270, 190, 150
            ]
            
            ForEach(0..<widths.count, id: \.self) { index in
                if index >= typedLinesCount {
                    SkeletonLine(width: widths[index], delay: Double(index) * 0.035)
                        .transition(.opacity)
                } else {
                    Color.clear
                        .frame(height: 16)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .opacity(appearanceOpacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4)) {
                appearanceOpacity = 1.0
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
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
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
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
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
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
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

