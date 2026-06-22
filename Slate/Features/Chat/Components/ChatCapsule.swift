//
//  ChatInputCapsuleView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-21.
//

import SwiftUI
import PhotosUI

struct ChatCapsule: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    @Binding var selectedImages: [UIImage]
    var isGenerating: Bool
    var isTextFieldDisabled: Bool
    var isInputFocused: FocusState<Bool>.Binding
    var onSend: () -> Void
    
    private var isMultiline: Bool {
        text.contains("\n") || text.count > 38 || !selectedImages.isEmpty
    }
    
    private var currentCornerRadius: CGFloat {
        isMultiline ? 33 : 35
    }
    
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
                // Documents Action
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
                .font(.system(size: 16))
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .frame(width: 36, height: 36)
                .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating ? Color.primary.opacity(0.3) : Color.primary)
                .clipShape(Circle())
        }
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
        .animation(.easeInOut(duration: 0.3), value: isGenerating)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isMultiline ? 12 : 0) {
            // 1. Image Previews Area
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
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
    }

}


