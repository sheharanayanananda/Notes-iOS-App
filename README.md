# Slate V2 — The Agentic Notes App

> **Branch:** `v2` &nbsp;|&nbsp; **Platform:** iOS 17+ &nbsp;|&nbsp; **Built with:** Swift & SwiftUI &nbsp;|&nbsp; **LLM Provider:** Ollama

Slate V2 is the next-generation evolution of the Slate note-taking platform. It moves beyond static text editing to deliver a fully autonomous, context-aware AI agent ecosystem — designed to manage, synthesize, and automate your personal knowledge base, all running on-device using a local Ollama AI backend.

> The V1 codebase (document scanning, Scribe voice agent) lives on the `main` branch. This `v2` branch is a ground-up architectural rebuild.

---

## Architecture

Slate V2 follows a clean layered architecture with strict separation of responsibilities:

```
┌──────────────────────────────────────────────────────────────────┐
│  App Layer                                                        │
│  SlateApp.swift       → SwiftData container, notification setup  │
│  ContentView.swift    → Tab router, animated Chat overlay         │
└───────────────────────────────────┬──────────────────────────────┘
                                    │
┌───────────────────────────────────▼──────────────────────────────┐
│  Core Layer                                                       │
│  SlateModel           → @Model note entity (SwiftData)           │
│  OllamaClient         → REST API client (generate / chat / stream)│
│  KeychainHelper       → Secure API key storage (Security.framework)│
└───────┬───────────────────────────┬──────────────────────────────┘
        │                           │
┌───────▼───────────────────────────▼──────────────────────────────┐
│  Features Layer                                                   │
│  Notes/     → Hybrid block editor, sharing, note list            │
│  Chat/      → AI chat, sessions, capsule input, MD renderer      │
│  Settings/  → API key management + live validation               │
└───────────────────────────────────┬──────────────────────────────┘
                                    │
┌───────────────────────────────────▼──────────────────────────────┐
│  Shared Utilities Layer                                           │
│  DocumentParser       → PDF / DOCX / XLSX / RTF text extraction  │
│  MarkdownToRTFConverter → Markdown → RTF for clipboard/share     │
└──────────────────────────────────────────────────────────────────┘
```

### File Tree

```
Slate/
├── App/
│   ├── SlateApp.swift               # Entry point, SwiftData container
│   └── ContentView.swift            # Root tab view + Chat slide-over
├── Core/
│   ├── Models/
│   │   └── SlateModel.swift         # SwiftData note model
│   └── Services/
│       ├── OllamaClient.swift       # Ollama REST API (generate/chat/stream)
│       └── KeychainHelper.swift     # Secure Keychain wrapper
├── Features/
│   ├── Chat/
│   │   ├── Components/
│   │   │   ├── CameraPicker.swift   # Camera + VisionKit document scanner
│   │   │   ├── ChatCapsule.swift    # Physics input bar + attachments
│   │   │   ├── MDFormatter.swift    # Markdown parser + inline renderer
│   │   │   └── MessageView.swift    # Animated block-by-block renderer
│   │   ├── Models/
│   │   │   └── SystemPrompts.swift  # All AI personas + preset configs
│   │   ├── Services/
│   │   │   └── ChatManager.swift    # Session manager, send, persist
│   │   └── Views/
│   │       ├── ChatView.swift       # Primary chat interface
│   │       └── ChatHistoryView.swift# Past sessions browser
│   ├── Notes/
│   │   ├── Components/
│   │   │   ├── NativeTextView.swift # UITextView rich markdown editor
│   │   │   ├── SpecialBlockWrapper.swift # Read-only block selection
│   │   │   └── ShareSheet.swift     # UIActivityViewController wrapper
│   │   ├── Utilities/
│   │   │   ├── NoteBlockUtility.swift  # Markdown ↔ block model split
│   │   │   └── NoteSharingHelper.swift # PDF / RTF / TXT export
│   │   └── Views/
│   │       ├── SlateTabView.swift   # Note list + swipe actions
│   │       └── CreateTabView.swift  # Block editor + AI organizer
│   └── Settings/
│       ├── ViewModels/
│       │   └── SettingsViewModel.swift # @Observable key state + validation
│       └── Views/
│           └── SettingsView.swift   # API key UI
└── Shared/
    └── Utilities/
        ├── DocumentParser.swift     # PDF/DOCX/XLSX/RTF parser, pure-Swift ZIP
        └── MarkdownToRTFConverter.swift # Markdown → base64 RTF
```

---

## Features

### 📝 Notes

