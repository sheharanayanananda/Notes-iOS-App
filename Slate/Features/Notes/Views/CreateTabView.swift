//
//  CreateTabView.swift
//  Slate
//
//  Live note editor with native formatting toolbar.
//  No edit/preview toggle — formatting is inserted inline as markdown syntax.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Formatting Toolbar

struct FormattingToolbar: UIViewRepresentable {
    @Binding var text: String
    var textView: UITextView?

    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.tintColor = UIColor.systemBlue

        let bold     = toolbarButton(title: "B", image: "bold",           tag: 0, target: context.coordinator)
        let italic   = toolbarButton(title: "I", image: "italic",         tag: 1, target: context.coordinator)
        let bullet   = toolbarButton(title: "•", image: "list.bullet",    tag: 2, target: context.coordinator)
        let numbered = toolbarButton(title: "1.", image: "list.number",   tag: 3, target: context.coordinator)
        let check    = toolbarButton(title: "☑", image: "checkmark.circle", tag: 4, target: context.coordinator)
        let heading  = toolbarButton(title: "H", image: "textformat.size", tag: 5, target: context.coordinator)
        let code     = toolbarButton(title: "</>", image: "curlybraces",  tag: 6, target: context.coordinator)
        let spacer   = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done     = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.dismissKeyboard))

        toolbar.items = [bold, italic, UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil),
                         bullet, numbered, check, heading, code, spacer, done]
        return toolbar
    }

    func updateUIView(_ uiView: UIToolbar, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func toolbarButton(title: String, image: String, tag: Int, target: AnyObject) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: UIImage(systemName: image), style: .plain, target: target, action: #selector(Coordinator.toolbarAction(_:)))
        item.tag = tag
        return item
    }

    class Coordinator: NSObject {
        var parent: FormattingToolbar
        weak var activeTextView: UITextView?

        init(parent: FormattingToolbar) {
            self.parent = parent
        }

        @objc func toolbarAction(_ sender: UIBarButtonItem) {
            guard let tv = activeTextView ?? findActiveTextView() else { return }
            let selectedRange = tv.selectedRange
            let currentText = tv.text ?? ""
            let nsText = currentText as NSString

            let selectedText = nsText.substring(with: selectedRange)
            let hasSelection = selectedRange.length > 0

            var insertion = ""
            var cursorOffset = 0

            switch sender.tag {
            case 0: // Bold
                if hasSelection {
                    insertion = "**\(selectedText)**"
                    cursorOffset = insertion.count
                } else {
                    insertion = "****"
                    cursorOffset = 2
                }
            case 1: // Italic
                if hasSelection {
                    insertion = "_\(selectedText)_"
                    cursorOffset = insertion.count
                } else {
                    insertion = "__"
                    cursorOffset = 1
                }
            case 2: // Bullet
                let prefix = isAtLineStart(tv: tv) ? "- " : "\n- "
                insertion = hasSelection ? prefix + selectedText : prefix
                cursorOffset = insertion.count
            case 3: // Numbered
                let prefix = isAtLineStart(tv: tv) ? "1. " : "\n1. "
                insertion = hasSelection ? prefix + selectedText : prefix
                cursorOffset = insertion.count
            case 4: // Checklist
                let prefix = isAtLineStart(tv: tv) ? "- [ ] " : "\n- [ ] "
                insertion = hasSelection ? prefix + selectedText : prefix
                cursorOffset = insertion.count
            case 5: // Heading
                let prefix = isAtLineStart(tv: tv) ? "## " : "\n## "
                insertion = hasSelection ? prefix + selectedText : prefix
                cursorOffset = insertion.count
            case 6: // Code
                if hasSelection && selectedText.contains("\n") {
                    insertion = "```\n\(selectedText)\n```"
                    cursorOffset = insertion.count
                } else if hasSelection {
                    insertion = "`\(selectedText)`"
                    cursorOffset = insertion.count
                } else {
                    insertion = "``"
                    cursorOffset = 1
                }
            default:
                break
            }

            let newText = nsText.replacingCharacters(in: selectedRange, with: insertion)
            tv.text = newText
            parent.text = newText

            // Restore cursor
            let newCursorPos = selectedRange.location + cursorOffset
            if let newPos = tv.position(from: tv.beginningOfDocument, offset: newCursorPos) {
                tv.selectedTextRange = tv.textRange(from: newPos, to: newPos)
            }
        }

        @objc func dismissKeyboard() {
            activeTextView?.resignFirstResponder()
        }

        private func isAtLineStart(tv: UITextView) -> Bool {
            let cursorPos = tv.selectedRange.location
            if cursorPos == 0 { return true }
            let prevChar = (tv.text as NSString).substring(with: NSRange(location: cursorPos - 1, length: 1))
            return prevChar == "\n"
        }

        private func findActiveTextView() -> UITextView? {
            let activeWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            return activeWindow?.rootViewController?.view.findFirstResponder() as? UITextView
        }
    }
}

