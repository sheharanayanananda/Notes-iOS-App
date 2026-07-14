//
//  NativeTextView+Coordinator.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI
import UIKit

extension NativeTextView {
    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: NativeTextView
        weak var textView: UITextView?
        var lastParsedText: String = ""
        var isUpdating = false
        
        init(_ parent: NativeTextView) {
            self.parent = parent
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let textView = textView else { return false }
            
            let location = touch.location(in: textView)
            let adjustedLocation = CGPoint(x: location.x - textView.textContainerInset.left,
                                           y: location.y - textView.textContainerInset.top)
            
            let layoutManager = textView.layoutManager
            let characterIndex = layoutManager.characterIndex(for: adjustedLocation, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            
            guard characterIndex < textView.textStorage.length else { return false }
            
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
            
            let expandedRect = boundingRect.insetBy(dx: -18, dy: -18)
            
            if expandedRect.contains(adjustedLocation) {
                let attribute = textView.textStorage.attribute(NSAttributedString.Key.attachment, at: characterIndex, effectiveRange: nil)
                if attribute is CheckboxAttachment {
                    return true
                }
            }
            
            return false
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = textView else { return }
            
            let location = gesture.location(in: textView)
            let adjustedLocation = CGPoint(x: location.x - textView.textContainerInset.left,
                                           y: location.y - textView.textContainerInset.top)
            
            let layoutManager = textView.layoutManager
            let characterIndex = layoutManager.characterIndex(for: adjustedLocation, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            
            guard characterIndex < textView.textStorage.length else { return }
            
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
            
            let expandedRect = boundingRect.insetBy(dx: -18, dy: -18)
            
            if expandedRect.contains(adjustedLocation) {
                if let attachment = textView.textStorage.attribute(NSAttributedString.Key.attachment, at: characterIndex, effectiveRange: nil) as? CheckboxAttachment {
                    toggleCheckbox(at: characterIndex, in: textView, currentAttachment: attachment)
                }
            }
        }
        
        private func toggleCheckbox(at index: Int, in textView: UITextView, currentAttachment: CheckboxAttachment) {
            let isChecked = !currentAttachment.isChecked
            let newAttachment = CheckboxAttachment(isChecked: isChecked)
            
            let attrString = NSMutableAttributedString(attributedString: textView.attributedText)
            guard index < attrString.length else { return }
            attrString.removeAttribute(.attachment, range: NSRange(location: index, length: 1))
            attrString.addAttribute(.attachment, value: newAttachment, range: NSRange(location: index, length: 1))
            
            let nsString = attrString.string as NSString
            let lineRange = nsString.lineRange(for: NSRange(location: index, length: 1))
            
            if lineRange.length > 3 {
                let startPos = index + 3
                var endPos = lineRange.location + lineRange.length
                
                // Trim trailing newline to avoid applying strikethrough to the newline char
                if endPos > 0 && endPos <= attrString.length {
                    let lastChar = nsString.character(at: endPos - 1)
                    if lastChar == unichar(10) { // '\n' ASCII is 10
                        endPos -= 1
                    }
                }
                
                if startPos < endPos && endPos <= attrString.length {
                    let textRange = NSRange(location: startPos, length: endPos - startPos)
                    if isChecked {
                        attrString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
                        attrString.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: textRange)
                    } else {
                        attrString.removeAttribute(.strikethroughStyle, range: textRange)
                        attrString.addAttribute(.foregroundColor, value: UIColor.label, range: textRange)
                    }
                }
            }
            
            isUpdating = true
            let selectedRange = textView.selectedRange
            textView.attributedText = attrString
            
            let newText = AttributedMarkdownRenderer.serializeToString(attributed: attrString)
            self.lastParsedText = newText
            parent.text = newText
            
            // Safely restore selection range within new length
            let maxLen = textView.attributedText.length
            if selectedRange.location <= maxLen {
                let safeLen = min(selectedRange.length, maxLen - selectedRange.location)
                textView.selectedRange = NSRange(location: selectedRange.location, length: safeLen)
            } else {
                textView.selectedRange = NSRange(location: maxLen, length: 0)
            }
            
            isUpdating = false
            
            HapticManager.trigger(.light)
        }
        
        func toggleChecklistAction() {
            guard let textView = textView else { return }
            
            let string = textView.textStorage.string as NSString
            let selectedRange = textView.selectedRange
            let safeLocation = min(selectedRange.location, string.length)
            let safeLength = min(selectedRange.length, string.length - safeLocation)
            let safeRange = NSRange(location: safeLocation, length: safeLength)
            
            let lineRange = string.length > 0
                ? string.lineRange(for: NSRange(location: safeRange.location, length: 0))
                : NSRange(location: 0, length: 0)
            
            if safeRange.location <= string.length {
                var range = NSRange(location: 0, length: 0)
                let firstCharAttr = lineRange.length > 0 && lineRange.location < textView.textStorage.length
                    ? textView.textStorage.attribute(NSAttributedString.Key.attachment, at: lineRange.location, effectiveRange: &range)
                    : nil
                
                if firstCharAttr is CheckboxAttachment {
                    isUpdating = true
                    let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                    
                    let removeRange = NSRange(location: lineRange.location, length: min(2, lineRange.length))
                    mutableAttr.replaceCharacters(in: removeRange, with: "")
                    
                    let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                    let normalParagraphStyle = NSMutableParagraphStyle()
                    normalParagraphStyle.paragraphSpacing = 8
                    
                    let normalAttrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: normalParagraphStyle
                    ]
                    
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                    
                    mutableAttr.addAttributes(normalAttrs, range: newLineRange)
                    mutableAttr.removeAttribute(.strikethroughStyle, range: newLineRange)
                    
                    textView.attributedText = mutableAttr
                    
                    let newLocation = max(lineRange.location, safeRange.location - removeRange.length)
                    textView.selectedRange = NSRange(location: newLocation, length: safeRange.length)
                    
                    let newText = AttributedMarkdownRenderer.serializeToString(attributed: mutableAttr)
                    self.lastParsedText = newText
                    parent.text = newText
                    isUpdating = false
                    
                } else {
                    isUpdating = true
                    let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                    
                    let attachment = CheckboxAttachment(isChecked: false)
                    let newBoxStr = NSMutableAttributedString(attachment: attachment)
                    
                    let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.headIndent = 32
                    paragraphStyle.firstLineHeadIndent = 0
                    paragraphStyle.paragraphSpacing = 8
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraphStyle]
                    
                    newBoxStr.append(NSAttributedString(string: " ", attributes: attrs))
                    newBoxStr.addAttributes(attrs, range: NSRange(location: 0, length: newBoxStr.length))
                    
                    mutableAttr.insert(newBoxStr, at: lineRange.location)
                    
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 1))
                    if newLineRange.location + newLineRange.length <= mutableAttr.length {
                        mutableAttr.addAttributes(attrs, range: newLineRange)
                    }
                    
