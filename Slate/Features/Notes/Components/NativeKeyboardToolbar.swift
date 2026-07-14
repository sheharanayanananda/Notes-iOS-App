//
//  NativeKeyboardToolbar.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI

struct NativeKeyboardToolbar: View {
    var onToggleChecklist: () -> Void
    var onToggleBulletList: () -> Void
    var onToggleNumberedList: () -> Void
    
    var onToggleBold: () -> Void
    var onToggleItalic: () -> Void
    var onToggleUnderline: () -> Void
    var onToggleStrikethrough: () -> Void
    
    var onDecreaseIndent: () -> Void
    var onIncreaseIndent: () -> Void
    
    var onDismissKeyboard: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Grouped text formatting tools
            HStack(spacing: 0) {
                Button(action: onToggleBold) {
                    Image(systemName: "bold")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                
                Button(action: onToggleItalic) {
                    Image(systemName: "italic")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                
                Button(action: onToggleUnderline) {
                    Image(systemName: "underline")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                
                Button(action: onToggleStrikethrough) {
                    Image(systemName: "strikethrough")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
            }
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            
            // Grouped list formatting tools inside a single container
            HStack(spacing: 0) {
                Button(action: onToggleChecklist) {
                    Image(systemName: "checklist")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                
                Button(action: onToggleBulletList) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                
                Button(action: onToggleNumberedList) {
                    Image(systemName: "list.number")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
            }
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            
            // Grouped indentation tools
            HStack(spacing: 0) {
                Button(action: onDecreaseIndent) {
                    Image(systemName: "decrease.indent")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                
                Button(action: onIncreaseIndent) {
                    Image(systemName: "increase.indent")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
            }
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            
            Spacer()
            
            Button(action: onDismissKeyboard) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
            }
            .background(Color(.systemGray6))
            .clipShape(Circle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.clear)
    }
}
