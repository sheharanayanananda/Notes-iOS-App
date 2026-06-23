//
//  ChatInputCapsuleView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-21.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatCapsule: View {
    // MARK: - Properties
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    @Binding var selectedImages: [UIImage]
    @Binding var selectedDocuments: [OllamaDocumentAttachment]
    var isGenerating: Bool
    var isTextFieldDisabled: Bool
    var isInputFocused: FocusState<Bool>.Binding
    var onSend: () -> Void
    
    private var isMultiline: Bool {
        text.contains("\n") || text.count > 36 || !selectedImages.isEmpty || !selectedDocuments.isEmpty
    }
    
    private var currentCornerRadius: CGFloat {
        isMultiline ? 33 : 35
    }
    
    // MARK: - UI Components
    private var plusButton: some View {
        Menu {
            Button(action: {
                showPhotoPicker = true
            }) {
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            
            Button(action: {
                showCamera = true
            }) {
                Label("Camera", systemImage: "camera")
            }
            
            Button(action: {
                showDocumentPicker = true
            }) {
                Label("Documents", systemImage: "doc.text")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
    }
    
    private var micButton: some View {
        Button(action: {
            // Microphone Action
        }) {
            Image(systemName: "mic")
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isGenerating)
    }
    
    private var sendButton: some View {
        Button(action: {
            onSend()
        }) {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .frame(width: 36, height: 36)
                .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating ? Color.primary.opacity(0.3) : Color.primary)
                .clipShape(Circle())
        }
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
        .animation(.easeInOut(duration: 0.3), value: isGenerating)
    }
    
    // MARK: - UI Code
    var body: some View {
        VStack(alignment: .leading, spacing: isMultiline ? 12 : 0) {
            // 1. Attachment Previews Area (Images & Documents)
            if !selectedImages.isEmpty || !selectedDocuments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Render Images
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, uiImage in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedImages.remove(at: index)
                                        if selectedItems.indices.contains(index) {
                                            selectedItems.remove(at: index)
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(Color.primary, Color(uiColor: .systemBackground))
                                        .font(.system(size: 22))
                                }
                                .offset(x: 6, y: -6)
                            }
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                        }
                        
                        // Render Documents
                        ForEach(selectedDocuments) { doc in
                            ZStack(alignment: .topTrailing) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    
                                    Text(doc.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .frame(width: 110, height: 72, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                )
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        if let idx = selectedDocuments.firstIndex(of: doc) {
                                            selectedDocuments.remove(at: idx)
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(Color.primary, Color(uiColor: .systemBackground))
                                        .font(.system(size: 22))
                                }
                                .offset(x: 6, y: -6)
                            }
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, 8)
            }
            
            // 2. Main Row (Textfield & Inline buttons in single-line mode)
            HStack(alignment: .bottom, spacing: 12) {
                if !isMultiline {
                    plusButton
                }
                
                TextField("Ask Slate", text: $text, axis: .vertical)
                    .font(.system(size: 16))
                    .lineSpacing(5)
                    .textFieldStyle(.plain)
                    .focused(isInputFocused)
                    .disabled(isTextFieldDisabled)
                    .opacity(isGenerating ? 0.6 : 1.0)
                    .lineLimit(1...6)
                    .frame(minHeight: 36)
                    .onSubmit {
                        onSend()
                    }
                
                if !isMultiline {
                    sendButton
                }
            }
            
            // 3. Multi-line Action Row (Plus and Send slide down below)
            if isMultiline {
                HStack(spacing: 12) {
                    plusButton
                    Spacer()
                    sendButton
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: currentCornerRadius))
                .onTapGesture {
                    isInputFocused.wrappedValue = true
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isMultiline)
        .padding(.horizontal, 21)
        .padding(.bottom, 4)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { capturedImage in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if selectedImages.count < 10 {
                        selectedImages.append(capturedImage)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                var loadedImages: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        loadedImages.append(uiImage)
                    }
                }
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        self.selectedImages = Array(loadedImages.prefix(10))
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .rtf, .text, .json, .commaSeparatedText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    
                    let coordinator = NSFileCoordinator()
                    var error: NSError?
                    
                    coordinator.coordinate(readingItemAt: url, options: [], error: &error) { coordinatedURL in
                        let name = coordinatedURL.lastPathComponent
                        let ext = coordinatedURL.pathExtension.lowercased()
                        
                        guard let fileData = try? Data(contentsOf: coordinatedURL) else {
                            print("Failed to read file data synchronously")
                            return
                        }
                        
                        Task {
                            if ext == "pdf" {
                                var needsVisual = false
                                if let textContent = DocumentParser.extractTextFromPDF(data: fileData, onNeedsVisualRendering: { needsVisual = true }) {
                                    let attachment = OllamaDocumentAttachment(name: name, contentText: textContent)
                                    await MainActor.run {
                                        withAnimation {
                                            selectedDocuments.append(attachment)
                                        }
                                    }
                                } else if needsVisual {
                                    let rendered = DocumentParser.renderPDFPagesToImages(data: fileData)
                                    await MainActor.run {
                                        withAnimation {
                                            for img in rendered {
                                                if selectedImages.count < 10 {
                                                    selectedImages.append(img)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else if ext == "docx" {
                                if let textContent = DocumentParser.extractTextFromDocx(data: fileData) {
                                    let attachment = OllamaDocumentAttachment(name: name, contentText: textContent)
                                    await MainActor.run {
                                        withAnimation {
                                            selectedDocuments.append(attachment)
                                        }
                                    }
                                }
                            } else if ext == "xlsx" {
                                if let textContent = DocumentParser.extractTextFromXlsx(data: fileData) {
                                    let attachment = OllamaDocumentAttachment(name: name, contentText: textContent)
                                    await MainActor.run {
                                        withAnimation {
                                            selectedDocuments.append(attachment)
                                        }
                                    }
                                }
                            } else if ext == "rtf" {
                                if let textContent = DocumentParser.extractTextFromRTF(data: fileData) {
                                    let attachment = OllamaDocumentAttachment(name: name, contentText: textContent)
                                    await MainActor.run {
                                        withAnimation {
                                            selectedDocuments.append(attachment)
                                        }
                                    }
                                }
                            } else {
                                if let textContent = String(data: fileData, encoding: .utf8) {
                                    let attachment = OllamaDocumentAttachment(name: name, contentText: textContent)
                                    await MainActor.run {
                                        withAnimation {
                                            selectedDocuments.append(attachment)
                                        }
                                    }
                                } else if let textContent = String(data: fileData, encoding: .ascii) {
                                    let attachment = OllamaDocumentAttachment(name: name, contentText: textContent)
                                    await MainActor.run {
                                        withAnimation {
                                            selectedDocuments.append(attachment)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("Failed to import documents: \(error.localizedDescription)")
            }
        }
    }

}


