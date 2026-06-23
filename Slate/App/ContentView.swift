//
//  ContentView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-07.
//

import SwiftUI
import SwiftData
import Vision
import ImageIO

struct ContentView: View {

    enum TabIdentifier: Hashable {
        case notes, create, intelligence, settings
    }

    @State private var activeTab: TabIdentifier = .notes
    @State private var editingNote: SlateModel? = nil
    @State private var showSettings = false
    @State private var showChatView = false

    @State private var isSettingsVisible = false
    @State private var isSettingsInteractable = false
    @State private var settingsViewModel = SettingsViewModel()
    @State private var settingsTransitionTask: Task<Void, Never>? = nil

    @Environment(\.modelContext) private var context

    private func settingsXOffset(screenWidth: CGFloat) -> CGFloat {
        if showSettings {
            return 0
        } else {
            return -screenWidth
        }
    }

    //----------------- Start of UI Code -----------------//
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            ZStack {
                TabView(selection: $activeTab) {
                    Tab("Slate", systemImage: "scribble.variable", value: .notes) {
                        NavigationStack {
                            SlateTabView(
                                showSettings: $showSettings,
                                onOpenSettings: {
                                    isSettingsVisible = true
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showSettings = true
                                    }
                                },
                                onCreate: {
                                    editingNote = nil
                                    activeTab = .create
                                },
                                onSelect: { note in
                                    editingNote = note
                                    activeTab = .create
                                }
                            )
                        }
                    }
                    
                    Tab((editingNote == nil || editingNote?.modelContext == nil) ? "New" : "Edit", systemImage: "plus", value: .create) {
                        NavigationStack {
                            CreateTabView(
                                editingNote: $editingNote,
                                activeTab: $activeTab
                            )
                        }
                    }
                    
                    Tab("Chat", systemImage: "apple.intelligence", value: .intelligence, role: .search) {
                        Color.clear
                    }
                }


                if showChatView {
                    NavigationStack {
                        ChatView(activeTab: $activeTab, editingNote: $editingNote)
                    }
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
                }


                if isSettingsVisible {
                    NavigationStack {
                        SettingsView(
                            viewModel: settingsViewModel,
                            onDismiss: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showSettings = false
                                }
                            }
                        )
                        .disabled(!isSettingsInteractable)
                    }
                    .offset(x: settingsXOffset(screenWidth: screenWidth))
                    .zIndex(1)
                }
            }
            .onChange(of: showSettings) { oldValue, newValue in
                settingsTransitionTask?.cancel()
                isSettingsInteractable = false
                
                settingsTransitionTask = Task { @MainActor in
                    if newValue {
                        isSettingsVisible = true
                        
                        // Wait for 0.2s for haptic
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        guard !Task.isCancelled else { return }
                        
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred()
                        
                        // Wait another 0.15s to enable interactions (total 0.35s)
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        
                        isSettingsInteractable = true
                    } else {
                        // Wait 0.35s for slide-out animation to finish
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard !Task.isCancelled else { return }
                        
                        isSettingsVisible = false
                    }
                }
            }

            .onChange(of: activeTab) { oldValue, newValue in
                if newValue == .intelligence {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
                        showChatView = true
                    }
                } else if oldValue == .intelligence {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) {
                        showChatView = false
                    }
                }
            }
        }
    }
    
}
