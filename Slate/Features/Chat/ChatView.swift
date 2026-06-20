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
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "apple.intelligence")
                .font(.system(size: 50, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.4, blue: 0.95),
                            Color(red: 0.35, green: 0.5, blue: 0.95),
                            Color(red: 0.2, green: 0.7, blue: 0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 10) {
                Text("Slate Agent")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Conversational Agentic Chat View coming soon\nin V2.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    activeTab = .notes
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

#Preview {
    ChatView(activeTab: .constant(.notes))
}