                    textView.attributedText = mutableAttr
                    
                    let newText = AttributedMarkdownRenderer.serializeToString(attributed: mutableAttr)
                    self.lastParsedText = newText
                    parent.text = newText
                    isUpdating = false
                    
                    textView.selectedRange = NSRange(location: selectedRange.location + newBoxStr.length, length: selectedRange.length)
                }
            }
            
            HapticManager.trigger(.light)
        }
        
        func toggleBulletListAction() {
            guard let textView = textView else { return }
            
            let string = textView.textStorage.string as NSString
            let selectedRange = textView.selectedRange
            let safeLocation = min(selectedRange.location, string.length)
            let safeLength = min(selectedRange.length, string.length - safeLocation)
            let safeRange = NSRange(location: safeLocation, length: safeLength)
            
            let lineRange = string.length > 0
                ? string.lineRange(for: NSRange(location: safeRange.location, length: 0))
                : NSRange(location: 0, length: 0)
            
            if safeRange.location <= string.length {
                let currentLine = lineRange.length > 0 ? string.substring(with: lineRange) : ""
                
                isUpdating = true
                let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                
                let font = textView.font ?? UIFont.defaultSlateFont
                let bulletParagraphStyle = NSMutableParagraphStyle()
                bulletParagraphStyle.headIndent = 18
                bulletParagraphStyle.firstLineHeadIndent = 0
                bulletParagraphStyle.paragraphSpacing = 8
                bulletParagraphStyle.lineSpacing = 3.0
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: bulletParagraphStyle]
                
                if currentLine.hasPrefix("•  ") {
                    let nsLine = currentLine as NSString
                    let cleanLine = nsLine.substring(from: 3)
                    mutableAttr.replaceCharacters(in: lineRange, with: cleanLine)
                    
                    let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                    mutableAttr.addAttributes(normalAttrs, range: newLineRange)
                    
                    textView.attributedText = mutableAttr
                    textView.selectedRange = NSRange(location: max(0, safeRange.location - 3), length: safeRange.length)
                } else {
                    var adjustSelection = 3
                    
                    if currentLine.hasPrefix("- [ ] ") || currentLine.hasPrefix("- [x] ") {
                        let checklistRange = NSRange(location: lineRange.location, length: 3)
                        mutableAttr.replaceCharacters(in: checklistRange, with: "•  ")
                        adjustSelection = 0
                    } else if let numberMatch = currentLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        let nsMatch = NSRange(numberMatch, in: currentLine)
                        let numberRange = NSRange(location: lineRange.location, length: nsMatch.length)
                        mutableAttr.replaceCharacters(in: numberRange, with: "•  ")
                        adjustSelection = 3 - nsMatch.length
                    } else {
                        mutableAttr.insert(NSAttributedString(string: "•  ", attributes: attrs), at: lineRange.location)
                    }
                    
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 1))
                    mutableAttr.addAttributes(attrs, range: newLineRange)
                    
                    textView.attributedText = mutableAttr
                    textView.selectedRange = NSRange(location: safeRange.location + adjustSelection, length: safeRange.length)
                }
                
                let newText = AttributedMarkdownRenderer.serializeToString(attributed: textView.attributedText)
                self.lastParsedText = newText
                parent.text = newText
                isUpdating = false
            }
            
            HapticManager.trigger(.light)
        }
        
        func toggleNumberedListAction() {
            guard let textView = textView else { return }
            
            let string = textView.textStorage.string as NSString
            let selectedRange = textView.selectedRange
            let safeLocation = min(selectedRange.location, string.length)
            let safeLength = min(selectedRange.length, string.length - safeLocation)
            let safeRange = NSRange(location: safeLocation, length: safeLength)
            
            let lineRange = string.length > 0
                ? string.lineRange(for: NSRange(location: safeRange.location, length: 0))
                : NSRange(location: 0, length: 0)
            
            if safeRange.location <= string.length {
                let currentLine = lineRange.length > 0 ? string.substring(with: lineRange) : ""
                
                isUpdating = true
                let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                
                let font = textView.font ?? UIFont.defaultSlateFont
                let numberedParagraphStyle = NSMutableParagraphStyle()
                numberedParagraphStyle.headIndent = 24
                numberedParagraphStyle.firstLineHeadIndent = 0
                numberedParagraphStyle.paragraphSpacing = 8
                numberedParagraphStyle.lineSpacing = 3.0
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: numberedParagraphStyle]
                
                if let numberMatch = currentLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                    let nsMatch = NSRange(numberMatch, in: currentLine)
                    let removeRange = NSRange(location: lineRange.location, length: nsMatch.length)
                    mutableAttr.replaceCharacters(in: removeRange, with: "")
                    
                    let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                    mutableAttr.addAttributes(normalAttrs, range: newLineRange)
                    
                    textView.attributedText = mutableAttr
                    textView.selectedRange = NSRange(location: max(0, safeRange.location - nsMatch.length), length: safeRange.length)
                } else {
                    var numberToUse = 1
                    if lineRange.location > 0 {
                        let aboveLineRange = string.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
                        let aboveLine = string.substring(with: aboveLineRange)
                        if let aboveMatch = aboveLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                            let numStr = aboveLine[aboveMatch].dropLast(2)
                            if let prevNum = Int(numStr) {
                                numberToUse = prevNum + 1
                            }
                        }
                    }
                    
                    let prefix = "\(numberToUse).  "
                    var adjustSelection = prefix.count
                    
                    if currentLine.hasPrefix("•  ") {
                        let bulletRange = NSRange(location: lineRange.location, length: 3)
                        mutableAttr.replaceCharacters(in: bulletRange, with: prefix)
                        adjustSelection = prefix.count - 3
                    } else if currentLine.hasPrefix("- [ ] ") || currentLine.hasPrefix("- [x] ") {
                        let checklistRange = NSRange(location: lineRange.location, length: 3)
                        mutableAttr.replaceCharacters(in: checklistRange, with: prefix)
                        adjustSelection = prefix.count - 3
                    } else {
                        mutableAttr.insert(NSAttributedString(string: prefix, attributes: attrs), at: lineRange.location)
                    }
                    
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 1))
                    mutableAttr.addAttributes(attrs, range: newLineRange)
                    
                    textView.attributedText = mutableAttr
                    textView.selectedRange = NSRange(location: safeRange.location + adjustSelection, length: safeRange.length)
                }
                
                let newText = AttributedMarkdownRenderer.serializeToString(attributed: textView.attributedText)
                self.lastParsedText = newText
                parent.text = newText
                isUpdating = false
            }
            
            HapticManager.trigger(.light)
        }
        
        // MARK: - Inline Formatting Actions
        
        private func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let textView = textView else { return }
            let string = textView.textStorage.string as NSString
            let selectedRange = textView.selectedRange
            let safeLocation = min(selectedRange.location, string.length)
            let safeLength = min(selectedRange.length, string.length - safeLocation)
            let safeRange = NSRange(location: safeLocation, length: safeLength)
            
            if safeRange.length > 0 {
                let attrString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                attrString.enumerateAttribute(.font, in: safeRange, options: []) { value, range, _ in
                    let currentFont = (value as? UIFont) ?? textView.font ?? UIFont.defaultSlateFont
                    var traits = currentFont.fontDescriptor.symbolicTraits
                    
                    if traits.contains(trait) {
                        traits.remove(trait)
                    } else {
                        traits.insert(trait)
                    }
                    
                    if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                        let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        attrString.addAttribute(.font, value: newFont, range: range)
                    }
                }
                
                isUpdating = true
                textView.attributedText = attrString
                textView.selectedRange = safeRange
                
                let newText = AttributedMarkdownRenderer.serializeToString(attributed: attrString)
                self.lastParsedText = newText
                parent.text = newText
                isUpdating = false
            } else {
                var currentAttrs = textView.typingAttributes
                let currentFont = (currentAttrs[.font] as? UIFont) ?? textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                var traits = currentFont.fontDescriptor.symbolicTraits
                
                if traits.contains(trait) {
                    traits.remove(trait)
                } else {
                    traits.insert(trait)
                }
                
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                    let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                    currentAttrs[.font] = newFont
                    textView.typingAttributes = currentAttrs
                }
            }
            
            HapticManager.trigger(.light)
        }
        
        func toggleBoldAction() {
            toggleFontTrait(.traitBold)
        }
        
        func toggleItalicAction() {
            toggleFontTrait(.traitItalic)
        }
        
        private func toggleAttribute(_ key: NSAttributedString.Key, value: Any) {
            guard let textView = textView else { return }
            let string = textView.textStorage.string as NSString
            let selectedRange = textView.selectedRange
            let safeLocation = min(selectedRange.location, string.length)
            let safeLength = min(selectedRange.length, string.length - safeLocation)
            let safeRange = NSRange(location: safeLocation, length: safeLength)
            
            if safeRange.length > 0 {
                let attrString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                var hasAttr = false
                attrString.enumerateAttribute(key, in: safeRange, options: []) { val, range, _ in
                    if val != nil {
                        hasAttr = true
                    }
                }
                
                if hasAttr {
                    attrString.removeAttribute(key, range: safeRange)
                } else {
                    attrString.addAttribute(key, value: value, range: safeRange)
                }
                
                isUpdating = true
                textView.attributedText = attrString
                textView.selectedRange = safeRange
                
                let newText = AttributedMarkdownRenderer.serializeToString(attributed: attrString)
                self.lastParsedText = newText
                parent.text = newText
                isUpdating = false
            } else {
                var currentAttrs = textView.typingAttributes
                if currentAttrs[key] != nil {
                    currentAttrs.removeValue(forKey: key)
                } else {
                    currentAttrs[key] = value
                }
                textView.typingAttributes = currentAttrs
            }
            
            HapticManager.trigger(.light)
        }
        
        func toggleUnderlineAction() {
            toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
        }
        
        func toggleStrikethroughAction() {
            toggleAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
        }
        
        // MARK: - Indentation Actions
        
        func increaseIndentAction() {
            adjustIndent(by: 24)
        }
        
        func decreaseIndentAction() {
            adjustIndent(by: -24)
        }
        
        private func adjustIndent(by amount: CGFloat) {
            guard let textView = textView else { return }
            
            let string = textView.textStorage.string as NSString
            let selectedRange = textView.selectedRange
            let safeLocation = min(selectedRange.location, string.length)
            let safeLength = min(selectedRange.length, string.length - safeLocation)
            let safeRange = NSRange(location: safeLocation, length: safeLength)
            
            let lineRange = string.lineRange(for: NSRange(location: safeRange.location, length: 0))
            
            if safeRange.location <= string.length {
                isUpdating = true
                let attrString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                var baseStyle = NSParagraphStyle.default
                if lineRange.location < attrString.length {
                    var optRange = NSRange(location: 0, length: 0)
                    if let currentPara = attrString.attribute(.paragraphStyle, at: lineRange.location, effectiveRange: &optRange) as? NSParagraphStyle {
                        baseStyle = currentPara
                    }
                } else if let typingPara = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle {
                    baseStyle = typingPara
                }
                
                let newFirstLineIndent = max(0, baseStyle.firstLineHeadIndent + amount)
                let diff = newFirstLineIndent - baseStyle.firstLineHeadIndent
                
                let newPara = NSMutableParagraphStyle()
                newPara.setParagraphStyle(baseStyle)
                newPara.firstLineHeadIndent = newFirstLineIndent
                newPara.headIndent = max(0, baseStyle.headIndent + diff)
                
                if lineRange.location < attrString.length && lineRange.location + lineRange.length <= attrString.length {
                    attrString.addAttribute(.paragraphStyle, value: newPara, range: lineRange)
                    
                    textView.attributedText = attrString
                    textView.selectedRange = safeRange
                    
                    let newText = AttributedMarkdownRenderer.serializeToString(attributed: attrString)
                    self.lastParsedText = newText
                    parent.text = newText
                } else {
                    var currentAttrs = textView.typingAttributes
                    currentAttrs[.paragraphStyle] = newPara
                    textView.typingAttributes = currentAttrs
                }
                
                isUpdating = false
            }
            
            HapticManager.trigger(.light)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if isUpdating { return }
            if textView.text.isEmpty {
                let defaultFont = UIFont.defaultSlateFont
                
                let defaultParagraphStyle = NSMutableParagraphStyle()
                defaultParagraphStyle.lineSpacing = 3.0
                defaultParagraphStyle.paragraphSpacing = 8
                
                textView.typingAttributes = [
                    .font: defaultFont,
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: defaultParagraphStyle
                ]
            }
            let newText = AttributedMarkdownRenderer.serializeToString(attributed: textView.attributedText)
            self.lastParsedText = newText
            parent.text = newText
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingEnded?()
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text.isEmpty && range.length == 0 {
                if range.location == 0 {
                    parent.onBackspaceAtStart?()
                    return false
                } else if range.location == textView.text.count {
                    parent.onDeleteAtEnd?()
                    return false
                }
            }
            if text == "\n" {
                let string = textView.textStorage.string as NSString
                let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))
                
                if lineRange.location <= string.length {
                    let currentLine = string.substring(with: lineRange)
                    let level = AttributedMarkdownRenderer.getIndentLevel(from: currentLine)
                    let strippedLine = AttributedMarkdownRenderer.stripIndent(from: currentLine, level: level)
                    
                    // 1. Checklist case
                    var r = NSRange(location: 0, length: 0)
                    let firstCharAttr = lineRange.length > 0
                        ? textView.textStorage.attribute(NSAttributedString.Key.attachment, at: lineRange.location, effectiveRange: &r)
                        : nil
                        
                    if firstCharAttr is CheckboxAttachment {
                        let isLineEmpty = strippedLine.count <= 3 || (strippedLine.count == 4 && strippedLine.hasSuffix("\n"))
                        
                        if isLineEmpty {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            mutableAttr.replaceCharacters(in: lineRange, with: "")
                            
                            let font = textView.font ?? UIFont.defaultSlateFont
                            let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                            if lineRange.location < mutableAttr.length {
                                let nsString = mutableAttr.string as NSString
                                let newRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                                mutableAttr.addAttributes(normalAttrs, range: newRange)
                            }
                            
                            textView.attributedText = mutableAttr
                            
                            let newText = AttributedMarkdownRenderer.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                            return false
                        } else {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            
                            let attachment = CheckboxAttachment(isChecked: false)
                            let newBoxStr = NSMutableAttributedString(string: "\n" + String(repeating: "  ", count: level))
                            newBoxStr.append(NSAttributedString(attachment: attachment))
                            
                            let font = textView.font ?? UIFont.defaultSlateFont
                            let paragraphStyle = NSMutableParagraphStyle()
                            let indentOffset = CGFloat(level * 24)
                            paragraphStyle.headIndent = indentOffset + 32
                            paragraphStyle.firstLineHeadIndent = indentOffset
                            paragraphStyle.paragraphSpacing = 8
                            paragraphStyle.lineSpacing = 3.0
                            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraphStyle]
                            
                            newBoxStr.append(NSAttributedString(string: "  ", attributes: attrs))
                            newBoxStr.addAttributes(attrs, range: NSRange(location: 0, length: newBoxStr.length))
                            
                            mutableAttr.replaceCharacters(in: range, with: newBoxStr)
                            textView.attributedText = mutableAttr
                            
                            let newText = AttributedMarkdownRenderer.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: range.location + newBoxStr.length, length: 0)
                            return false
                        }
                    }
                    
                    // 2. Bullet point case
                    if strippedLine.hasPrefix("•  ") {
                        let isLineEmpty = strippedLine.count <= 4
                        
                        if isLineEmpty {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            mutableAttr.replaceCharacters(in: lineRange, with: "")
                            
                            let font = textView.font ?? UIFont.defaultSlateFont
                            let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                            if lineRange.location < mutableAttr.length {
                                let nsString = mutableAttr.string as NSString
                                let newRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                                mutableAttr.addAttributes(normalAttrs, range: newRange)
                            }
                            
                            textView.attributedText = mutableAttr
                            
                            let newText = AttributedMarkdownRenderer.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                            return false
                        } else {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            
                            let font = textView.font ?? UIFont.defaultSlateFont
                            let bulletParagraphStyle = NSMutableParagraphStyle()
                            let indentOffset = CGFloat(level * 24)
                            bulletParagraphStyle.headIndent = indentOffset + 18
                            bulletParagraphStyle.firstLineHeadIndent = indentOffset
                            bulletParagraphStyle.paragraphSpacing = 8
                            bulletParagraphStyle.lineSpacing = 3.0
                            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: bulletParagraphStyle]
                            
                            let newBulletStr = NSMutableAttributedString(string: "\n" + String(repeating: "  ", count: level) + "•  ", attributes: attrs)
                            
                            mutableAttr.replaceCharacters(in: range, with: newBulletStr)
                            textView.attributedText = mutableAttr
                            
                            let newText = AttributedMarkdownRenderer.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: range.location + newBulletStr.length, length: 0)
                            return false
                        }
                    }
                    
                    // 3. Numbered list case
                    if let numberMatch = strippedLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) ?? strippedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        let prefix = String(strippedLine[numberMatch])
                        let isLineEmpty = strippedLine.count <= prefix.count + 1
                        
                        if isLineEmpty {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            mutableAttr.replaceCharacters(in: lineRange, with: "")
                            
                            let font = textView.font ?? UIFont.defaultSlateFont
                            let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                            if lineRange.location < mutableAttr.length {
                                let nsString = mutableAttr.string as NSString
                                let newRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                                mutableAttr.addAttributes(normalAttrs, range: newRange)
                            }
                            
                            textView.attributedText = mutableAttr
                            
                            let newText = AttributedMarkdownRenderer.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                            return false
                        } else {
                            let numStr = prefix.trimmingCharacters(in: .whitespaces).dropLast(1)
                            var nextNum = 1
                            if let currentNum = Int(numStr) {
                                nextNum = currentNum + 1
                            }
                            
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            
                            let font = textView.font ?? UIFont.defaultSlateFont
                            let numberedParagraphStyle = NSMutableParagraphStyle()
                            let indentOffset = CGFloat(level * 24)
                            numberedParagraphStyle.headIndent = indentOffset + 24
                            numberedParagraphStyle.firstLineHeadIndent = indentOffset
                            numberedParagraphStyle.paragraphSpacing = 8
                            numberedParagraphStyle.lineSpacing = 3.0
                            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: numberedParagraphStyle]
                            
                            let newPrefixStr = NSMutableAttributedString(string: "\n" + String(repeating: "  ", count: level) + "\(nextNum).  ", attributes: attrs)
                            
                            mutableAttr.replaceCharacters(in: range, with: newPrefixStr)
                            textView.attributedText = mutableAttr
                            
                            let newText = AttributedMarkdownRenderer.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: range.location + newPrefixStr.length, length: 0)
                            return false
                        }
                    }
                }
            }
            return true
        }
    }
}
