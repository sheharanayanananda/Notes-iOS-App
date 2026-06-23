//
//  ScribeToolSheet.swift
//  Slate
//

import SwiftUI
import SwiftData

struct ScribeToolSheet: View {
    // MARK: - Properties
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    enum ScribeState {
        case idle
        case recording
        case processing
        case completed
    }
    
    @State private var currentState: ScribeState = .idle
    @State private var recordingSeconds = 0
    @State private var timer: Timer?
    @State private var dictationText = ""
    @State private var waveformHeights: [CGFloat] = Array(repeating: 10, count: 15)
    @State private var waveformTimer: Timer?
    
    // Hardcoded simulation timeline
    private let dictationSteps = [
        "Hey Slate...",
        "Hey Slate, create a checklist for my launch plan tomorrow...",
        "Hey Slate, create a checklist for my launch plan tomorrow and review the design notes.",
    ]
    
    private let mockTitle = "Launch Plan Checklist"
    private let mockDesc = "Launch Plan\n\n**Action Items**\n- [ ] Complete launch plan tasks\n- [ ] Review design notes"
    
    // MARK: - UI Code
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                switch currentState {
                case .idle:
                    idleView
                case .recording:
                    recordingView
                case .processing:
                    processingView
                case .completed:
                    completedView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Scribe")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        stopAllSimulations()
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .onDisappear {
                stopAllSimulations()
            }
        }
    }
    
    private var idleView: some View {
        VStack(spacing: 24) {
            Button(action: startRecordingSimulation) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }
            }
            
            VStack(spacing: 8) {
                Text("Scribe Voice Agent")
                    .font(.title2)
                    .bold()
                
                Text("Tap the microphone to dictate your thoughts. Scribe will transcribe your speech and use Gemma AI to structure it into formatted notes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var recordingView: some View {
        VStack(spacing: 32) {
            HStack(spacing: 4) {
                ForEach(0..<15) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(width: 6, height: waveformHeights[index])
                        .animation(.easeInOut(duration: 0.1), value: waveformHeights[index])
                }
            }
            .frame(height: 80)
            
            VStack(spacing: 12) {
                Text(timeString(from: recordingSeconds))
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                
                Text(dictationText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .frame(height: 60)
            }
            
            Button(action: stopRecordingSimulation) {
                Image(systemName: "stop.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
                .tint(.red)
            
            VStack(spacing: 8) {
                Text("Analyzing Speech")
                    .font(.headline)
                Text("Gemma is structuring your note details...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Note Structured")
                    .font(.title2)
                    .bold()
                Text("A new note has been successfully compiled from your dictation.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text(mockTitle)
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text(mockDesc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            
            Button(action: saveMockNote) {
                Text("Add to Slates")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Main Functions
extension ScribeToolSheet {
    private func startRecordingSimulation() {
        currentState = .recording
        recordingSeconds = 0
        dictationText = dictationSteps[0]
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingSeconds += 1
            if recordingSeconds < dictationSteps.count {
                dictationText = dictationSteps[recordingSeconds]
            } else if recordingSeconds >= 6 {
                stopRecordingSimulation()
            }
        }
        
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            for i in 0..<15 {
                waveformHeights[i] = CGFloat.random(in: 10...70)
            }
        }
    }
    
    private func stopRecordingSimulation() {
        timer?.invalidate()
        timer = nil
        waveformTimer?.invalidate()
        waveformTimer = nil
        
        guard currentState == .recording else { return }
        
        currentState = .processing
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                currentState = .completed
            }
        }
    }
    
    private func saveMockNote() {
        let note = SlateModel(title: mockTitle, desc: mockDesc)
        context.insert(note)
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        dismiss()
    }
}

// MARK: - Supporting Functions
extension ScribeToolSheet {
    private func stopAllSimulations() {
        timer?.invalidate()
        timer = nil
        waveformTimer?.invalidate()
        waveformTimer = nil
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Previews
#Preview {
    ScribeToolSheet()
}
