//
//  ChatInputCapsuleView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-21.
//

import SwiftUI

struct ChatCapsule: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    var isGenerating: Bool
    var isTextFieldDisabled: Bool
    var isInputFocused: FocusState<Bool>.Binding
    var onSend: () -> Void
    
    // Internal liquid scale drag animation states
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showAttachmentSheet = false
    
    private var isMultiline: Bool {
        text.contains("\n") || text.count > 33
    }
    
    private var currentCornerRadius: CGFloat {
        isMultiline ? 32 : 35
    }
    
    // Subviews to keep code clean and maintain exact same layout behaviors
    private var plusButton: some View {
        Button(action: {
            showAttachmentSheet = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 20, height: 20)
        }
        .padding(.leading, 7)
    }
    
    private var micButton: some View {
        Button(action: {
            // Microphone Action
        }) {
            Image(systemName: "mic")
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 20, height: 20)
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
                .padding(.leading, isMultiline ? 0 : 38)
                .padding(.trailing, isMultiline ? 0 : 80)
                .onSubmit {
                    onSend()
                }
            
            // Buttons Row (Invariant - exact same buttons slide down)
            HStack(spacing: 12) {
                plusButton
                
                Spacer()
                
                micButton
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
        .sheet(isPresented: $showAttachmentSheet) {
            AttachmentSheetView()
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
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

struct AttachmentOption: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

struct AttachmentSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    let options = [
        AttachmentOption(title: "Photos", icon: "photo.on.rectangle", color: .blue),
        AttachmentOption(title: "Camera", icon: "camera", color: .green),
        AttachmentOption(title: "Documents", icon: "doc.text", color: .orange)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 40) {
                ForEach(options) { option in
                    Button(action: {
                        dismiss()
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: option.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(option.color.gradient)
                                .clipShape(Circle())
                                .shadow(color: option.color.opacity(0.3), radius: 6, x: 0, y: 3)
                            
                            Text(option.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(.top, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
