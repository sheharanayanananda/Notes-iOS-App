//
//  CheckboxAttachment.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import UIKit

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
        let checkboxFont = UIFont.systemFont(ofSize: 24)
        let config = UIImage.SymbolConfiguration(font: checkboxFont)
        let systemName = isChecked ? "checkmark.circle.fill" : "circle"
        let color = isChecked ? UIColor.systemBlue : UIColor.secondaryLabel.withAlphaComponent(0.6)
        return UIImage(systemName: systemName, withConfiguration: config)?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        guard let textStorage = textContainer?.textStorage else {
            return CGRect(x: 0, y: -4.5, width: 24, height: 24)
        }
        
        let font: UIFont
        var range = NSRange(location: 0, length: 0)
        if charIndex < textStorage.length,
           let f = textStorage.attribute(NSAttributedString.Key.font, at: charIndex, effectiveRange: &range) as? UIFont {
            font = f
        } else {
            font = UIFont.defaultSlateFont
        }
        
        let size: CGFloat = 24
        let yOffset = (font.capHeight - size) / 2
        return CGRect(x: 0, y: yOffset, width: size, height: size)
    }
}
