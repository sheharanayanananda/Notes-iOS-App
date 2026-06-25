//
//  SettingsView.swift
//  Slate
//
//  Created by Antigravity on 2026-06-14.
//

import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var viewModel: SettingsViewModel
    var onDismiss: (() -> Void)? = nil

    @State private var showKey: Bool = false
    @AppStorage("is_demo_mode") private var isDemoMode = false

    // MARK: - UI Code
    var body: some View {
        Form {
            Section(
                header: Text("Ollama"),
                footer: Text("Your API key is encrypted and stored securely in your device's Keychain. It is used to authorize intelligence features on the cloud server.")
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if showKey {
                            TextField("Ollama API Key", text: $viewModel.apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("Ollama API Key", text: $viewModel.apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if viewModel.validationStatus != .empty {
                        HStack(spacing: 6) {
                            if viewModel.validationStatus == .checking {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: viewModel.validationStatus.iconName)
                                    .foregroundColor(viewModel.validationStatus.color)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text(viewModel.validationStatus.message)
                                .font(.caption)
                                .foregroundColor(viewModel.validationStatus.color)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            Section(
                footer: Text("Enabling demo mode loads pre-configured promotional slates, populates new notes with rich formatting templates, and simulates tools.")
            ) {
                Toggle("Demo Mode", isOn: $isDemoMode)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    dismissView()
                }) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .onDisappear {
            viewModel.savePendingChanges()
        }
        .onChange(of: viewModel.apiKey) {
            viewModel.handleApiKeyChange()
        }
    }
}

// MARK: - Main Functions
extension SettingsView {
    private func dismissView() {
        viewModel.savePendingChanges()
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

// MARK: - Previews
#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel())
    }
}
