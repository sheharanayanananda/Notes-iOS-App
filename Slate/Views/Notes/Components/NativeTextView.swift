//
//  NativeTextView.swift
//  Slate
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

extension UIFont {
    func bold() -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.insert(.traitBold)
        if let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return self
    }
    
    func italic() -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.insert(.traitItalic)
        if let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return self
    }
    
    var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
}

class CheckboxAttachment: NSTextAttachment {
    var isChecked: Bool
    
    init(isChecked: Bool) {
        self.isChecked = isChecked
        super.init(data: nil, ofType: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        guard let textStorage = textContainer?.textStorage else { return nil }
        
        let font: UIFont
        var range = NSRange(location: 0, length: 0)
        if charIndex < textStorage.length,
           let f = textStorage.attribute(NSAttributedString.Key.font, at: charIndex, effectiveRange: &range) as? UIFont {
            font = f
        } else {
            font = UIFont.preferredFont(forTextStyle: .body)
        }
        
        let config = UIImage.SymbolConfiguration(font: font)
        let systemName = isChecked ? "checkmark.circle.fill" : "circle"
        let color = isChecked ? UIColor.systemBlue : UIColor.tertiaryLabel
        return UIImage(systemName: systemName, withConfiguration: config)?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        guard let textStorage = textContainer?.textStorage else {
            return CGRect(x: 0, y: -4, width: 22, height: 22)
        }
        
        let font: UIFont
        var range = NSRange(location: 0, length: 0)
        if charIndex < textStorage.length,
           let f = textStorage.attribute(NSAttributedString.Key.font, at: charIndex, effectiveRange: &range) as? UIFont {
            font = f
        } else {
            font = UIFont.preferredFont(forTextStyle: .body)
        }
        
        let size = font.lineHeight
        let yOffset = (font.capHeight - size) / 2
        return CGRect(x: 0, y: yOffset, width: size, height: size)
    }
}

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

class SlateTextView: UITextView {
    var isLayoutUpdating = false
    
    override func caretRect(for position: UITextPosition) -> CGRect {
        if isLayoutUpdating {
            let defaultFont = self.font ?? UIFont.preferredFont(forTextStyle: .body)
            return CGRect(x: 24, y: 16, width: 2, height: defaultFont.lineHeight)
        }
        
        var rect = super.caretRect(for: position)
        
        let offset = self.offset(from: self.beginningOfDocument, to: position)
        let font: UIFont
        
        if offset > 0 && offset <= self.attributedText.length {
            var range = NSRange(location: 0, length: 0)
            if let f = self.attributedText.attribute(.font, at: offset - 1, effectiveRange: &range) as? UIFont {
                font = f
            } else {
                font = self.font ?? UIFont.preferredFont(forTextStyle: .body)
            }
        } else if offset == 0 && self.attributedText.length > 0 {
            var range = NSRange(location: 0, length: 0)
            if let f = self.attributedText.attribute(.font, at: 0, effectiveRange: &range) as? UIFont {
                font = f
            } else {
                font = self.font ?? UIFont.preferredFont(forTextStyle: .body)
            }
        } else {
            font = self.font ?? UIFont.preferredFont(forTextStyle: .body)
        }
        
        let targetHeight = font.lineHeight
        if rect.size.height > targetHeight {
            rect.size.height = targetHeight
        }
        
        return rect
    }
}

struct NativeTextView: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = SlateTextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        textView.font = bodyFont
        textView.textColor = UIColor.label
        
        let defaultParagraphStyle = NSMutableParagraphStyle()
        defaultParagraphStyle.paragraphSpacing = 8
        
        textView.typingAttributes = [
            .font: bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: defaultParagraphStyle
        ]
        
        // Match native notes text container inset with 24pt side margins to align with toolbar
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        
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
        
