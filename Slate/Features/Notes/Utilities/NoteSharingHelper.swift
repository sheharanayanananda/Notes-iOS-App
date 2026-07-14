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
        
        // Ensure all text is black (or dark color) for print/PDF export
        result.addAttribute(.foregroundColor, value: UIColor.black, range: range)
        
        // Apply target font
        result.addAttribute(.font, value: font, range: range)
        
        return result
    }
    
    static func generateRichText(for note: SlateModel) -> NSAttributedString {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let baseAttr = note.attributedDesc
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

