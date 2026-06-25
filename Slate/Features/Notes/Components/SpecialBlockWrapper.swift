//
//  SpecialBlockWrapper.swift
//  Slate
//
//  Created by Antigravity on 6/23/26.
//

import SwiftUI
import UIKit

struct HiddenTextResponder: UIViewRepresentable {
    var isFocused: Bool
    var onBackspace: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.text = " " // Dummy character to capture backspace
        textField.keyboardType = .default
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        
        // Hide the text field visually but keep it focusable
        textField.alpha = 0.01
        textField.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else {
            if uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBackspace: onBackspace)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var onBackspace: () -> Void
        
        init(onBackspace: @escaping () -> Void) {
            self.onBackspace = onBackspace
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string.isEmpty {
                onBackspace()
                return false
            }
            return true
        }
    }
}

struct SpecialBlockWrapper<Content: View>: View {
    let isSelected: Bool
    let onTap: () -> Void
    let onBackspace: () -> Void
    let content: Content
    
    init(
        isSelected: Bool,
        onTap: @escaping () -> Void,
        onBackspace: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.onTap = onTap
        self.onBackspace = onBackspace
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Hidden responder to capture keyboard interactions
            HiddenTextResponder(isFocused: isSelected, onBackspace: onBackspace)
                .frame(width: 1, height: 1)
            
            content
                .contentShape(Rectangle())
                .onTapGesture {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onTap()
                }
                .padding(4)
                .background(isSelected ? Color.blue.opacity(0.12) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
        }
        .padding(.vertical, 4)
    }
}