        if context.coordinator.lastParsedText != text && !context.coordinator.isUpdating {
            let font = UIFont.preferredFont(forTextStyle: .body)
            let attr = NativeTextView.parseToAttributed(text: text, font: font)
            
            let selectedRange = uiView.selectedRange
            slateTextView?.isLayoutUpdating = true
            context.coordinator.isUpdating = true
            uiView.attributedText = attr
            context.coordinator.isUpdating = false
            
            uiView.font = font
            
            let defaultParagraphStyle = NSMutableParagraphStyle()
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private static func getIndentLevel(from line: String) -> Int {
        var spaceCount = 0
        for char in line {
            if char == " " {
                spaceCount += 1
            } else if char == "\t" {
                spaceCount += 2
            } else {
                break
            }
        }
        return spaceCount / 2
    }
    
    private static func stripIndent(from line: String, level: Int) -> String {
        return String(line.dropFirst(level * 2))
    }
    
    static func parseInlineMarkdown(_ text: String, font: UIFont) -> NSAttributedString {
        let attrString = NSMutableAttributedString(string: text)
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        attrString.addAttributes(defaultAttributes, range: NSRange(location: 0, length: attrString.length))
        
        // Parse and format tags
        parseAndReplaceTag(attrString, pattern: #"<u>(.*?)</u>"#, font: font) { mutableContent, range, _ in
            mutableContent.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        parseAndReplaceTag(attrString, pattern: #"~~(.*?)~~"#, font: font) { mutableContent, range, _ in
            mutableContent.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        parseAndReplaceTag(attrString, pattern: #"\*\*(.*?)\*\*"#, font: font) { mutableContent, range, _ in
            mutableContent.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                if let currentFont = value as? UIFont {
                    mutableContent.addAttribute(.font, value: currentFont.bold(), range: subRange)
                }
            }
        }
        
        parseAndReplaceTag(attrString, pattern: #"\*(.*?)\*"#, font: font) { mutableContent, range, _ in
            mutableContent.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                if let currentFont = value as? UIFont {
                    mutableContent.addAttribute(.font, value: currentFont.italic(), range: subRange)
                }
            }
        }
        
        return attrString
    }
    
    private static func parseAndReplaceTag(
        _ attrString: NSMutableAttributedString,
        pattern: String,
        font: UIFont,
        applyFormatting: (NSMutableAttributedString, NSRange, String) -> Void
    ) {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        
        var matchFound = true
        while matchFound {
            let range = NSRange(location: 0, length: attrString.length)
            if let match = regex.firstMatch(in: attrString.string, options: [], range: range) {
                let tagRange = match.range(at: 0)
                let contentRange = match.range(at: 1)
                
                let contentAttrString = attrString.attributedSubstring(from: contentRange)
                let mutableContent = NSMutableAttributedString(attributedString: contentAttrString)
                
                guard tagRange.length > 0 else {
                    matchFound = false
                    break
                }
                
                guard mutableContent.length > 0 else {
                    attrString.replaceCharacters(in: tagRange, with: mutableContent)
                    continue
                }
                
                let newRange = NSRange(location: 0, length: mutableContent.length)
                applyFormatting(mutableContent, newRange, mutableContent.string)
                
                attrString.replaceCharacters(in: tagRange, with: mutableContent)
            } else {
                matchFound = false
            }
        }
    }
    
    static func parseToAttributed(text: String, font: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let sanitizedText = text.replacingOccurrences(of: "\r", with: "")
        let lines = sanitizedText.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let level = getIndentLevel(from: line)
            let strippedLine = stripIndent(from: line, level: level)
            let indentOffset = CGFloat(level * 24)
            
            let checklistParagraphStyle = NSMutableParagraphStyle()
            checklistParagraphStyle.headIndent = indentOffset + 32
            checklistParagraphStyle.firstLineHeadIndent = indentOffset
            checklistParagraphStyle.paragraphSpacing = 8
            
            let bulletParagraphStyle = NSMutableParagraphStyle()
            bulletParagraphStyle.headIndent = indentOffset + 16
            bulletParagraphStyle.firstLineHeadIndent = indentOffset
            bulletParagraphStyle.paragraphSpacing = 8
            
            let numberedParagraphStyle = NSMutableParagraphStyle()
            numberedParagraphStyle.headIndent = indentOffset + 20
            numberedParagraphStyle.firstLineHeadIndent = indentOffset
            numberedParagraphStyle.paragraphSpacing = 8
            
            let normalParagraphStyle = NSMutableParagraphStyle()
            normalParagraphStyle.headIndent = indentOffset
            normalParagraphStyle.firstLineHeadIndent = indentOffset
            normalParagraphStyle.paragraphSpacing = 8
            
            if strippedLine.hasPrefix("- [ ] ") {
                let attachment = CheckboxAttachment(isChecked: false)
                let attrString = NSMutableAttributedString(attachment: attachment)
                let contentText = String(strippedLine.dropFirst(6))
                let contentAttr = parseInlineMarkdown(" " + contentText, font: font)
                attrString.append(contentAttr)
                
                attrString.addAttribute(.paragraphStyle, value: checklistParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                attrString.addAttributes([.font: font, .foregroundColor: UIColor.label], range: NSRange(location: 0, length: 2))
                
                result.append(attrString)
            } else if strippedLine.hasPrefix("- [x] ") {
                let attachment = CheckboxAttachment(isChecked: true)
                let attrString = NSMutableAttributedString(attachment: attachment)
                let contentText = String(strippedLine.dropFirst(6))
                let contentAttr = parseInlineMarkdown(" " + contentText, font: font)
                
                let mutableContent = NSMutableAttributedString(attributedString: contentAttr)
                let textRange = NSRange(location: 0, length: mutableContent.length)
                mutableContent.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
                mutableContent.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: textRange)
                
                attrString.append(mutableContent)
                
                attrString.addAttribute(.paragraphStyle, value: checklistParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                attrString.addAttributes([.font: font, .foregroundColor: UIColor.label], range: NSRange(location: 0, length: 2))
                
                result.append(attrString)
            } else if strippedLine.hasPrefix("- ") || strippedLine.hasPrefix("• ") {
                let contentText = String(strippedLine.dropFirst(2))
                let contentAttr = parseInlineMarkdown(contentText, font: font)
                let attrString = NSMutableAttributedString(string: "• ")
                attrString.append(contentAttr)
                
                attrString.addAttribute(.paragraphStyle, value: bulletParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                attrString.addAttributes([.font: font, .foregroundColor: UIColor.label], range: NSRange(location: 0, length: 2))
                
                result.append(attrString)
            } else if let numberMatch = strippedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let prefix = String(strippedLine[numberMatch])
                let contentText = String(strippedLine[numberMatch.upperBound...])
                let contentAttr = parseInlineMarkdown(contentText, font: font)
                let attrString = NSMutableAttributedString(string: prefix)
                attrString.append(contentAttr)
                
                attrString.addAttribute(.paragraphStyle, value: numberedParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                attrString.addAttributes([.font: font, .foregroundColor: UIColor.label], range: NSRange(location: 0, length: prefix.count))
                
                result.append(attrString)
            } else {
                let contentAttr = parseInlineMarkdown(strippedLine, font: font)
                let attrString = NSMutableAttributedString(attributedString: contentAttr)
                
                attrString.addAttribute(.paragraphStyle, value: normalParagraphStyle, range: NSRange(location: 0, length: attrString.length))
                
                result.append(attrString)
            }
            
            if index < lines.count - 1 {
                let isList = strippedLine.hasPrefix("- [ ] ") || strippedLine.hasPrefix("- [x] ") || strippedLine.hasPrefix("- ") || strippedLine.hasPrefix("• ") || strippedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
                let newlineParagraphStyle = isList ? (strippedLine.hasPrefix("- ") || strippedLine.hasPrefix("• ") ? bulletParagraphStyle : (strippedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil ? numberedParagraphStyle : checklistParagraphStyle)) : normalParagraphStyle
                
                let newlineAttrs: [NSAttributedString.Key: Any] = [
                    .paragraphStyle: newlineParagraphStyle,
                    .font: font,
                    .foregroundColor: UIColor.label
                ]
                result.append(NSAttributedString(string: "\n", attributes: newlineAttrs))
            }
        }
        
        return result
    }
    
    static func serializeToString(attributed: NSAttributedString) -> String {
        var result = ""
        let string = attributed.string as NSString
        
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attrs, range, _ in
            if let attachment = attrs[.attachment] as? CheckboxAttachment {
                result += attachment.isChecked ? "- [x]" : "- [ ]"
            } else {
                let substring = string.substring(with: range)
                let cleaned = substring.replacingOccurrences(of: "\u{FFFC}", with: "")
                
                var prefix = ""
                var suffix = ""
                
                if let font = attrs[.font] as? UIFont {
                    if font.isBold {
                        prefix += "**"
                        suffix = "**" + suffix
                    }
                    if font.isItalic {
                        prefix += "*"
                        suffix = "*" + suffix
                    }
                }
                
                if let underline = attrs[.underlineStyle] as? Int, underline > 0 {
                    prefix += "<u>"
                    suffix = "</u>" + suffix
                }
                
                if let strikethrough = attrs[.strikethroughStyle] as? Int, strikethrough > 0 {
                    var isChecklistStrikethrough = false
                    let lineRange = string.lineRange(for: range)
                    if lineRange.length > 0 {
                        var optRange = NSRange(location: 0, length: 0)
                        if let firstAttr = attributed.attribute(.attachment, at: lineRange.location, effectiveRange: &optRange) as? CheckboxAttachment {
                            if firstAttr.isChecked {
                                isChecklistStrikethrough = true
                            }
                        }
                    }
                    
                    if !isChecklistStrikethrough {
                        prefix += "~~"
                        suffix = "~~" + suffix
                    }
                }
                
                result += prefix + cleaned + suffix
            }
        }
        
        var lines = result.components(separatedBy: "\n")
        for i in 0..<lines.count {
            let lineStart = findLineStartInAttributed(attributed, lineIndex: i)
            if lineStart < attributed.length {
                var optRange = NSRange(location: 0, length: 0)
                if let paraStyle = attributed.attribute(.paragraphStyle, at: lineStart, effectiveRange: &optRange) as? NSParagraphStyle {
                    let level = Int(paraStyle.firstLineHeadIndent / 24)
                    if level > 0 {
                        let spaces = String(repeating: " ", count: level * 2)
                        lines[i] = spaces + lines[i]
                    }
                }
            }
            
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("• ") {
                if let bulletRange = lines[i].range(of: "• ") {
                    lines[i] = lines[i].replacingCharacters(in: bulletRange, with: "- ")
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private static func findLineStartInAttributed(_ attrString: NSAttributedString, lineIndex: Int) -> Int {
        let string = attrString.string as NSString
        var currentLineIndex = 0
        var currentIndex = 0
        
        while currentIndex < string.length {
            let lineRange = string.lineRange(for: NSRange(location: currentIndex, length: 0))
            if currentLineIndex == lineIndex {
                return lineRange.location
            }
            currentIndex = lineRange.location + lineRange.length
            currentLineIndex += 1
        }
        
        return string.length
    }
    
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
            
            let expandedRect = boundingRect.insetBy(dx: -10, dy: -10)
            
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
            
            let expandedRect = boundingRect.insetBy(dx: -10, dy: -10)
            
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
            
            if lineRange.length > 2 {
                let startPos = index + 2
                let endPos = lineRange.location + lineRange.length
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
            textView.selectedRange = selectedRange
            
            let newText = NativeTextView.serializeToString(attributed: attrString)
            self.lastParsedText = newText
            parent.text = newText
            isUpdating = false
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
                    
                    let newText = NativeTextView.serializeToString(attributed: mutableAttr)
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
                    
                    let newText = NativeTextView.serializeToString(attributed: mutableAttr)
                    self.lastParsedText = newText
                    parent.text = newText
                    isUpdating = false
                    
                    textView.selectedRange = NSRange(location: selectedRange.location + newBoxStr.length, length: selectedRange.length)
                }
            }
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
                
                let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                let bulletParagraphStyle = NSMutableParagraphStyle()
                bulletParagraphStyle.headIndent = 16
                bulletParagraphStyle.firstLineHeadIndent = 0
                bulletParagraphStyle.paragraphSpacing = 8
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: bulletParagraphStyle]
                
                if currentLine.hasPrefix("• ") {
                    let nsLine = currentLine as NSString
                    let cleanLine = nsLine.substring(from: 2)
                    mutableAttr.replaceCharacters(in: lineRange, with: cleanLine)
                    
                    let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                    mutableAttr.addAttributes(normalAttrs, range: newLineRange)
                    
                    textView.attributedText = mutableAttr
                    textView.selectedRange = NSRange(location: max(0, safeRange.location - 2), length: safeRange.length)
                } else {
                    var adjustSelection = 2
                    
                    if currentLine.hasPrefix("- [ ] ") || currentLine.hasPrefix("- [x] ") {
                        let checklistRange = NSRange(location: lineRange.location, length: 2)
                        mutableAttr.replaceCharacters(in: checklistRange, with: "• ")
                        adjustSelection = 0
                    } else if let numberMatch = currentLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        let nsMatch = NSRange(numberMatch, in: currentLine)
                        let numberRange = NSRange(location: lineRange.location, length: nsMatch.length)
                        mutableAttr.replaceCharacters(in: numberRange, with: "• ")
                        adjustSelection = 2 - nsMatch.length
                    } else {
                        mutableAttr.insert(NSAttributedString(string: "• ", attributes: attrs), at: lineRange.location)
                    }
                    
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 1))
                    mutableAttr.addAttributes(attrs, range: newLineRange)
                    
                    textView.attributedText = mutableAttr
                    textView.selectedRange = NSRange(location: safeRange.location + adjustSelection, length: safeRange.length)
                }
                
