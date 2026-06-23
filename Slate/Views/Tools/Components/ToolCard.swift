//
//  ToolCard.swift
//  Slate
//

import SwiftUI

struct ToolCard: View {
    // MARK: - Properties
    var title: String
    var subtitle: String
    var iconName: String
    var iconColor: Color
    var action: () -> Void
    
    // MARK: - UI Code
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    // Minimalist icon with vibrant color
                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(iconColor)
                    
                    Spacer()
                    
                    // Sleek, clean action arrow
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    // Crisp title text
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Explanatory subtitle
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ToolCardButtonStyle())
    }
}

// MARK: - Helpers
struct ToolCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0), value: configuration.isPressed)
    }
}

// MARK: - Previews
#Preview {
    ContentView()
}
