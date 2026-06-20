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
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    @State private var selectedModel: ModelMetadata = ModelMetadata.availableModels[0]
    @State private var thinkingLevel: String = "Low"
    @State private var creativity: Double = 0.2
    @State private var memorySize: MemoryLimit = .standard
    @State private var showModelConfigSheet = false
    
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
            .scaleEffect(x: liquidScaleX, y: liquidScaleY)
            .offset(x: dragOffset.width * 0.22, y: dragOffset.height * 0.12)
            .simultaneousGesture(dragGesture)
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
            
            ToolbarItem(placement: .principal) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    showModelConfigSheet = true
                }) {
                    HStack(spacing: 4) {
                        Text(selectedModel.id)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if selectedModel.supportsThinking {
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            Text(thinkingLevel)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    chatText = ""
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showModelConfigSheet) {
            NavigationStack {
                Form {
                    Section(footer: Text(selectedModel.description)) {
                        Picker("Model", selection: $selectedModel) {
                            ForEach(ModelMetadata.availableModels) { model in
                                Text(model.id).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedModel) {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            selectModel(selectedModel)
                        }
                    }
                    
                    if selectedModel.supportsThinking {
                        Section(
                            header: Text("Reasoning"),
                            footer: Text("Controls how deeply the agent reasons before organizing notes or connecting to other apps.")
                        ) {
                            Picker("Reasoning", selection: $thinkingLevel) {
                                Text("Off").tag("Off")
                                Text("Low").tag("Low")
                                Text("Medium").tag("Medium")
                                Text("High").tag("High")
                            }
                            .pickerStyle(.menu)
                            .onChange(of: thinkingLevel) {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                    }
                    
                    Section(
                        footer: Text(creativityDescription)
                    ) {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Creativity")
                                Spacer()
                                Text(String(format: "%.1f", creativity))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(.secondary)
                                ZStack {
                                    SliderTicksView(numberOfSteps: 10)
                                        .offset(y: 8)
                                    Slider(
                                        value: creativitySliderBinding,
                                        in: 0.0...1.0,
                                        step: 0.1
                                    )
                                }
                                Image(systemName: "sparkles")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Section(
                        footer: Text(memorySizeDescription)
                    ) {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Memory Size")
                                Spacer()
                                Text(memorySize.displayName)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "memorychip")
                                    .foregroundColor(.secondary)
                                
                                let cases = MemoryLimit.allCases.filter { $0 <= selectedModel.maxMemorySize }
                                ZStack {
                                    SliderTicksView(numberOfSteps: cases.count - 1)
                                        .offset(y: 8)
                                    Slider(
                                        value: memorySizeSliderBinding,
                                        in: 0.0...Double(cases.count - 1),
                                        step: 1.0
                                    )
                                }
                                
                                Image(systemName: "cpu")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .tint(.primary)
            .presentationDetents([.medium, .large])
        }
    }
    
    private var creativitySliderBinding: Binding<Double> {
        Binding(
            get: { creativity },
            set: { newValue in
                let rounded = round(newValue * 10) / 10.0
                if rounded != creativity {
                    creativity = rounded
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        )
    }
    
    private var memorySizeSliderBinding: Binding<Double> {
        Binding(
            get: {
                let cases = MemoryLimit.allCases.filter { $0 <= selectedModel.maxMemorySize }
                if let index = cases.firstIndex(of: memorySize) {
                    return Double(index)
                }
                return 0.0
            },
            set: { newValue in
                let cases = MemoryLimit.allCases.filter { $0 <= selectedModel.maxMemorySize }
                let index = Int(round(newValue))
                if index >= 0 && index < cases.count {
                    let newLimit = cases[index]
                    if newLimit != memorySize {
                        memorySize = newLimit
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
            }
        )
    }
    
    private var liquidScaleX: CGFloat {
        let stretch = abs(dragOffset.width) * 0.0012 - abs(dragOffset.height) * 0.0008
        return min(max(1.0 + stretch, 0.82), 1.15)
    }
    
    private var liquidScaleY: CGFloat {
        let stretch = abs(dragOffset.height) * 0.0012 - abs(dragOffset.width) * 0.0008
        return min(max(1.0 + stretch, 0.82), 1.15)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                
                let oldWidth = dragOffset.width
                let newWidth = value.translation.width
                if Int(abs(newWidth) / 20) != Int(abs(oldWidth) / 20) {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.5)
                }
                
                dragOffset = value.translation
            }
            .onEnded { _ in
                if isDragging {
                    isDragging = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                        dragOffset = .zero
                    }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
    }
    
    private func selectModel(_ model: ModelMetadata) {
        selectedModel = model
        creativity = model.defaultCreativity
        if memorySize > model.maxMemorySize {
            memorySize = model.maxMemorySize
        }
        if !model.supportsThinking {
            thinkingLevel = "Off"
        }
    }
    
    private var creativityDescription: String {
        if creativity <= 0.3 {
            return "Precise: Best for factual notes, summaries, logic, and automated action steps."
        } else if creativity <= 0.6 {
            return "Balanced: A blend of factual accuracy and natural writing style."
        } else {
            return "Creative: Best for brainstorming ideas, creative writing, and expanding on note drafts."
        }
    }
    
    private var memorySizeDescription: String {
        switch memorySize {
        case .short:
            return "Short (4K): Best for quick replies and editing single short notes."
        case .standard:
            return "Standard (8K): Good for average conversations and referencing standard notes."
        case .detailed:
            return "Detailed (16K): Best for working with multiple notes and linking content together."
        case .maximum:
            return "Maximum (32K): Best for referencing very long note histories and entire project files."
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(activeTab: .constant(.notes))
    }
}

struct ModelMetadata: Identifiable, Hashable {
    let id: String
    let systemName: String
    let description: String
    
    let supportsThinking: Bool
    let maxMemorySize: MemoryLimit
    let defaultCreativity: Double
}

enum MemoryLimit: Int, Comparable, CaseIterable, Identifiable {
    case short = 4096      // 4K
    case standard = 8192   // 8K
    case detailed = 16384  // 16K
    case maximum = 32768   // 32K
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .short: return "Short (4K)"
        case .standard: return "Standard (8K)"
        case .detailed: return "Detailed (16K)"
        case .maximum: return "Maximum (32K)"
        }
    }
    
    var subLabel: String {
        switch self {
        case .short: return "For quick, simple chats"
        case .standard: return "Good for most tasks"
        case .detailed: return "Better for referencing multiple notes"
        case .maximum: return "Remembers extremely long chats"
        }
    }
    
    static func < (lhs: MemoryLimit, rhs: MemoryLimit) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension ModelMetadata {
    static let availableModels: [ModelMetadata] = [
        ModelMetadata(id: "Gemma 4", systemName: "gemma4:31b", description: "Best for complex note organization, writing code, and automated connections to other apps.", supportsThinking: true, maxMemorySize: .maximum, defaultCreativity: 0.2),
        ModelMetadata(id: "Qwen 3.5", systemName: "qwen3.5", description: "Great all-around helper for summarizing content, analyzing files, and logical reasoning.", supportsThinking: true, maxMemorySize: .maximum, defaultCreativity: 0.3),
        ModelMetadata(id: "Mistral 3", systemName: "mistral3", description: "Best for creative writing, formatting documents, and drafting outlines or email replies.", supportsThinking: false, maxMemorySize: .detailed, defaultCreativity: 0.7),
        ModelMetadata(id: "Gemini 3 Flash Preview", systemName: "gemini3-flash", description: "Best for quick replies, fast note searches, and instant text extraction from scans.", supportsThinking: false, maxMemorySize: .maximum, defaultCreativity: 0.4),
        ModelMetadata(id: "Gemma 3", systemName: "gemma3", description: "A lightweight option for quick note editing, spelling fixes, and simple text updates.", supportsThinking: false, maxMemorySize: .standard, defaultCreativity: 0.3)
    ]
}

struct SliderTicksView: View {
    let numberOfSteps: Int
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            if numberOfSteps > 1 {
                ForEach(1..<numberOfSteps, id: \.self) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 3.5, height: 3.5)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 14)
        .allowsHitTesting(false)
    }
}