- **Hybrid Block Editor** — The editor seamlessly interleaves an editable `NativeTextView` (UITextView-backed) with read-only rendered blocks (`SpecialBlockWrapper`) for code, tables, LaTeX equations, alert callouts, and horizontal rules.
- **Full Markdown Rendering** — Headers (H1–H3), bold, italic, underline, strikethrough, inline code, blockquotes, bullet lists, numbered lists, and interactive checklists all rendered natively inside a `UITextView` using a custom `NSAttributedString` serializer.
- **Interactive Checkboxes** — Custom `NSTextAttachment` subclass renders SF Symbol checkboxes. A `UITapGestureRecognizer` with surgical hit-testing detects taps within the checkbox glyph bounds and toggles state with haptic feedback.
- **Keyboard Accessory Toolbar** — Floating grouped capsule toolbar with Bold, Italic, Underline, Strikethrough, Checklist, Bullet List, Numbered List, Indent/Outdent, and Dismiss Keyboard buttons.
- **AI-Generated Titles** — After saving a note, a background task calls Ollama to generate a concise 3-word title automatically.
- **Note List** — Live SwiftData `@Query` sorted by creation date (newest first) with markdown-aware rich previews. Special blocks shown with emoji icons (💻 code, 📊 table, 🧮 math, 🖼️ image, etc.).
- **Export Formats** — Share any note as adaptive Rich Text (RTF for Messages/Mail, markdown for others), PDF (A4, rendered at 595×842pt), or plain `.txt`.
- **Swipe Actions** — Swipe left to delete; swipe right to share.

### 💬 Slate AI Chat

- **Multi-turn Streaming Chat** — Powered by the Ollama `/api/chat` endpoint with async streaming via `URLSession.bytes` async sequences. Responses are delivered token-by-token in real time.
- **Six Chat Presets** — Each preset configures a unique AI personality, temperature, context window size, and thinking depth:

  | Preset | Focus | Temperature | Context |
  |---|---|---|---|
  | Slate Lite | Quick, lightweight | 0.1 | 4K |
  | Slate Flash | Balanced assistant | 0.3 | 8K |
  | Slate Creative | Brainstorming | 0.8 | 8K |
  | Slate Scholar | Deep research | 0.2 | 32K |
  | Slate Coder | Code & debugging | 0.1 | 16K |
  | Slate Pro | Maximum reasoning | 0.2 | 32K |

- **Animated Block Reveal** — AI responses are parsed into a `MarkdownBlock` tree and revealed block-by-block with a 120ms staggered delay using spring + opacity + slide transitions.
- **Full Markdown + LaTeX Rendering** — Custom single-pass `MarkdownParser` handles all GFM block types (headers, blockquotes, fenced code, tables with alignment, GitHub alert callouts, thematic breaks, task lists, images) plus LaTeX math blocks. Inline rendering supports bold, italic, strikethrough, underline, colored underlines, inline code, auto-linked URLs and emails.
- **LaTeX via MathJax** — Math blocks are rendered in an embedded `WKWebView` loading MathJax 3 from CDN. A `WKScriptMessageHandler` bridge reports rendered height back to SwiftUI to auto-size the view.
- **Thread-safe LRU Markdown Cache** — `MarkdownCache` stores up to 100 parsed block results and 400 inline `Text` renderings, protected by `NSRecursiveLock`, eliminating redundant re-parses during scroll.
- **Diff Syntax Highlighting** — Code blocks detect diff format and colour lines starting with `+` (green) and `-` (red).
- **File & Image Attachments** — Attach up to 10 images from Photos, Camera, or a document scanner. Attach files including PDF (text extraction, visual fallback for scanned PDFs), DOCX, XLSX (rendered as markdown table), RTF, and plain text/CSV/JSON.
- **Physics Input Capsule** — The `ChatCapsule` input bar has rubber-band drag physics: a `DragGesture` applies a 0.5× damped offset with non-uniform `scaleEffect(x:y:)` proportional to drag distance, snapping back with `dampingFraction: 0.55`. Haptics fire on drag start (soft), at 25pt stretch intervals (selection), and on release (rigid).
- **Multi-Session History** — All chat sessions are persisted as JSON in the app's Documents directory. Sessions are auto-titled from the first message. View, switch between, and delete sessions in a dedicated history sheet.
- **Background Generation** — `ChatManager` uses `UIBackgroundTaskIdentifier` to keep generation running when the app is minimized. A local `UNUserNotificationCenter` notification fires when the response is ready.
- **"Add to Slate" Note Extraction** — Any AI response can be converted into a note. A second Ollama call with `SystemPrompts.noteExtractionMessages` extracts a structured title and clean markdown body from the raw chat response.
- **Contextual Error Bubbles** — Network errors are categorised (offline, timeout, auth failure, quota exceeded, server unreachable) and shown with descriptive icons and recovery guidance.

### ⚙️ Settings & Security

- **Keychain-Secured API Key** — The Ollama API key is stored using raw `Security.framework` (`kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlock`). It never touches `UserDefaults`.
- **Live Validation** — `SettingsViewModel` debounces key changes by 800ms, then performs a real network call to validate the key. Status is shown inline: spinner while checking, green checkmark for valid, red with reason for invalid, orange for quota exceeded.
- **Show/Hide Toggle** — Switch between `SecureField` and `TextField` with the eye icon.

---

## Tech Stack

All functionality is implemented using **Apple system frameworks only**. There are zero third-party dependencies.

