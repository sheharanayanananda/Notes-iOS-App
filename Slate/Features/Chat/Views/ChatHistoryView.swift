//
//  ChatHistoryView.swift
//  Slate
//
//  Created by Antigravity on 6/25/26.
//

import SwiftUI

struct ChatHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var chatManager = ChatManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(chatManager.sessions.sorted(by: { $0.lastUpdated > $1.lastUpdated })) { session in
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        chatManager.selectSession(session)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title.isEmpty ? "New Chat" : session.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(formatDate(session.lastUpdated))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if chatManager.activeSessionId == session.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            chatManager.deleteSession(id: session.id)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