private extension UIView {
    func findFirstResponder() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let found = subview.findFirstResponder() { return found }
        }
        return nil
    }
}

// MARK: - Native Editor Representable

struct SlateTextEditorView: UIViewRepresentable {
    @Binding var text: String
    var toolbarCoordinator: FormattingToolbar.Coordinator?

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 120, right: 16)
        tv.textColor = UIColor.label
        tv.allowsEditingTextAttributes = false
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences

        // Attach the formatting toolbar
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.tintColor = UIColor.systemBlue
        toolbar.items = buildToolbarItems(coordinator: context.coordinator)
        tv.inputAccessoryView = toolbar

        context.coordinator.textView = tv
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func buildToolbarItems(coordinator: Coordinator) -> [UIBarButtonItem] {
        func btn(_ image: String, tag: Int) -> UIBarButtonItem {
            let item = UIBarButtonItem(image: UIImage(systemName: image), style: .plain,
                                      target: coordinator, action: #selector(Coordinator.format(_:)))
            item.tag = tag
            return item
        }
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done   = UIBarButtonItem(barButtonSystemItem: .done, target: coordinator, action: #selector(Coordinator.done))
        return [
            btn("bold", tag: 0),
            btn("italic", tag: 1),
            btn("list.bullet", tag: 2),
            btn("list.number", tag: 3),
            btn("checkmark.circle", tag: 4),
            btn("textformat.size", tag: 5),
            btn("curlybraces", tag: 6),
            spacer,
            done
        ]
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SlateTextEditorView
        weak var textView: UITextView?

        init(parent: SlateTextEditorView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        @objc func done() {
            textView?.resignFirstResponder()
        }

        @objc func format(_ sender: UIBarButtonItem) {
            guard let tv = textView else { return }
            let selectedRange = tv.selectedRange
            let nsText = tv.text as NSString
            let selectedText = nsText.substring(with: selectedRange)
            let hasSelection = selectedRange.length > 0

            var insertion = ""
            var cursorOffset = 0

            switch sender.tag {
            case 0: // Bold
                insertion = hasSelection ? "**\(selectedText)**" : "****"
                cursorOffset = hasSelection ? insertion.count : 2
            case 1: // Italic
                insertion = hasSelection ? "_\(selectedText)_" : "__"
                cursorOffset = hasSelection ? insertion.count : 1
            case 2: // Bullet
                let prefix = atLineStart(tv: tv) ? "- " : "\n- "
                insertion = prefix + (hasSelection ? selectedText : "")
                cursorOffset = insertion.count
            case 3: // Numbered
                let prefix = atLineStart(tv: tv) ? "1. " : "\n1. "
                insertion = prefix + (hasSelection ? selectedText : "")
                cursorOffset = insertion.count
            case 4: // Checklist
                let prefix = atLineStart(tv: tv) ? "- [ ] " : "\n- [ ] "
                insertion = prefix + (hasSelection ? selectedText : "")
                cursorOffset = insertion.count
            case 5: // Heading (H2)
                let prefix = atLineStart(tv: tv) ? "## " : "\n## "
                insertion = prefix + (hasSelection ? selectedText : "")
                cursorOffset = insertion.count
            case 6: // Code
                if hasSelection && selectedText.contains("\n") {
                    insertion = "```\n\(selectedText)\n```"
                } else if hasSelection {
                    insertion = "`\(selectedText)`"
                } else {
                    insertion = "``"
                    cursorOffset = 1
                }
                if cursorOffset == 0 { cursorOffset = insertion.count }
            default: break
            }

            let newText = nsText.replacingCharacters(in: selectedRange, with: insertion)
            tv.text = newText
            parent.text = newText

            let newCursorPos = selectedRange.location + cursorOffset
            if let pos = tv.position(from: tv.beginningOfDocument, offset: min(newCursorPos, newText.count)),
               let range = tv.textRange(from: pos, to: pos) {
                tv.selectedTextRange = range
            }
        }

        private func atLineStart(tv: UITextView) -> Bool {
            let loc = tv.selectedRange.location
            guard loc > 0 else { return true }
            return (tv.text as NSString).substring(with: NSRange(location: loc - 1, length: 1)) == "\n"
        }
    }
}

// MARK: - Create Tab View

struct CreateTabView: View {
    @State private var text: String = ""

    @Binding var editingNote: SlateModel?
    @Binding var activeTab: ContentView.TabIdentifier

    @Environment(\.modelContext) private var context
    @State private var showEmptyWarning: Bool = false
    @State private var isOrganizing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var wasTitlePreGenerated: Bool = false

    var body: some View {
        SlateTextEditorView(text: $text)
            .onAppear { loadNote(editingNote) }
            .onChange(of: editingNote) { _, newValue in loadNote(newValue) }
            .navigationTitle(navTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { cancel() }
                        .disabled(isOrganizing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isOrganizing {
                        ProgressView()
                    } else {
                        Button("Save", systemImage: "checkmark", role: .confirm) { saveNote() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("Empty Note", isPresented: $showEmptyWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Can't save an empty note.")
            }
            .alert("Organizer Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
    }

    private var navTitle: String {
        if editingNote == nil || editingNote?.modelContext == nil { return "New Note" }
        let t = editingNote?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Edit Note" : t
    }
}

// MARK: - Main Functions

extension CreateTabView {
    private func saveNote() {
        let trimmedDesc = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDesc.isEmpty { showEmptyWarning = true; return }

        let targetNote: SlateModel
        let initialTitle = generateInitialTitle(from: trimmedDesc)

        if let note = editingNote {
            note.desc = trimmedDesc
            if note.title.isEmpty { note.title = initialTitle }
            targetNote = note
            if targetNote.modelContext == nil { context.insert(targetNote) }
        } else {
            targetNote = SlateModel(title: initialTitle, desc: trimmedDesc)
            context.insert(targetNote)
        }

        if !wasTitlePreGenerated {
            Task { await generateTitleInBackground(for: targetNote, content: trimmedDesc) }
        }

        reset()
        activeTab = .notes
    }

    private func cancel() {
        reset()
        activeTab = .notes
    }
}

// MARK: - Supporting Functions

extension CreateTabView {
    private func reset() {
        text = ""
        editingNote = nil
    }

    private func loadNote(_ note: SlateModel?) {
        if let note = note {
            text = note.desc
            wasTitlePreGenerated = !note.title.isEmpty && note.title != "New Note"
        } else {
            text = ""
            wasTitlePreGenerated = false
        }
    }

    private func generateInitialTitle(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
        let words = cleaned.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let firstThree = words.prefix(3).joined(separator: " ")
        return firstThree.isEmpty ? "New Note" : firstThree
    }

    private func generateTitleInBackground(for note: SlateModel, content: String) async {
        do {
            let client = OllamaClient()
            let title = try await client.generate(prompt: content, system: SystemPrompts.titleGeneration)
            let trimmedTitle = title.replacingOccurrences(of: "\r", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                await MainActor.run { note.title = trimmedTitle }
            }
        } catch {
            print("Failed to generate title: \(error.localizedDescription)")
        }
    }
}
