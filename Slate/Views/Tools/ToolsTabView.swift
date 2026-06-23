//
//  ToolsTabView.swift
//  Slate
//

import SwiftUI

struct ToolsTabView: View {
    // MARK: - Properties
    @Binding var editingNote: SlateModel?
    @Binding var activeTab: ContentView.TabIdentifier
    let onSmartLens: () -> Void
    
    @State private var selectedToolItem: DisplayTool?
    @AppStorage("is_demo_mode") private var isDemoMode = false
    
    struct DisplayTool: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let iconName: String
        let iconColor: Color
        let isReal: Bool
        let realType: ToolType?
    }
    
    private var displayedTools: [DisplayTool] {
        var list = [
            DisplayTool(
                id: "smartLens",
                title: "Smart Lens",
                subtitle: "Capture and convert real-world text or objects into intelligent notes.",
                iconName: "text.viewfinder",
                iconColor: .blue,
                isReal: true,
                realType: .smartLens
            ),
            DisplayTool(
                id: "scribe",
                title: "Scribe",
                subtitle: "Speak naturally to capture thoughts, build task lists, and organize slates instantly.",
                iconName: "waveform",
                iconColor: .red,
                isReal: true,
                realType: .scribe
            )
        ]
        
        if isDemoMode {
            list.append(contentsOf: [
                DisplayTool(
                    id: "webClipper",
                    title: "Web Clipper",
                    subtitle: "Extract clean note summaries and key findings from any webpage URL.",
                    iconName: "link",
                    iconColor: .orange,
                    isReal: false,
                    realType: nil
                ),
                DisplayTool(
                    id: "conceptCanvas",
                    title: "Concept Canvas",
                    subtitle: "Sketch diagrams or notes and instantly convert them to Markdown drawings.",
                    iconName: "pencil.and.outline",
                    iconColor: .purple,
                    isReal: false,
                    realType: nil
                ),
                DisplayTool(
                    id: "smartDictation",
                    title: "Smart Dictation",
                    subtitle: "Speak naturally and let AI segment and organize your speech in real-time.",
                    iconName: "mic.badge.plus",
                    iconColor: .green,
                    isReal: false,
                    realType: nil
                ),
                DisplayTool(
                    id: "autoOrganizer",
                    title: "Auto-Organizer",
                    subtitle: "Automatically categorize and cluster notes into smart folder hierarchies.",
                    iconName: "folder.badge.gearshape",
                    iconColor: .yellow,
                    isReal: false,
                    realType: nil
                )
            ])
        }
        
        return list
    }
    
    // MARK: - UI Code
    var body: some View {
        ScrollView {
            let columns = [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(displayedTools) { tool in
                    ToolCard(
                        title: tool.title,
                        subtitle: tool.subtitle,
                        iconName: tool.iconName,
                        iconColor: tool.iconColor,
                        action: {
                            if tool.isReal && tool.realType == .smartLens && !isDemoMode {
                                onSmartLens()
                            } else {
                                selectedToolItem = tool
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Tools")
        .sheet(item: $selectedToolItem) { tool in
            if tool.isReal && !isDemoMode, let realType = tool.realType {
                ToolSheet(type: realType, editingNote: $editingNote, activeTab: $activeTab)
            } else {
                ComingSoonToolSheet(
                    title: tool.title,
                    iconName: tool.iconName,
                    iconColor: tool.iconColor,
                    description: tool.subtitle
                )
            }
        }
    }
}

// MARK: - Previews
#Preview {
    ContentView()
}
