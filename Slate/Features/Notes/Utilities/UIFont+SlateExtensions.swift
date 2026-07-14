//
//  UIFont+SlateExtensions.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import UIKit

extension UIFont {
    static var defaultSlateFont: UIFont {
        return UIFont.systemFont(ofSize: 16)
    }
    
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
