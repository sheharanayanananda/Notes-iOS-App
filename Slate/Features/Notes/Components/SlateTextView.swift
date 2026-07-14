//
//  SlateTextView.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import UIKit

class SlateTextView: UITextView {
    var isLayoutUpdating = false
    
    override func caretRect(for position: UITextPosition) -> CGRect {
        if isLayoutUpdating {
            let defaultFont = self.font ?? UIFont.defaultSlateFont
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
                font = self.font ?? UIFont.defaultSlateFont
            }
        } else if offset == 0 && self.attributedText.length > 0 {
            var range = NSRange(location: 0, length: 0)
            if let f = self.attributedText.attribute(.font, at: 0, effectiveRange: &range) as? UIFont {
                font = f
            } else {
                font = self.font ?? UIFont.defaultSlateFont
            }
        } else {
            font = self.font ?? UIFont.defaultSlateFont
        }
        
        let targetHeight = font.lineHeight
        if rect.size.height > targetHeight {
            rect.size.height = targetHeight
        }
        
        return rect
    }
}
