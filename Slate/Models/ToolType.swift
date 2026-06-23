//
//  ToolType.swift
//  Slate
//

import SwiftUI

enum ToolType: String, Identifiable, CaseIterable {
    case smartLens
    case scribe
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .smartLens:
            return "Smart Lens"
        case .scribe:
            return "Scribe"
        }
    }
    
    var subtitle: String {
        switch self {
        case .smartLens:
            return "Capture and convert real-world text or objects into intelligent notes."
        case .scribe:
            return "Speak naturally to capture thoughts, build task lists, and organize slates instantly."
        }
    }
    
    var iconName: String {
        switch self {
        case .smartLens:
            return "text.viewfinder"
        case .scribe:
            return "waveform"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .smartLens:
            return .blue
        case .scribe:
            return .red
        }
    }
}
