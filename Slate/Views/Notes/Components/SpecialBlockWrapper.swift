//
//  SpecialBlockWrapper.swift
//  Slate
//

import SwiftUI

struct SpecialBlockWrapper<Content: View>: View {
    let onDelete: () -> Void
    let content: Content
    
    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }
    
    var body: some View {
        content
            .overlay(alignment: .topLeading) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.15), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
    }
}
