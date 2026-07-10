# Slate V2: The Agentic Notes App

Slate V2 is the next-generation, commercial iteration of the Slate note-taking platform for iOS. Built with Swift and SwiftUI, V2 moves beyond static text editing to deliver a fully autonomous, context-aware AI agent ecosystem designed to manage, synthesize, and automate a user's personal knowledge base.

The V2 codebase resides in the `v2` branch of this repository, while the V1 version remains available on the `main` branch.

---

## The Agentic Vision
At the core of Slate V2 is the transition from a passive note-taking tool to an active **AI Agent**. The application is structured around a centralized workspace where the agent understands context, processes documents, and assists the user through advanced LLM reasoning.

### 1. The Centralized Chat Command Center
The chat interface (`ChatView`) is the primary control deck of Slate V2. Through conversational prompts, the user can interact with the agent, process attachments, and get contextual summaries. Powered by `ChatManager`, generation processes run asynchronously and continue even if the app enters the background, alerting users via notifications when done.

### 2. Multi-Model Presets
- **Preset Behaviors**: Switch system instructions, temperatures, and context sizes instantly:
  - **Balanced Assistant**: Standard note-taking and reasoning.
  - **Deep Reasoning**: Max context for analyzing complex threads or multi-page documents.
  - **Creative Drafts**: High creativity for brain-storming.
  - **Quick Fixes**: Snappy, low-overhead responses.
- **Visual indicators**: Cascading vertical wave bounce typing indicator (Loading Wave) and sequential fade-in paragraph transitions.

### 3. Rich Document & Media Attachments
Users can attach multiple file types directly to the Chat Command Center using the floating capsule:
- **Images & Photos**: Attached from the library or captured live via a custom `CameraPicker`.
- **Documents**: Local parsing of PDF, Word (DOCX), RTF, and plain text files from ZIP archives, automatically parsed by a high-efficiency `DocumentParser`.

### 4. Interactive Physics-Based Input Capsule
- **Liquid Glass Chat Capsule**: A floating input bar featuring dynamic horizontal/vertical stretching animations and rubber-band spring physics on drag offsets.
- **Drag & Gesture Interactions**: Full support for responsive drag gestures, interactive haptic feedback patterns (soft on drag start, continuous selection haptics on stretching, rigid feedback on release), and full-body capsule focus.

### 5. High-Fidelity Markdown & LaTeX Formatting
- **Advanced Math Rendering**: Support for inline and block equations, integrations, matrices, and custom algebraic/quantum symbols using cached web layouts and MathJax.
- **Optimized Layout Rendering**: Thread-safe dictionary caching for structural blocks and statically compiled regex styling for smooth 60 FPS scrolling.

---

## Codebase Structure

Slate V2 uses a unified, modular architecture to separate App UI, persistence models, services, and utilities:

```text
├── Slate/
│   ├── App/             # App lifecycle (SlateApp.swift, ContentView.swift)
│   ├── Models/          # SwiftData models (SlateModel.swift, SystemPrompts.swift)
│   ├── Services/        # Ollama client and Keychain storage wrappers
│   ├── Utilities/       # DocumentParser, ChatManager, RTF and sharing helpers
│   └── Views/           # SwiftUI View hierarchy
│       ├── Chat/        # Chat workspace, ChatCapsule, CameraPicker, and Markdown/LaTeX formatting
│       ├── Notes/       # Note editor, native text view canvas, blocks, and note lists
│       └── Settings/    # API configuration panel and settings view model
```

---

## Requirements

- Xcode 15.0 or later
- iOS 17.0 or later
- Camera & Photo Library permissions (for media attachments)
- Ollama API connection

---

## Getting Started

1. **Clone the Repository and Switch to V2**:
   ```bash
   git clone https://github.com/sheharanayanananda/Slate.git
   cd Slate
   git checkout v2
   ```

2. **Open the Project**:
   Open `Slate.xcodeproj` in Xcode.

3. **Secure API Configuration**:
   Input your selected model API key in the app Settings screen. Keys are encrypted and stored in the secure Apple Keychain.

4. **Build and Run**:
   Press `⌘ + R` to build and run on your target iOS device or simulator.

---

## License

This project is licensed under the **Slate Proprietary and Source-Available License**. See the [LICENSE](LICENSE) file for the full license text permitting personal, educational, and evaluation use (such as recruiter inspections) while prohibiting unauthorized commercial redistribution.

