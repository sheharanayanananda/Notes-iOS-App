//
//  NativeTextView.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI
import UIKit

extension NSTextContainer {
    var textStorage: NSTextStorage? {
        if let lm = self.layoutManager {
            return lm.textStorage
        }
        if let tlm = self.textLayoutManager,
           let tcs = tlm.textContentManager as? NSTextContentStorage {
            return tcs.textStorage
        }
        return nil
    }
}

struct NativeTextView: UIViewRepresentable {
    let id: UUID
    @Binding var text: String
    @Binding var focusedBlockID: UUID?
    @Binding var cursorPosition: Int?
    var onEditingEnded: (() -> Void)? = nil
    var onBackspaceAtStart: (() -> Void)? = nil
    var onDeleteAtEnd: (() -> Void)? = nil
    
    func makeUIView(context: Context) -> UITextView {
        let textView = SlateTextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        
        let bodyFont = UIFont.defaultSlateFont
        textView.font = bodyFont
        textView.textColor = UIColor.label
        
        let defaultParagraphStyle = NSMutableParagraphStyle()
        defaultParagraphStyle.lineSpacing = 3.0
        defaultParagraphStyle.paragraphSpacing = 8
        
        textView.typingAttributes = [
            .font: bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: defaultParagraphStyle
        ]
        
        // Allow SwiftUI to compress this view horizontally — required so sizeThatFits
        // can propose the correct width and UITextView wraps at the right boundary.
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // Align with special block padding (horizontal 24 is managed by the parent ScrollView)
        // Set vertical to 0 so spacing matches SwiftUI's standard Stack layouts.
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        
        let accessoryView = NativeKeyboardToolbar(
            onToggleChecklist: {
                context.coordinator.toggleChecklistAction()
            },
            onToggleBulletList: {
                context.coordinator.toggleBulletListAction()
            },
            onToggleNumberedList: {
                context.coordinator.toggleNumberedListAction()
            },
            onToggleBold: {
                context.coordinator.toggleBoldAction()
            },
            onToggleItalic: {
                context.coordinator.toggleItalicAction()
            },
            onToggleUnderline: {
                context.coordinator.toggleUnderlineAction()
            },
            onToggleStrikethrough: {
                context.coordinator.toggleStrikethroughAction()
            },
            onDecreaseIndent: {
                context.coordinator.decreaseIndentAction()
            },
            onIncreaseIndent: {
                context.coordinator.increaseIndentAction()
            },
            onDismissKeyboard: { [weak textView] in
                textView?.resignFirstResponder()
            }
        )
        
        let hostingController = UIHostingController(rootView: accessoryView)
        hostingController.view.autoresizingMask = .flexibleWidth
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 48)
        hostingController.view.backgroundColor = .clear
        
        textView.inputAccessoryView = hostingController.view
        
        // Tap gesture ONLY for toggling checklists directly when tapped on visual checkbox
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        textView.addGestureRecognizer(tapGesture)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let slateTextView = uiView as? SlateTextView
        
        if focusedBlockID == id {
            if !uiView.isFirstResponder {
                // Focus the text view
                uiView.becomeFirstResponder()
            }
            if let pos = cursorPosition {
                let textLength = uiView.text.count
                let safePos = min(max(0, pos), textLength)
                uiView.selectedRange = NSRange(location: safePos, length: 0)
                // Clear the position asynchronously to prevent triggering updates during layout pass
                DispatchQueue.main.async {
                    self.cursorPosition = nil
                }
            }
        }
        
        if context.coordinator.lastParsedText != text && !context.coordinator.isUpdating {
            let font = UIFont.defaultSlateFont
            let attr = AttributedMarkdownRenderer.parseToAttributed(text: text, font: font)
            
            let selectedRange = uiView.selectedRange
            slateTextView?.isLayoutUpdating = true
            context.coordinator.isUpdating = true
            
            // IMPORTANT: set font BEFORE attributedText.
            // Setting UITextView.font AFTER attributedText resets the entire text storage
            // to a single font, destroying any per-character styling (e.g. header sizes).
            uiView.font = font
            uiView.attributedText = attr
            context.coordinator.isUpdating = false
            
            let defaultParagraphStyle = NSMutableParagraphStyle()
            defaultParagraphStyle.lineSpacing = 3.0
            defaultParagraphStyle.paragraphSpacing = 8
            
            uiView.typingAttributes = [
                .font: font,
                .foregroundColor: UIColor.label,
                .paragraphStyle: defaultParagraphStyle
            ]
            
            let length = uiView.attributedText.length
            if selectedRange.location <= length {
                let maxLen = min(selectedRange.length, length - selectedRange.location)
                uiView.selectedRange = NSRange(location: selectedRange.location, length: maxLen)
            } else {
                uiView.selectedRange = NSRange(location: length, length: 0)
            }
            
            context.coordinator.lastParsedText = text
            slateTextView?.isLayoutUpdating = false
        }
    }
    
    /// Tells SwiftUI the exact size this text view needs given the proposed (available) width.
    /// This is the canonical fix for UITextView intrinsic-size overflow in UIViewRepresentable:
    /// UITextView measures itself with unlimited width by default, returning the longest line
    /// length as its intrinsic width. sizeThatFits intercepts that and clamps to the proposed
    /// width, asking UITextView how tall it needs at that width, ensuring proper text wrapping.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        var defaultWidth: CGFloat = 375
        if let windowScene = uiView.window?.windowScene {
            defaultWidth = windowScene.screen.bounds.width
        } else if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            defaultWidth = windowScene.screen.bounds.width
        }
        let width = proposal.width ?? defaultWidth
        guard width > 0, width < .infinity else { return nil }
        let fitting = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: max(fitting.height, 24))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
