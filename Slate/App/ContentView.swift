//
//  ContentView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-07.
//

import SwiftUI
import SwiftData
import Vision
import ImageIO

struct ContentView: View {

    enum TabIdentifier: Hashable {
        case notes, create, intelligence, settings
    }

    @State private var activeTab: TabIdentifier = .intelligence
    @State private var editingNote: SlateModel? = nil
    @State private var quickTool: ToolType? = nil
    @State private var showSettings = false
    @State private var showChatView = true

    @State private var isSettingsVisible = false
    @State private var isSettingsInteractable = false
    @State private var settingsViewModel = SettingsViewModel()
    @State private var settingsTransitionTask: Task<Void, Never>? = nil

    // Smart Lens Scanner and Processing States
    @State private var showScanner = false
    @State private var isProcessing = false
    @State private var processStatus = ""
    @State private var processState: ProcessState = .analyzing
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var lensResultText = ""

    enum ProcessState {
        case analyzing
        case completed
        case failed
    }

    @Environment(\.modelContext) private var context

    private func settingsXOffset(screenWidth: CGFloat) -> CGFloat {
        if showSettings {
            return 0
        } else {
            return -screenWidth
        }
    }

    //----------------- Start of UI Code -----------------//
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            ZStack {
                TabView(selection: $activeTab) {
                    Tab("Slate", systemImage: "scribble.variable", value: .notes) {
                        NavigationStack {
                            SlateTabView(
                                showSettings: $showSettings,
                                onOpenSettings: {
                                    isSettingsVisible = true
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showSettings = true
                                    }
                                },
                                onCreate: {
                                    editingNote = nil
                                    activeTab = .create
                                },
                                onSelect: { note in
                                    editingNote = note
                                    activeTab = .create
                                },
                                onSmartLens: { showScanner = true },
                                onScribe: { quickTool = .scribe }
                            )
                        }
                    }
                    
                    Tab((editingNote == nil || editingNote?.modelContext == nil) ? "New" : "Edit", systemImage: "plus", value: .create) {
                        NavigationStack {
                            CreateTabView(
                                editingNote: $editingNote,
                                activeTab: $activeTab,
                                isLensProcessing: $isProcessing,
                                lensStatus: $processStatus,
                                lensResultText: $lensResultText
                            )
                        }
                    }
                    
                    Tab("Chat", systemImage: "apple.intelligence", value: .intelligence, role: .search) {
                        Color.clear
                    }
                }
                .sheet(item: $quickTool) { tool in
                    ToolSheet(type: tool, editingNote: $editingNote, activeTab: $activeTab)
                }

                if showChatView {
                    NavigationStack {
                        ChatView(activeTab: $activeTab)
                    }
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
                }


