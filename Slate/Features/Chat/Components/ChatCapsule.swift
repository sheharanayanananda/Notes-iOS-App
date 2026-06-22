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
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    private var isMultiline: Bool {
        text.contains("\n") || text.count > 33 || !selectedImages.isEmpty
    }
    
    private var currentCornerRadius: CGFloat {
        isMultiline ? 32 : 35
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
            
            // Chat input textfield (Invariant hierarchy to preserve focus)
            TextField("Ask Slate", text: $text, axis: .vertical)
                .font(.system(size: 16))
                .lineSpacing(5)
                .textFieldStyle(.plain)
                .focused(isInputFocused)
                .disabled(isTextFieldDisabled)
                .opacity(isGenerating ? 0.6 : 1.0)
                .lineLimit(1...6)
                .frame(minHeight: 36)
                .padding(.leading, isMultiline ? 0 : 42)
                .padding(.trailing, isMultiline ? 0 : 92)
                .onSubmit {
                    onSend()
                }
            
            // Buttons Row (Invariant - exact same buttons slide down)
            HStack(spacing: 12) {
                plusButton
                
                Spacer()
                
//                micButton
                sendButton
            }
            .padding(.top, isMultiline ? 0 : -36)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07), lineWidth: 1)
                )
                .onTapGesture {
                    isInputFocused.wrappedValue = true
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isMultiline)
        .scaleEffect(x: liquidScaleX, y: liquidScaleY)
        .offset(x: dragOffset.width * 0.25, y: dragOffset.height * 0.25)
        .simultaneousGesture(dragGesture)
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
    
    private var liquidScaleX: CGFloat {
        let stretch = abs(dragOffset.width) * 0.0015 - abs(dragOffset.height) * 0.001
        return min(max(1.0 + stretch, 0.8), 1.2)
    }
    
    private var liquidScaleY: CGFloat {
        let stretch = abs(dragOffset.height) * 0.0015 - abs(dragOffset.width) * 0.001
        return min(max(1.0 + stretch, 0.8), 1.2)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                
                let oldWidth = dragOffset.width
                let newWidth = value.translation.width
                if Int(abs(newWidth) / 20) != Int(abs(oldWidth) / 20) {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.5)
                }
                
                let horizontalTranslation = value.translation.width
                let verticalTranslation = value.translation.height
                dragOffset = CGSize(width: horizontalTranslation, height: verticalTranslation)
            }
            .onEnded { _ in
                if isDragging {
                    isDragging = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                        dragOffset = .zero
                    }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
    }
}


