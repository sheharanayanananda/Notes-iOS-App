//
//  NoteExtractionUtility.swift
//  Slate
//

import Foundation

struct NoteExtractionUtility {
    /// Heuristically extracts a title and clean note body from a raw conversational AI response.
    static func parseHeuristically(text: String) -> (title: String, body: String) {
        let lines = text.components(separatedBy: .newlines)
        
        var titleLineIndex: Int? = nil
        
        // Find the first line that looks like a markdown header or a bold title
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") || (trimmed.hasPrefix("**") && trimmed.hasSuffix("**")) {
                titleLineIndex = index
                break
            }
        }
        
        var title = ""
        var bodyStart = 0
        
        if let titleIndex = titleLineIndex {
            let rawTitle = lines[titleIndex]
            title = cleanTitle(rawTitle)
            bodyStart = titleIndex + 1
        } else {
            // Find the first non-empty line to generate a title from
            if let firstNonEmptyIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                let firstLine = lines[firstNonEmptyIndex]
                title = generateFallbackTitle(from: firstLine)
                // Do NOT skip the first line because it contains actual content (like a checklist, table, etc.)
                bodyStart = firstNonEmptyIndex
            } else {
                title = "New Note"
                bodyStart = 0
            }
        }
        
        var bodyLines = bodyStart < lines.count ? Array(lines[bodyStart...]) : []
        
        // Clean up leading newlines/empty lines in the body
        while let first = bodyLines.first, first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bodyLines.removeFirst()
        }
        
        // Strip trailing conversational outro/footer noise
        while let last = bodyLines.last {
            let trimmedLast = last.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLast.isEmpty ||
               trimmedLast == "***" ||
               trimmedLast == "---" ||
               trimmedLast.lowercased().contains("created by") ||
               trimmedLast.lowercased().contains("slate ai") ||
               trimmedLast.lowercased().contains("hope this helps") ||
               trimmedLast.lowercased().contains("let me know if") {
                bodyLines.removeLast()
            } else {
                break
            }
        }
        
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If the body ends up empty, fall back to the original text as description
        // and a shorter prefix of the text as the title.
        if body.isEmpty {
            let fallbackTitle = generateFallbackTitle(from: text)
            return (title: fallbackTitle, body: text)
        }
        
        return (title: title, body: body)
    }
    
    private static func cleanTitle(_ rawTitle: String) -> String {
        var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip markdown header prefixes (like #, ##, etc.)
        while title.hasPrefix("#") {
            title = title.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Strip bold formatting (like **Title**)
        if title.hasPrefix("**") && title.hasSuffix("**") {
            title = String(title.dropFirst(2).dropLast(2))
        }
        
        // Clean common prefixes if present (like "Title:", "Project:")
        if title.lowercased().hasPrefix("title:") {
            title = String(title.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func generateFallbackTitle(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: "#-*[]| \n\r\t"))
        let words = cleaned.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let firstThree = words.prefix(3).joined(separator: " ")
        return firstThree.isEmpty ? "New Note" : firstThree
    }
}
