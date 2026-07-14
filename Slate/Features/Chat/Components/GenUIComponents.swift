//
//  GenUIComponents.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI

// MARK: - GenUI Main Parser & Wrapper View

struct GenUIComponentView: View {
    let payload: String
    let messageID: String
    @Binding var genuiState: String?
    
    var body: some View {
        if let data = payload.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            
            VStack(alignment: .leading, spacing: 14) {
                // Render header if title is present
                if let title = json["title"] as? String {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.accentColor)
                        
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 4)
                }
                
                switch type {
                case "checklist", "shopping_list", "todo_list":
                    GenUIChecklistComponent(json: json, genuiState: $genuiState)
                case "form":
                    GenUIFormComponent(json: json, messageID: messageID, genuiState: $genuiState)
                case "quick_actions", "option_grid":
                    GenUIQuickActionsComponent(json: json, genuiState: $genuiState)
                default:
                    Text("Unsupported GenUI view: \(type)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground).opacity(0.65))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.vertical, 8)
        } else {
            // Fallback: render raw code block if JSON parsing fails
            VStack(alignment: .leading, spacing: 8) {
                Text("GenUI Block (Parsing error)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Text(payload)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - 1. Interactive Checklist Component

struct GenUIChecklistComponent: View {
    let json: [String: Any]
    @Binding var genuiState: String?
    
    struct ChecklistItem: Identifiable, Codable {
        let id: String
        let name: String
        var checked: Bool
    }
    
    @State private var items: [ChecklistItem] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                Button(action: {
                    toggleItem(item.id)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(item.checked ? .accentColor : .secondary.opacity(0.6))
                            .contentTransition(.symbolEffect(.replace))
                        
                        Text(item.name)
                            .font(.system(size: 15, weight: item.checked ? .regular : .medium))
                            .foregroundColor(item.checked ? .secondary : .primary)
                            .strikethrough(item.checked)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(item.checked ? Color.primary.opacity(0.02) : Color.primary.opacity(0.04))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .onAppear {
            loadItems()
        }
        .onChange(of: genuiState) {
            loadItems()
        }
    }
    
    private func loadItems() {
        // First try to load from persistent genuiState
        if let stateData = genuiState?.data(using: .utf8),
           let decodedItems = try? JSONDecoder().decode([ChecklistItem].self, from: stateData) {
            self.items = decodedItems
            return
        }
        
        // Fallback: parse initial state from AI response payload
        if let rawItems = json["items"] as? [[String: Any]] {
            self.items = rawItems.compactMap { dict in
                let id = (dict["id"] as? String) ?? UUID().uuidString
                guard let name = dict["name"] as? String else { return nil }
                let checked = (dict["checked"] as? Bool) ?? false
                return ChecklistItem(id: id, name: name, checked: checked)
            }
        }
    }
    
    private func toggleItem(_ id: String) {
        HapticManager.trigger(.light)
        
        if let index = items.firstIndex(where: { $0.id == id }) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                items[index].checked.toggle()
            }
            
            // Save state back to bindings
            if let encoded = try? JSONEncoder().encode(items),
               let stateString = String(data: encoded, encoding: .utf8) {
                self.genuiState = stateString
                
                // Save ChatManager state
                DispatchQueue.main.async {
                    ChatManager.shared.saveCurrentState()
                }
            }
        }
    }
}

// MARK: - 2. Dynamic Form Component

struct GenUIFormComponent: View {
    let json: [String: Any]
    let messageID: String
    @Binding var genuiState: String?
    
    struct FormField: Identifiable, Codable {
        let id: String
        let label: String
        let placeholder: String?
        var value: String
    }
    
    @State private var fields: [FormField] = []
    @State private var isSubmitted: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isSubmitted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Form Submitted Successfully")
                            .font(.system(size: 15, weight: .bold))
                        Text("Your responses were saved.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)
            } else {
                ForEach($fields) { $field in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(field.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField(field.placeholder ?? "", text: $field.value)
                            .font(.system(size: 15))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .onChange(of: field.value) {
                                saveState()
                            }
                    }
                }
                
                Button(action: submitForm) {
                    HStack {
                        Spacer()
                        Text((json["buttonText"] as? String) ?? "Submit")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(fields.contains(where: { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
                .opacity(fields.contains(where: { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ? 0.6 : 1.0)
            }
        }
        .onAppear {
            loadForm()
        }
    }
    
    private func loadForm() {
        if let stateData = genuiState?.data(using: .utf8) {
            // Check if submitted already
            if let submission = try? JSONSerialization.jsonObject(with: stateData) as? [String: Any],
               let submitted = submission["isSubmitted"] as? Bool {
                self.isSubmitted = submitted
                if let rawFields = submission["fields"] as? [[String: Any]] {
                    self.fields = rawFields.compactMap { dict in
                        let id = (dict["id"] as? String) ?? ""
                        let label = (dict["label"] as? String) ?? ""
                        let value = (dict["value"] as? String) ?? ""
                        return FormField(id: id, label: label, placeholder: nil, value: value)
                    }
                }
                return
            }
        }
        
        // Initial setup from JSON
        if let rawFields = json["fields"] as? [[String: Any]] {
            self.fields = rawFields.compactMap { dict in
                guard let id = dict["id"] as? String,
                      let label = dict["label"] as? String else { return nil }
                let placeholder = dict["placeholder"] as? String
                let value = (dict["value"] as? String) ?? ""
                return FormField(id: id, label: label, placeholder: placeholder, value: value)
            }
        }
    }
    
    private func saveState() {
        let fieldList = fields.map { ["id": $0.id, "label": $0.label, "value": $0.value] }
        let stateObj: [String: Any] = [
            "isSubmitted": isSubmitted,
            "fields": fieldList
        ]
        
        if let stateData = try? JSONSerialization.data(withJSONObject: stateObj, options: []),
           let stateString = String(data: stateData, encoding: .utf8) {
            self.genuiState = stateString
            
            // Save ChatManager state
            DispatchQueue.main.async {
                ChatManager.shared.saveCurrentState()
            }
        }
    }
    
    private func submitForm() {
        HapticManager.trigger(.medium)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSubmitted = true
        }
        saveState()
        
        // Send a response text back to the assistant automatically
        let summary = fields.map { "\($0.label): \($0.value)" }.joined(separator: ", ")
        let submitMessage = "Submitted form: \(summary)"
        
        DispatchQueue.main.async {
            ChatManager.shared.sendMessage(chatText: submitMessage, selectedImages: [], selectedDocuments: [])
        }
    }
}

// MARK: - 3. Quick Actions Component

struct GenUIQuickActionsComponent: View {
    let json: [String: Any]
    @Binding var genuiState: String?
    
    struct ActionItem: Identifiable {
        let id = UUID()
        let label: String
        let action: String
    }
    
    @State private var actions: [ActionItem] = []
    @State private var selectedActionID: UUID? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { item in
                    Button(action: {
                        triggerAction(item)
                    }) {
                        Text(item.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedActionID == item.id ? .white : .accentColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(selectedActionID == item.id ? Color.accentColor : Color.accentColor.opacity(0.12))
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(selectedActionID != nil)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .onAppear {
            loadActions()
        }
    }
    
    private func loadActions() {
        if let stateData = genuiState?.data(using: .utf8),
           let selectedIDString = String(data: stateData, encoding: .utf8),
           let uuid = UUID(uuidString: selectedIDString) {
            self.selectedActionID = uuid
        }
        
        if let rawActions = json["actions"] as? [[String: Any]] {
            self.actions = rawActions.compactMap { dict in
                guard let label = dict["label"] as? String,
                      let action = dict["action"] as? String else { return nil }
                return ActionItem(label: label, action: action)
            }
        }
    }
    
    private func triggerAction(_ actionItem: ActionItem) {
        HapticManager.trigger(.medium)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            selectedActionID = actionItem.id
        }
        
        self.genuiState = actionItem.id.uuidString
        
        DispatchQueue.main.async {
            ChatManager.shared.saveCurrentState()
            
            // Send the prompt to the Ollama client
            ChatManager.shared.sendMessage(chatText: actionItem.action, selectedImages: [], selectedDocuments: [])
        }
    }
}
