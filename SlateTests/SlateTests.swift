import Testing
import UIKit
@testable import Slate

struct SlateTests {

    @Test func testBasicIndentationParsing() throws {
        let font = UIFont.systemFont(ofSize: 16)
        
        // No indent
        let attr1 = NativeTextView.parseToAttributed(text: "Hello", font: font)
        let style1 = attr1.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style1?.firstLineHeadIndent == 0)
        #expect(style1?.headIndent == 0)
        
        // 1 level indent (2 spaces)
        let attr2 = NativeTextView.parseToAttributed(text: "  Hello", font: font)
        let style2 = attr2.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style2?.firstLineHeadIndent == 24)
        #expect(style2?.headIndent == 24)
        
        // 2 levels indent (4 spaces)
        let attr3 = NativeTextView.parseToAttributed(text: "    Hello", font: font)
        let style3 = attr3.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style3?.firstLineHeadIndent == 48)
        #expect(style3?.headIndent == 48)
    }

    @Test func testListIndentationParsing() throws {
        let font = UIFont.systemFont(ofSize: 16)
        
        // Indented checklist
        let attrCheck = NativeTextView.parseToAttributed(text: "  - [ ] Task", font: font)
        let styleCheck = attrCheck.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(styleCheck?.firstLineHeadIndent == 24)
        #expect(styleCheck?.headIndent == 56) // 24 + 32
        
        // Indented bullet
        let attrBullet = NativeTextView.parseToAttributed(text: "    - Bullet", font: font)
        let styleBullet = attrBullet.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(styleBullet?.firstLineHeadIndent == 48)
        #expect(styleBullet?.headIndent == 64) // 48 + 16
        
        // Indented number
        let attrNum = NativeTextView.parseToAttributed(text: "  1. Number", font: font)
        let styleNum = attrNum.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(styleNum?.firstLineHeadIndent == 24)
        #expect(styleNum?.headIndent == 44) // 24 + 20
    }

    @Test func testSerializerRoundtrip() throws {
        let font = UIFont.systemFont(ofSize: 16)
        
        let cases = [
            "Hello",
            "  Hello",
            "    Hello",
            "- [ ] Task",
            "  - [ ] Task",
            "    - [ ] Task",
            "- [x] Done",
            "  - [x] Done",
            "- Bullet",
            "  - Bullet",
            "1. One",
            "  2. Two",
            "**Bold**",
            "*Italic*",
            "<u>Underline</u>",
            "~~Strikethrough~~",
            "  **Bold** and *Italic* with <u>Underline</u> and ~~Strikethrough~~"
        ]
        
        for testCase in cases {
            let attr = NativeTextView.parseToAttributed(text: testCase, font: font)
            let serialized = NativeTextView.serializeToString(attributed: attr)
            #expect(serialized == testCase, "Failed for case: '\(testCase)' (got '\(serialized)')")
        }
    }

    @Test func testMarkdownHeaders() throws {
        let text = "# Header 1\n## Header 2\n### Header 3\n#NotHeader"
        let blocks = MarkdownParser.parse(text)
        
        #expect(blocks.count == 4)
        
        if case .header(let level, let content) = blocks[0] {
            #expect(level == 1)
            #expect(content == "Header 1")
        } else {
            #expect(Bool(false), "Expected Header 1 block")
        }
        
        if case .header(let level, let content) = blocks[1] {
            #expect(level == 2)
            #expect(content == "Header 2")
        } else {
            #expect(Bool(false), "Expected Header 2 block")
        }
        
        if case .paragraph(let content) = blocks[3] {
            #expect(content == "#NotHeader")
        } else {
            #expect(Bool(false), "Expected paragraph for #NotHeader")
        }
    }
}

