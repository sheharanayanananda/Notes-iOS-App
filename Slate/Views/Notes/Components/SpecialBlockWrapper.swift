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
        ZStack(alignment: .topLeading) {
            content
                .padding(.top, 12)
                .padding(.leading, 12)
            
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
            .padding(.leading, 4)
            .padding(.top, 4)
            .buttonStyle(.plain)
            .zIndex(10)
        }
        .padding(.vertical, 4)
    }
}
