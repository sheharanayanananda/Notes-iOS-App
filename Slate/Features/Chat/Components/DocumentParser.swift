//
//  DocumentParser.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-06-22.
//

import Foundation
import UIKit
import PDFKit
import Compression

enum ZIPError: Error {
    case fileNotFound(String)
    case invalidArchive
    case compressionFailed
}

struct ZIPArchive {
    let data: Data
    
    func extract(fileName: String) throws -> Data {
        var eocdOffset = -1
        let size = data.count
        
        // Search backwards from the end of the file for EOCD signature
        for i in stride(from: size - 22, to: max(0, size - 1024), by: -1) {
            if data[i] == 0x50 && data[i+1] == 0x4b && data[i+2] == 0x05 && data[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        guard eocdOffset != -1 else {
            throw ZIPError.invalidArchive
        }
        
        let cdOffset = Int(readUInt32(offset: eocdOffset + 16))
        let recordCount = Int(readUInt16(offset: eocdOffset + 8))
        
        var currentOffset = cdOffset
        for _ in 0..<recordCount {
            guard readUInt32(offset: currentOffset) == 0x02014b50 else {
                throw ZIPError.invalidArchive
            }
            
            let compressionMethod = readUInt16(offset: currentOffset + 10)
            let compressedSize = Int(readUInt32(offset: currentOffset + 20))
            let uncompressedSize = Int(readUInt32(offset: currentOffset + 24))
            let fileNameLen = Int(readUInt16(offset: currentOffset + 28))
            let extraFieldLen = Int(readUInt16(offset: currentOffset + 30))
            let fileCommentLen = Int(readUInt16(offset: currentOffset + 32))
            let localHeaderOffset = Int(readUInt32(offset: currentOffset + 42))
            
            let nameRange = (currentOffset + 46)..<(currentOffset + 46 + fileNameLen)
            let entryName = String(decoding: data[nameRange], as: UTF8.self)
            
            if entryName == fileName {
                guard readUInt32(offset: localHeaderOffset) == 0x04034b50 else {
                    throw ZIPError.invalidArchive
                }
                let localFileNameLen = Int(readUInt16(offset: localHeaderOffset + 26))
                let localExtraFieldLen = Int(readUInt16(offset: localHeaderOffset + 28))
                
                let dataStart = localHeaderOffset + 30 + localFileNameLen + localExtraFieldLen
                let compressedData = data.subdata(in: dataStart..<(dataStart + compressedSize))
                
                if compressionMethod == 0 {
                    return compressedData
                } else if compressionMethod == 8 {
                    return try decompressDeflate(compressedData: compressedData, uncompressedSize: uncompressedSize)
                } else {
                    throw ZIPError.compressionFailed
                }
            }
            
            currentOffset += 46 + fileNameLen + extraFieldLen + fileCommentLen
        }
        throw ZIPError.fileNotFound(fileName)
    }
    
    private func readUInt16(offset: Int) -> UInt16 {
        return data.withUnsafeBytes { bp in
            bp.load(fromByteOffset: offset, as: UInt16.self)
        }
    }
    
    private func readUInt32(offset: Int) -> UInt32 {
        return data.withUnsafeBytes { bp in
            bp.load(fromByteOffset: offset, as: UInt32.self)
        }
    }
    
    private func decompressDeflate(compressedData: Data, uncompressedSize: Int) throws -> Data {
        let sourceBuffer = [UInt8](compressedData)
        var destinationBuffer = [UInt8](repeating: 0, count: uncompressedSize)
        
        let decompressedSize = sourceBuffer.withUnsafeBufferPointer { sourceBP in
            destinationBuffer.withUnsafeMutableBufferPointer { destBP in
                compression_decode_buffer(
                    destBP.baseAddress!,
                    uncompressedSize,
                    sourceBP.baseAddress!,
                    compressedData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        guard decompressedSize == uncompressedSize else {
            throw ZIPError.compressionFailed
        }
        return Data(destinationBuffer)
    }
}

// SAX handler for DOCX parsing
class DocxXMLHandler: NSObject, XMLParserDelegate {
    var extractedText = ""
    private var inText = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "w:t" {
            inText = true
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "w:t" {
            inText = false
        } else if elementName == "w:p" {
            extractedText += "\n"
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText {
            extractedText += string
        }
    }
}

// SAX handler for XLSX Shared Strings parsing
class SharedStringsHandler: NSObject, XMLParserDelegate {
    var strings = [String]()
    private var currentString = ""
    private var inText = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "t" {
            inText = true
            currentString = ""
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            inText = false
            strings.append(currentString)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText {
            currentString += string
        }
    }
}

// SAX handler for XLSX Cell Grid parsing
class WorksheetHandler: NSObject, XMLParserDelegate {
    let sharedStrings: [String]
    var grid = [Int: [Int: String]]()
    
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentValue = ""
    private var inValue = false
    private var currentRow = 0
    
    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "c" {
            currentCellRef = attributeDict["r"] ?? ""
            currentCellType = attributeDict["t"] ?? ""
            currentValue = ""
        } else if elementName == "v" {
            inValue = true
        } else if elementName == "row" {
            if let rStr = attributeDict["r"], let rNum = Int(rStr) {
                currentRow = rNum - 1
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "c" {
            if let (col, row) = parseCellRef(currentCellRef) {
                var cellVal = currentValue
                if currentCellType == "s", let idx = Int(currentValue), idx >= 0, idx < sharedStrings.count {
                    cellVal = sharedStrings[idx]
                }
                if grid[row] == nil {
                    grid[row] = [:]
                }
                grid[row]?[col] = cellVal
            }
        } else if elementName == "v" {
            inValue = false
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue {
            currentValue += string
        }
    }
    
    private func columnNumber(from colRef: String) -> Int {
        var number = 0
        for char in colRef.uppercased() {
            if let ascii = char.asciiValue {
                number = number * 26 + Int(ascii - 64)
            }
        }
        return number - 1
    }
    
    private func parseCellRef(_ ref: String) -> (col: Int, row: Int)? {
        let letters = ref.filter { $0.isLetter }
        let digits = ref.filter { $0.isNumber }
        guard !letters.isEmpty, let row = Int(digits) else { return nil }
        return (columnNumber(from: letters), row - 1)
    }
}

final class DocumentParser {
    
    static func extractTextFromPDF(data: Data, onNeedsVisualRendering: () -> Void) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        var extractedText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                extractedText += pageText + "\n"
            }
        }
        
        let trimmed = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 15 {
            onNeedsVisualRendering()
            return nil
        }
        return trimmed
    }
    
    static func renderPDFPagesToImages(data: Data) -> [UIImage] {
        guard let document = PDFDocument(data: data) else { return [] }
        var images = [UIImage]()
        let pageLimit = min(document.pageCount, 10)
        for i in 0..<pageLimit {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(CGRect(origin: .zero, size: pageRect.size))
                context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: context.cgContext)
            }
            images.append(image)
        }
        return images
    }
    
    static func extractTextFromRTF(data: Data) -> String? {
        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            return attributedString.string
        }
        return nil
    }
    
    static func extractTextFromDocx(data: Data) -> String? {
        guard let xmlData = try? ZIPArchive(data: data).extract(fileName: "word/document.xml") else {
            return nil
        }
        let parser = XMLParser(data: xmlData)
        let handler = DocxXMLHandler()
        parser.delegate = handler
        parser.parse()
        return handler.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func extractTextFromXlsx(data: Data) -> String? {
        let archive = ZIPArchive(data: data)
        
        // Parse shared strings first
        var sharedStrings = [String]()
        if let xmlStringsData = try? archive.extract(fileName: "xl/sharedStrings.xml") {
            let parser = XMLParser(data: xmlStringsData)
            let handler = SharedStringsHandler()
            parser.delegate = handler
            parser.parse()
            sharedStrings = handler.strings
        }
        
        // Parse sheet1
        guard let xmlSheetData = try? archive.extract(fileName: "xl/worksheets/sheet1.xml") else {
            return nil
        }
        let parser = XMLParser(data: xmlSheetData)
        let handler = WorksheetHandler(sharedStrings: sharedStrings)
        parser.delegate = handler
        parser.parse()
        
        return makeMarkdownTable(from: handler.grid)
    }
    
    private static func makeMarkdownTable(from grid: [Int: [Int: String]]) -> String {
        guard !grid.isEmpty else { return "" }
        
        let rows = grid.keys.sorted()
        let maxRow = rows.last ?? 0
        
        var maxCol = 0
        for r in grid.values {
            if let colMax = r.keys.max() {
                maxCol = max(maxCol, colMax)
            }
        }
        
        var markdown = ""
        
        // Header row
        var headerRow = "|"
        var separatorRow = "|"
        for col in 0...maxCol {
            let val = grid[0]?[col] ?? "Col \(col + 1)"
            headerRow += " \(val) |"
            separatorRow += "---|"
        }
        markdown += headerRow + "\n" + separatorRow + "\n"
        
        // Remaining rows
        let startRow = grid[0] != nil ? 1 : 0
        if startRow <= maxRow {
            for row in startRow...maxRow {
                var rowStr = "|"
                for col in 0...maxCol {
                    let val = grid[row]?[col] ?? ""
                    rowStr += " \(val) |"
                }
                markdown += rowStr + "\n"
            }
        }
        
        return markdown
    }
}