                if isSettingsVisible {
                    NavigationStack {
                        SettingsView(
                            viewModel: settingsViewModel,
                            onDismiss: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showSettings = false
                                }
                            }
                        )
                        .disabled(!isSettingsInteractable)
                    }
                    .offset(x: settingsXOffset(screenWidth: screenWidth))
                    .zIndex(1)
                }
            }
            .onChange(of: showSettings) { oldValue, newValue in
                settingsTransitionTask?.cancel()
                isSettingsInteractable = false
                
                settingsTransitionTask = Task { @MainActor in
                    if newValue {
                        isSettingsVisible = true
                        
                        // Wait for 0.2s for haptic
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        guard !Task.isCancelled else { return }
                        
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred()
                        
                        // Wait another 0.15s to enable interactions (total 0.35s)
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        
                        isSettingsInteractable = true
                    } else {
                        // Wait 0.35s for slide-out animation to finish
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard !Task.isCancelled else { return }
                        
                        isSettingsVisible = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView(onScanCompleted: { image in
                    showScanner = false
                    if let image = image {
                        processScannedImage(image)
                    }
                }, onCancel: {
                    showScanner = false
                })
                .ignoresSafeArea()
            }
            .alert("AI Feature Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .onChange(of: activeTab) { oldValue, newValue in
                if newValue == .intelligence {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
                        showChatView = true
                    }
                } else if oldValue == .intelligence {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) {
                        showChatView = false
                    }
                }
            }
        }
    }
    
    // Background Processing: Vision Extraction (OCR & Classification) and Ollama API Request
    private func processScannedImage(_ image: UIImage) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = true
            processState = .analyzing
            processStatus = "Extracting details..."
            
            // Immediately navigate to the Create tab and reset editing state
            activeTab = .create
            editingNote = nil
            lensResultText = ""
        }
        
        Task {
            // Run native OCR and classification in parallel on the device
            async let ocrText = performOCR(on: image)
            async let classifications = performClassification(on: image)
            
            let resolvedOcr = await ocrText
            let resolvedClassifications = await classifications
            
            await MainActor.run {
                processStatus = "Analyzing Content..."
            }
            
            do {
                let client = OllamaClient()
                
                let systemPrompt = """
                Act as an Intelligent Note-Taking Assistant (Smart Lens). You are given a photo scanned by the user, along with on-device Apple Vision text recognition (OCR) and image classification context.
                
                Your goal is to synthesize a highly organized, professional, and clean Markdown note based on this combined input.
                
                ### Context from Device:
                - OCR Extracted Text: \(resolvedOcr)
                - Detected Objects/Scenes: \(resolvedClassifications)
                
                ### Strict Formatting Rules:
                1. **First Line (Title)**: Output ONLY a concise, suitable title (maximum 4 words) as the very first line of your response. Do NOT use markdown headers (#), bolding (**), quotes, or emojis for the title.
                2. **No Markdown Headers**: Do NOT use `#`, `##`, `###`, etc., anywhere in the note. For section divisions, use bold text (e.g., `**Section Name**`) or underlined text (e.g., `<u>Section Name</u>`) on a separate line.
                3. **Supported Formattings ONLY**: You must ONLY use the following elements for structure:
                   - Checklists: `- [ ] Item` (use for tasks, todos, shopping items, lists of items to acquire/buy)
                   - Bullet lists: `- Item` (use for details, lists, summaries)
                   - Numbered lists: `1. Item` (use for sequences, chronological steps, recipes)
                   - Indentation: Prepend exactly 2 spaces per indentation level for nested sub-points (e.g. `  - Sub-point` or `  - [ ] Sub-task`)
                   - Inline styles: Bold `**text**`, Italic `*text*`, Underline `<u>text</u>`, Strikethrough `~~text~~`
                4. **Strictly Forbidden elements**:
                   - No Markdown tables (use bullet points or indented lists to organize attributes instead)
                   - No Blockquotes (>) or code blocks (```)
                   - No HTML tags except `<u>` and `</u>`
                   - No Emojis anywhere in the note (neither in the title nor body)
                5. **No Fenced Code Blocks**: Do NOT wrap your output in triple backticks or markdown code block syntax. Start directly with the title.
                6. **No Conversational Preamble**: Output ONLY the raw note. Do not say "Here is your note" or explain your formatting.
                
                ### Intelligence & Context Guidelines:
                - **Contextual Formatting**: Intelligently detect the intent behind the scan (e.g. shopping list, todo list, recipe, business card, textbook info, receipt).
                - **Shopping/Todo Lists**: If the scanned image contains lists of items to buy, tasks to perform, or actions, structure them as checkbox items: `- [ ] Item`. Do NOT apply bolding (`**`) or any other inline styling to the checkbox items; keep the item text as plain text.
                - **Recipes/Processes**: If the scanned image describes step-by-step instructions or procedures, format them as numbered lists: `1. Step`.
                - **Receipts/Financials**: Organize receipt data into key-value descriptions using bold and underline rather than tables, for example:
                  `**Merchant:** Store Name`
                  `**Total:** $12.34`
                  `  - Item 1: $10.00`
                  `  - Taxes: $2.34`
                - **Low/No-OCR Scenario**: If the "OCR Extracted Text" is empty or contains only a few characters, focus your response on describing the detected objects/scenes from "Detected Objects/Scenes" and any visual information you can extract from the image itself. Synthesize a note summarizing the photo's subject, context, and potential next steps or observations based on the visual contents.
                """
                
                let userPrompt = "Analyze this image and synthesize a clean note."
                let optimizedImage = image.resized(toMaxDimension: 1024)
                let response = try await client.generate(prompt: userPrompt, system: systemPrompt, image: optimizedImage)
                let parsed = parseResponse(response)
                
                await MainActor.run {
                    processState = .completed
                    processStatus = "Note Created"
                }
                
                try await Task.sleep(nanoseconds: 300_000_000)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isProcessing = false
                        editingNote = SlateModel(title: parsed.title, desc: "")
                        lensResultText = parsed.desc
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        processState = .failed
                        processStatus = "Failed to analyze"
                        isProcessing = false
                    }
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
                print("Failed to process scanned image: \(error)")
            }
        }
    }
    
    private func performOCR(on image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    private func performClassification(on image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let classifications = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(3)
                    .map { "\($0.identifier) (confidence: \(Int($0.confidence * 100))%)" }
                    .joined(separator: ", ")
                continuation.resume(returning: classifications)
            }
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    private func parseResponse(_ response: String) -> (title: String, desc: String) {
        var textToParse = response
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find content inside ```markdown ... ``` or ``` ... ```
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
        
        let lines = textToParse.components(separatedBy: .newlines)
        var title = "New Note"
        var descLines = [String]()
        var foundTitle = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if foundTitle {
                    descLines.append(line)
                }
                continue
            }
            
            // Skip any line starting with triple backticks
            if trimmed.hasPrefix("```") {
                continue
            }
            
            if !foundTitle {
                title = trimmed.replacingOccurrences(of: "#", with: "")
                    .replacingOccurrences(of: "**Title**:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                foundTitle = true
            } else {
                descLines.append(line)
            }
        }
        
        let desc = descLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, desc)
    }
}

#Preview {
    ContentView()
}

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let widthRatio  = maxDimension / size.width
        let heightRatio = maxDimension / size.height
        
        // Only scale down if the image is larger than the maxDimension
        guard widthRatio < 1.0 || heightRatio < 1.0 else {
            return self
        }
        
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Ensure scale is 1.0 to get exact pixel dimensions
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
