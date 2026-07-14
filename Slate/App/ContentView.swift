//
//  ContentView.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-07.
//

import SwiftUI
import SwiftData

struct ContentView: View {

    enum TabIdentifier: Hashable {
        case notes, create, intelligence, settings
    }

    @State private var activeTab: TabIdentifier = .notes
    @State private var editingNote: SlateModel? = nil
    @State private var showSettings = false
    @State private var showChatView = false
    @State private var unreadNotesCount = 0

    @State private var settingsViewModel = SettingsViewModel()

    @Environment(\.modelContext) private var context

    //----------------- Start of UI Code -----------------//
    var body: some View {
        ZStack {
            TabView(selection: $activeTab) {
                Tab("Slate", systemImage: "scribble.variable", value: .notes) {
                    NavigationStack {
                        SlateTabView(
                            onOpenSettings: {
                                HapticManager.trigger(.medium)
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
                .badge(unreadNotesCount > 0 ? Text("\(unreadNotesCount)") : nil)
                
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
            .fullScreenCover(isPresented: $showChatView, onDismiss: {
                if activeTab == .intelligence {
                    activeTab = .notes
                }
            }) {
                NavigationStack {
                    ChatView(activeTab: $activeTab)
                }
            }
        }
        .onChange(of: activeTab) { oldValue, newValue in
            if newValue == .notes {
                unreadNotesCount = 0
            }
            if newValue == .intelligence {
                HapticManager.trigger(.medium)
                showChatView = true
            } else if oldValue == .intelligence {
                HapticManager.trigger(.light)
                showChatView = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PulseNotesTab"))) { _ in
            if activeTab != .notes {
                unreadNotesCount += 1
            }
        }
    }
    
}
