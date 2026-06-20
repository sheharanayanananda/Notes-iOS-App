//
//  ChatView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-20.
//

import SwiftUI

struct ChatView: View {
    @Binding var activeTab: ContentView.TabIdentifier
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.35, blue: 0.95),
                            Color(red: 0.35, green: 0.45, blue: 0.95),
                            Color(red: 0.25, green: 0.65, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Slate AI Agent")
                .font(.title2)
                .bold()
            
            Text("Conversational Agentic Chat View coming soon in V2.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    activeTab = .notes
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(activeTab: .constant(.intelligence))
    }
}
