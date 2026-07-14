//
//  SlateModel+Rendering.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import UIKit
import SwiftUI

extension SlateModel {
    var attributedDesc: NSAttributedString {
        let mdOptions = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attrStr = try? AttributedString(markdown: desc, options: mdOptions) {
            return NSAttributedString(attrStr)
        }
        
        return NSAttributedString(string: desc)
    }
}
