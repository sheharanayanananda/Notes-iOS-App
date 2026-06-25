//
//  NoteSharingHelper.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-08.
//

import UIKit
import PDFKit

struct NoteSharingHelper {
    
    static func prepareForExport(_ attributedString: NSAttributedString, font: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributedString)
        let range = NSRange(location: 0, length: result.length)
        
        // Resolve dynamic colors using light mode trait collection to prevent invisible text in dark mode
        result.enumerateAttribute(.foregroundColor, in: range, options: []) { value, subrange, _ in
            if let color = value as? UIColor {
                let lightColor = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                result.removeAttribute(.foregroundColor, range: subrange)
                result.addAttribute(.foregroundColor, value: lightColor, range: subrange)
            } else {
                result.addAttribute(.foregroundColor, value: UIColor.black, range: subrange)
            }
        }
        
        result.enumerateAttribute(.attachment, in: range, options: []) { value, subrange, _ in
            if let customAttachment = value as? CheckboxAttachment {
                let config = UIImage.SymbolConfiguration(font: font)
                let systemName = customAttachment.isChecked ? "checkmark.circle.fill" : "circle"
                let rawColor = customAttachment.isChecked ? UIColor.systemBlue : UIColor.tertiaryLabel
                let color = rawColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                if let rawImage = UIImage(systemName: systemName, withConfiguration: config)?.withTintColor(color, renderingMode: .alwaysOriginal) {
                    let standardAttachment = NSTextAttachment()
                    standardAttachment.image = rawImage
                    
                    let size = font.lineHeight
                    let yOffset = (font.capHeight - size) / 2
                    standardAttachment.bounds = CGRect(x: 0, y: yOffset, width: size, height: size)
                    
                    result.removeAttribute(.attachment, range: subrange)
                    result.addAttribute(.attachment, value: standardAttachment, range: subrange)
                }
            }
        }
        
        return result
    }
    
    static func generateRichText(for note: SlateModel) -> NSAttributedString {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let baseAttr = NativeTextView.parseToAttributed(text: note.desc, font: font)
        return prepareForExport(baseAttr, font: font)
    }
    
    static func generateMarkdownText(for note: SlateModel) -> String {
        return note.desc
    }
    
    static func generatePDF(for note: SlateModel) -> URL? {
        let content = generateRichText(for: note)
        
        // A4 page boundaries: 595 x 842 points
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        
        let cleanTitle = note.title.isEmpty ? "New Note" : note.title
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(cleanTitle).pdf")
        
        do {
            try pdfRenderer.writePDF(to: fileURL) { context in
                context.beginPage()
                // Use 24pt margins on A4: 595 - 48 = 547 width, 842 - 48 = 794 height
                content.draw(in: CGRect(x: 24, y: 24, width: 547, height: 794))
            }
            return fileURL
        } catch {
            print("Could not create PDF file: \(error)")
            return nil
        }
    }
    
    static func generateTextFile(for note: SlateModel) -> URL? {
        let cleanTitle = note.title.isEmpty ? "New Note" : note.title
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(cleanTitle).txt")
        
        do {
            try note.desc.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Could not create text file: \(error)")
            return nil
        }
    }
}

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
