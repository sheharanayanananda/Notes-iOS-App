//
//  NoteShareItemSource.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import UIKit

class NoteItemSource: NSObject, UIActivityItemSource {
    let note: SlateModel
    
    init(note: SlateModel) {
        self.note = note
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return note.title
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        if activityType == .message || activityType == .mail || activityType?.rawValue == "com.apple.mobilenotes.SharingExtension" {
            let richText = NoteSharingHelper.generateRichText(for: note)
            if let rtfData = try? richText.data(from: NSRange(location: 0, length: richText.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                return rtfData
            }
            return richText
        } else {
            return NoteSharingHelper.generateMarkdownText(for: note)
        }
    }
}