| Framework | Usage |
|---|---|
| SwiftUI | All UI surfaces |
| SwiftData | Note persistence (`@Model`, `@Query`) |
| UIKit | Rich text editor (`UITextView`), document sharing, PDF rendering |
| WebKit | LaTeX rendering via MathJax in `WKWebView` |
| VisionKit | Multi-page document scanner (`VNDocumentCameraViewController`) |
| PhotosUI | `PhotosPicker` for image attachments |
| PDFKit | PDF text extraction |
| Compression | ZIP Deflate decompression for DOCX/XLSX parsing |
| Security | Keychain API for API key storage |
| UserNotifications | Local push notifications for background AI completion |

> **External runtime dependency:** MathJax 3 is loaded from `cdn.jsdelivr.net` at runtime when LaTeX content is rendered. An internet connection is required for LaTeX display.

---

## Getting Started

### Requirements

- Xcode 16.0 or later
- iOS 17.0 or later
- Ollama Account & API Key (accessible via Ollama Cloud API; no local server setup required)
- Camera & Photo Library permissions (for media attachments)

### Installation

```bash
# Clone the repository
git clone https://github.com/sheharanayanananda/Slate.git
cd Slate

# Switch to the V2 branch
git checkout v2

# Open in Xcode
open Slate.xcodeproj
```

### Configuration

1. Build and run on your device or simulator (`⌘ + R`).
2. Sign in to your Ollama account, navigate to your profile keys section, and create a new API key.
3. Open **Settings** inside the Slate app and input your Ollama API key.
4. The key is validated live and saved securely to the Apple Keychain.

> The app defaults to model `gemma4:31b` from `UserDefaults`. This can be changed programmatically via the `ollama_model_name` key.

---

## Key Implementation Notes

These sections highlight engineering decisions that go beyond standard iOS development.

### Bidirectional Markdown ↔ NSAttributedString Serializer
`NativeTextView` contains a fully custom, bidirectional serializer. `parseToAttributed(text:font:)` converts raw markdown line-by-line into a rich `NSAttributedString` with paragraph styles, custom `NSTextAttachment` checkboxes, and inline span attributes. `serializeToString(attributed:)` reverses this — enumerating every attribute run and reconstructing the original markdown string, including detecting `CheckboxAttachment` subclasses, mapping `firstLineHeadIndent` values back to list types, and re-emitting inline span markers. This avoids any dependency on a third-party rich text library.

### Pure-Swift ZIP Parser
`DocumentParser` contains a hand-rolled `ZIPArchive` struct that reads ZIP-format files (used by both DOCX and XLSX) without any external libraries. It reads the End-of-Central-Directory record, walks the central directory, resolves local file headers, and decompresses Deflate-compressed entries using Apple's `Compression` framework (`COMPRESSION_ZLIB`). XLSX files are then SAX-parsed with `XMLParser` delegates that reconstruct the spreadsheet grid using Excel-style base-26 column reference arithmetic.

### Thread-Safe LRU Markdown Cache
`MDFormatter.MarkdownCache` is a thread-safe in-memory LRU cache protected by `NSRecursiveLock`, storing up to 100 parsed `[MarkdownBlock]` results and 400 inline `Text` renderings keyed by content string. This eliminates redundant re-parsing during `List` scroll recycling, where the same message content would otherwise be re-parsed on every cell dequeue.

### Physics Input Bar
`ChatCapsule` implements rubber-band drag physics entirely within SwiftUI. A `DragGesture` on the background `GeometryReader` tracks horizontal and vertical translation separately. `dragScaleX` and `dragScaleY` are computed from these offsets with independent clamping, producing a non-uniform `scaleEffect` that squishes the capsule horizontally when dragged vertically and vice versa. On release, a spring animation with `dampingFraction: 0.55` returns it to its natural size. Three haptic patterns (soft, selection at 25pt intervals, rigid) give the interaction physical texture.

### MathJax WKWebView Height Bridge
`LaTeXWebViewRepresentable` renders LaTeX inside a `WKWebView` loading MathJax 3 from CDN. After rendering, an injected JavaScript handler calls `window.webkit.messageHandlers.heightHandler.postMessage(document.body.scrollHeight)`. The `WKScriptMessageHandler` receives this and updates a `@Binding<CGFloat>` on the `MainActor`, resizing the SwiftUI frame to exactly match the rendered content — avoiding either fixed heights or scroll-within-scroll issues.

### ChatManager Background Execution
When the user sends a message, `ChatManager.sendMessage` immediately appends an empty assistant placeholder for optimistic UI, then wraps the actual API call in a `Task.detached(priority: .background)` guarded by a `UIBackgroundTaskIdentifier`. This allows streaming to continue for up to 30 seconds after the app enters the background. On completion, a `UNTimeIntervalNotificationTrigger` (1s delay) fires a local notification so the user knows the response is ready.

---

## License

This project is licensed under the **Slate Proprietary Source-Available License**.

You are permitted to view, clone, and inspect this code for personal, educational, and evaluation purposes (including recruiter and employer review). **Commercial use of any kind is strictly prohibited** without a separate written agreement.

See the [LICENSE](LICENSE) file for the full terms.

Copyright © 2026 Thineth Shehara. All rights reserved.
