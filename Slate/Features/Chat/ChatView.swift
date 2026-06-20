//
//  ChatView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-20.
//

import SwiftUI

struct ChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var activeTab: ContentView.TabIdentifier
    
    @State private var chatText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "apple.intelligence")
                .font(.system(size: 55))
            
            VStack(spacing: 10) {
                Text("Slate Agent")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("New Conversation")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                
                // Chat input textfield
                TextField("Ask Slate", text: $chatText)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
                
                // Voice input microphone button
                Button(action: {
                    // Microphone Action
                }) {
                    Image(systemName: "mic")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                
                // Send Button
                Button(action: {
                    // Send Action
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(width: 36, height: 36)
                        .background(Color.primary)
                        .clipShape(Circle())
                }
            }
            .padding()
            .padding(.leading, 5)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color(red: 38/255, green: 38/255, blue: 38/255) : Color(red: 245/255, green: 245/255, blue: 245/255))
                    .overlay(
                        Capsule()
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .ignoresSafeArea(.container, edges: .bottom)
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