                let newText = NativeTextView.serializeToString(attributed: textView.attributedText)
                self.lastParsedText = newText
                parent.text = newText
                isUpdating = false
            }
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
                
                let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                let numberedParagraphStyle = NSMutableParagraphStyle()
                numberedParagraphStyle.headIndent = 20
                numberedParagraphStyle.firstLineHeadIndent = 0
                numberedParagraphStyle.paragraphSpacing = 8
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
                    
                    let prefix = "\(numberToUse). "
                    var adjustSelection = prefix.count
                    
                    if currentLine.hasPrefix("• ") {
                        let bulletRange = NSRange(location: lineRange.location, length: 2)
                        mutableAttr.replaceCharacters(in: bulletRange, with: prefix)
                        adjustSelection = prefix.count - 2
                    } else if currentLine.hasPrefix("- [ ] ") || currentLine.hasPrefix("- [x] ") {
                        let checklistRange = NSRange(location: lineRange.location, length: 2)
                        mutableAttr.replaceCharacters(in: checklistRange, with: prefix)
                        adjustSelection = prefix.count - 2
                    } else {
                        mutableAttr.insert(NSAttributedString(string: prefix, attributes: attrs), at: lineRange.location)
                    }
                    
                    let nsString = mutableAttr.string as NSString
                    let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 1))
                    mutableAttr.addAttributes(attrs, range: newLineRange)
                    
                    textView.attributedText = mutableAttr
                    textView.selectedRange = NSRange(location: safeRange.location + adjustSelection, length: safeRange.length)
                }
                
                let newText = NativeTextView.serializeToString(attributed: textView.attributedText)
                self.lastParsedText = newText
                parent.text = newText
                isUpdating = false
            }
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
                    let currentFont = (value as? UIFont) ?? textView.font ?? UIFont.preferredFont(forTextStyle: .body)
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
                
                let newText = NativeTextView.serializeToString(attributed: attrString)
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
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
                
                let newText = NativeTextView.serializeToString(attributed: attrString)
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
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
                    
                    let newText = NativeTextView.serializeToString(attributed: attrString)
                    self.lastParsedText = newText
                    parent.text = newText
                } else {
                    var currentAttrs = textView.typingAttributes
                    currentAttrs[.paragraphStyle] = newPara
                    textView.typingAttributes = currentAttrs
                }
                
                isUpdating = false
            }
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if isUpdating { return }
            if textView.text.isEmpty {
                let defaultFont = UIFont.preferredFont(forTextStyle: .body)
                
                let defaultParagraphStyle = NSMutableParagraphStyle()
                defaultParagraphStyle.paragraphSpacing = 8
                
                textView.typingAttributes = [
                    .font: defaultFont,
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: defaultParagraphStyle
                ]
            }
            let newText = NativeTextView.serializeToString(attributed: textView.attributedText)
            self.lastParsedText = newText
            parent.text = newText
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                let string = textView.textStorage.string as NSString
                let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))
                
                if lineRange.location <= string.length {
                    let currentLine = string.substring(with: lineRange)
                    let level = NativeTextView.getIndentLevel(from: currentLine)
                    let strippedLine = NativeTextView.stripIndent(from: currentLine, level: level)
                    
                    // 1. Checklist case
                    var r = NSRange(location: 0, length: 0)
                    let firstCharAttr = lineRange.length > 0
                        ? textView.textStorage.attribute(NSAttributedString.Key.attachment, at: lineRange.location, effectiveRange: &r)
                        : nil
                        
                    if firstCharAttr is CheckboxAttachment {
                        let isLineEmpty = strippedLine.count <= 2 || (strippedLine.count == 3 && strippedLine.hasSuffix("\n"))
                        
                        if isLineEmpty {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            mutableAttr.replaceCharacters(in: lineRange, with: "")
                            
                            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                            let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                            if lineRange.location < mutableAttr.length {
                                let nsString = mutableAttr.string as NSString
                                let newRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                                mutableAttr.addAttributes(normalAttrs, range: newRange)
                            }
                            
                            textView.attributedText = mutableAttr
                            
                            let newText = NativeTextView.serializeToString(attributed: mutableAttr)
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
                            
                            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                            let paragraphStyle = NSMutableParagraphStyle()
                            let indentOffset = CGFloat(level * 24)
                            paragraphStyle.headIndent = indentOffset + 32
                            paragraphStyle.firstLineHeadIndent = indentOffset
                            paragraphStyle.paragraphSpacing = 8
                            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraphStyle]
                            
                            newBoxStr.append(NSAttributedString(string: " ", attributes: attrs))
                            newBoxStr.addAttributes(attrs, range: NSRange(location: 0, length: newBoxStr.length))
                            
                            mutableAttr.replaceCharacters(in: range, with: newBoxStr)
                            textView.attributedText = mutableAttr
                            
                            let newText = NativeTextView.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: range.location + newBoxStr.length, length: 0)
                            return false
                        }
                    }
                    
                    // 2. Bullet point case
                    if strippedLine.hasPrefix("• ") {
                        let isLineEmpty = strippedLine.count <= 3
                        
                        if isLineEmpty {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            mutableAttr.replaceCharacters(in: lineRange, with: "")
                            
                            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                            let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                            if lineRange.location < mutableAttr.length {
                                let nsString = mutableAttr.string as NSString
                                let newRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                                mutableAttr.addAttributes(normalAttrs, range: newRange)
                            }
                            
                            textView.attributedText = mutableAttr
                            
                            let newText = NativeTextView.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                            return false
                        } else {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            
                            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                            let bulletParagraphStyle = NSMutableParagraphStyle()
                            let indentOffset = CGFloat(level * 24)
                            bulletParagraphStyle.headIndent = indentOffset + 16
                            bulletParagraphStyle.firstLineHeadIndent = indentOffset
                            bulletParagraphStyle.paragraphSpacing = 8
                            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: bulletParagraphStyle]
                            
                            let newBulletStr = NSMutableAttributedString(string: "\n" + String(repeating: "  ", count: level) + "• ", attributes: attrs)
                            
                            mutableAttr.replaceCharacters(in: range, with: newBulletStr)
                            textView.attributedText = mutableAttr
                            
                            let newText = NativeTextView.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: range.location + newBulletStr.length, length: 0)
                            return false
                        }
                    }
                    
                    // 3. Numbered list case
                    if let numberMatch = strippedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        let prefix = String(strippedLine[numberMatch])
                        let isLineEmpty = strippedLine.count <= prefix.count + 1
                        
                        if isLineEmpty {
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            mutableAttr.replaceCharacters(in: lineRange, with: "")
                            
                            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                            let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: NSMutableParagraphStyle()]
                            if lineRange.location < mutableAttr.length {
                                let nsString = mutableAttr.string as NSString
                                let newRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
                                mutableAttr.addAttributes(normalAttrs, range: newRange)
                            }
                            
                            textView.attributedText = mutableAttr
                            
                            let newText = NativeTextView.serializeToString(attributed: mutableAttr)
                            self.lastParsedText = newText
                            parent.text = newText
                            isUpdating = false
                            
                            textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                            return false
                        } else {
                            let numStr = prefix.dropLast(2)
                            var nextNum = 1
                            if let currentNum = Int(numStr) {
                                nextNum = currentNum + 1
                            }
                            
                            isUpdating = true
                            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
                            
                            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                            let numberedParagraphStyle = NSMutableParagraphStyle()
                            let indentOffset = CGFloat(level * 24)
                            numberedParagraphStyle.headIndent = indentOffset + 20
                            numberedParagraphStyle.firstLineHeadIndent = indentOffset
                            numberedParagraphStyle.paragraphSpacing = 8
                            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: numberedParagraphStyle]
                            
                            let newPrefixStr = NSMutableAttributedString(string: "\n" + String(repeating: "  ", count: level) + "\(nextNum). ", attributes: attrs)
                            
                            mutableAttr.replaceCharacters(in: range, with: newPrefixStr)
                            textView.attributedText = mutableAttr
                            
                            let newText = NativeTextView.serializeToString(attributed: mutableAttr)
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
