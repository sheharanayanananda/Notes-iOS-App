//
//  ToolSheet.swift
//  Slate
//

import SwiftUI

struct ToolSheet: View {
    // MARK: - Properties
    let type: ToolType
    @Binding var editingNote: SlateModel?
    @Binding var activeTab: ContentView.TabIdentifier
    @Environment(\.dismiss) private var dismiss

    // MARK: - UI Code
    var body: some View {
        Group {
            switch type {
            case .smartLens:
                EmptyView()
            case .scribe:
                ScribeToolSheet()
            }
        }
    }
}

// MARK: - Coming Soon Sheet
struct ComingSoonToolSheet: View {
    // MARK: - Properties
    let title: String
    let iconName: String
    let iconColor: Color
    let description: String
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - UI Code
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundColor(iconColor)
                    .padding(24)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .bold()
                    
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Text("Coming Soon")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(iconColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Capsule())
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews
#Preview {
    ContentView()
}
