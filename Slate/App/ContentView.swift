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

    @State private var settingsViewModel = SettingsViewModel()

    @Environment(\.modelContext) private var context

    //----------------- Start of UI Code -----------------//
    var body: some View {
        ZStack {
            TabView(selection: $activeTab) {
                Tab("Slate", systemImage: "scribble.variable", value: .notes) {
                    NavigationStack {
                        SlateTabView(
                            showSettings: $showSettings,
                            onOpenSettings: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.prepare()
                                generator.impactOccurred()
                                showSettings = true
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
            .fullScreenCover(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(viewModel: settingsViewModel)
                }
            }


            if showChatView {
                NavigationStack {
                    ChatView(activeTab: $activeTab, editingNote: $editingNote)
                }
                .transition(.move(edge: .trailing))
                .zIndex(2)
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
