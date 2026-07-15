//
//  NativeTextView.swift
//  Slate
//

import SwiftUI
import UIKit

// MARK: - SwiftUI Keyboard Toolbar

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

// MARK: - SlateTextView Subclass

class SlateTextView: UITextView {
    var isLayoutUpdating = false
    
    override func caretRect(for position: UITextPosition) -> CGRect {
        if isLayoutUpdating {
            return CGRect(x: 0, y: 0, width: 2, height: UIFont.preferredFont(forTextStyle: .body).lineHeight)
        }
        return super.caretRect(for: position)
    }
}

// MARK: - Native TextView Wrapper

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
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        
        let defaultParagraphStyle = NSMutableParagraphStyle()
        defaultParagraphStyle.lineSpacing = 3.0
        defaultParagraphStyle.paragraphSpacing = 8
        
        textView.typingAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
            .paragraphStyle: defaultParagraphStyle
        ]
        
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        
        // Build and host the custom SwiftUI toolbar accessory view
        let accessoryView = NativeKeyboardToolbar(
            onToggleChecklist: { context.coordinator.toggleChecklistAction() },
            onToggleBulletList: { context.coordinator.toggleBulletListAction() },
            onToggleNumberedList: { context.coordinator.toggleNumberedListAction() },
            onToggleBold: { context.coordinator.toggleBoldAction() },
            onToggleItalic: { context.coordinator.toggleItalicAction() },
            onToggleUnderline: { context.coordinator.toggleUnderlineAction() },
            onToggleStrikethrough: { context.coordinator.toggleStrikethroughAction() },
            onDecreaseIndent: { context.coordinator.decreaseIndentAction() },
            onIncreaseIndent: { context.coordinator.increaseIndentAction() },
            onDismissKeyboard: { [weak textView] in textView?.resignFirstResponder() }
        )
        
        let hostingController = UIHostingController(rootView: accessoryView)
        hostingController.view.autoresizingMask = .flexibleWidth
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 48)
        hostingController.view.backgroundColor = .clear
        
        textView.inputAccessoryView = hostingController.view
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if context.coordinator.lastParsedText != text && !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            uiView.text = text
            context.coordinator.lastParsedText = text
            context.coordinator.isUpdating = false
        }
        
        if focusedBlockID == id {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
            if let pos = cursorPosition {
                let safePos = min(max(0, pos), uiView.text.count)
                uiView.selectedRange = NSRange(location: safePos, length: 0)
                DispatchQueue.main.async {
                    self.cursorPosition = nil
                }
            }
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .infinity))
        return CGSize(width: width, height: max(size.height, 24))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeTextView
        weak var textView: UITextView?
        var lastParsedText: String = ""
        var isUpdating = false
        
        init(_ parent: NativeTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if isUpdating { return }
            let newText = textView.text ?? ""
            lastParsedText = newText
            parent.text = newText
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingEnded?()
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text.isEmpty && range.length == 0 {
                // Backspace pressed on empty selection
                if range.location == 0 {
                    parent.onBackspaceAtStart?()
                    return false
                } else if range.location == (textView.text ?? "").count {
                    parent.onDeleteAtEnd?()
                    return false
                }
            }
            
            // Auto-list item insertion logic on return key
            if text == "\n" {
                let string = (textView.text ?? "") as NSString
                let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))
                let currentLine = string.substring(with: lineRange)
                
                let trimmedLine = currentLine.trimmingCharacters(in: .whitespaces)
                let indentSpaces = currentLine.prefix(while: { $0 == " " })
                
                // 1. Checklist
                if trimmedLine.hasPrefix("- [ ] ") || trimmedLine.hasPrefix("- [x] ") || trimmedLine.hasPrefix("- [X] ") {
                    let prefix = String(trimmedLine.prefix(6))
                    if trimmedLine.count <= 6 {
                        // Empty checklist line - clear it
                        isUpdating = true
                        let mutableText = NSMutableString(string: textView.text)
                        mutableText.replaceCharacters(in: lineRange, with: "")
                        textView.text = mutableText as String
                        parent.text = textView.text
                        isUpdating = false
                        return false
                    } else {
                        // Insert next checklist item
                        isUpdating = true
                        let insertion = "\n\(indentSpaces)- [ ] "
                        let mutableText = NSMutableString(string: textView.text)
                        mutableText.replaceCharacters(in: range, with: insertion)
                        textView.text = mutableText as String
                        parent.text = textView.text
                        textView.selectedRange = NSRange(location: range.location + insertion.count, length: 0)
                        isUpdating = false
                        return false
                    }
                }
                
                // 2. Bullet list
                if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                    let prefix = String(trimmedLine.prefix(2))
                    if trimmedLine.count <= 2 {
                        // Empty bullet line - clear it
                        isUpdating = true
                        let mutableText = NSMutableString(string: textView.text)
                        mutableText.replaceCharacters(in: lineRange, with: "")
                        textView.text = mutableText as String
                        parent.text = textView.text
                        isUpdating = false
                        return false
                    } else {
                        // Insert next bullet point
                        isUpdating = true
                        let insertion = "\n\(indentSpaces)\(prefix)"
                        let mutableText = NSMutableString(string: textView.text)
                        mutableText.replaceCharacters(in: range, with: insertion)
                        textView.text = mutableText as String
                        parent.text = textView.text
                        textView.selectedRange = NSRange(location: range.location + insertion.count, length: 0)
                        isUpdating = false
                        return false
                    }
                }
                
                // 3. Numbered list
                if let numberRange = trimmedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                    let prefix = String(trimmedLine[numberRange])
                    if trimmedLine.count <= prefix.count {
                        // Empty numbered item - clear it
                        isUpdating = true
                        let mutableText = NSMutableString(string: textView.text)
                        mutableText.replaceCharacters(in: lineRange, with: "")
                        textView.text = mutableText as String
                        parent.text = textView.text
                        isUpdating = false
                        return false
                    } else {
                        // Increment and insert next numbered item
                        let numberStr = prefix.trimmingCharacters(in: .whitespaces).dropLast()
                        var nextNum = 1
                        if let currentNum = Int(numberStr) {
                            nextNum = currentNum + 1
                        }
                        isUpdating = true
                        let insertion = "\n\(indentSpaces)\(nextNum). "
                        let mutableText = NSMutableString(string: textView.text)
                        mutableText.replaceCharacters(in: range, with: insertion)
                        textView.text = mutableText as String
                        parent.text = textView.text
                        textView.selectedRange = NSRange(location: range.location + insertion.count, length: 0)
                        isUpdating = false
                        return false
                    }
                }
            }
            return true
        }
        
        // MARK: - Toolbar Formatting Actions
        
        func toggleBoldAction() {
            wrapSelection(prefix: "**", suffix: "**")
        }
        
        func toggleItalicAction() {
            wrapSelection(prefix: "_", suffix: "_")
        }
        
        func toggleUnderlineAction() {
            wrapSelection(prefix: "<u>", suffix: "</u>")
        }
        
        func toggleStrikethroughAction() {
            wrapSelection(prefix: "~~", suffix: "~~")
        }
        
        func toggleChecklistAction() {
            toggleLinePrefix(prefix: "- [ ] ")
        }
        
        func toggleBulletListAction() {
            toggleLinePrefix(prefix: "- ")
        }
        
        func toggleNumberedListAction() {
            toggleLinePrefix(prefix: "1. ")
        }
        
        func increaseIndentAction() {
            modifyIndent(amount: 2)
        }
        
        func decreaseIndentAction() {
            modifyIndent(amount: -2)
        }
        
        private func wrapSelection(prefix: String, suffix: String) {
            guard let tv = textView else { return }
            let selectedRange = tv.selectedRange
            let nsText = (tv.text ?? "") as NSString
            let selectedText = nsText.substring(with: selectedRange)
            
            let insertion = prefix + selectedText + suffix
            let newText = nsText.replacingCharacters(in: selectedRange, with: insertion)
            
            isUpdating = true
            tv.text = newText
            parent.text = newText
            isUpdating = false
            
            let cursorOffset = prefix.count + selectedText.count + suffix.count
            tv.selectedRange = NSRange(location: selectedRange.location + cursorOffset, length: 0)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        private func toggleLinePrefix(prefix: String) {
            guard let tv = textView else { return }
            let selectedRange = tv.selectedRange
            let nsText = (tv.text ?? "") as NSString
            
            let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineText = nsText.substring(with: lineRange)
            
            var insertion = lineText
            if lineText.hasPrefix(prefix) {
                insertion = String(lineText.dropFirst(prefix.count))
            } else {
                insertion = prefix + lineText
            }
            
            isUpdating = true
            let newText = nsText.replacingCharacters(in: lineRange, with: insertion)
            tv.text = newText
            parent.text = newText
            isUpdating = false
            
            let diff = insertion.count - lineText.count
            tv.selectedRange = NSRange(location: max(0, selectedRange.location + diff), length: 0)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        private func modifyIndent(amount: Int) {
            guard let tv = textView else { return }
            let selectedRange = tv.selectedRange
            let nsText = (tv.text ?? "") as NSString
            
            let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineText = nsText.substring(with: lineRange)
            
            var insertion = lineText
            if amount > 0 {
                insertion = String(repeating: " ", count: amount) + lineText
            } else if amount < 0 {
                let spacesToRemove = abs(amount)
                if lineText.hasPrefix(String(repeating: " ", count: spacesToRemove)) {
                    insertion = String(lineText.dropFirst(spacesToRemove))
                }
            }
            
            isUpdating = true
            let newText = nsText.replacingCharacters(in: lineRange, with: insertion)
            tv.text = newText
            parent.text = newText
            isUpdating = false
            
            let diff = insertion.count - lineText.count
            tv.selectedRange = NSRange(location: max(0, selectedRange.location + diff), length: 0)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}
