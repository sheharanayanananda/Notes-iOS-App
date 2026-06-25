//
//  OllamaClient.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-28.
//

import Foundation
import UIKit

struct OllamaGenerateResponse: Decodable {
    let response: String
}

struct OllamaDocumentAttachment: Codable, Equatable, Hashable, Identifiable {
    var id = UUID()
    let name: String
    let contentText: String
    
    enum CodingKeys: String, CodingKey {
        case name, contentText
    }
    
    init(id: UUID = UUID(), name: String, contentText: String) {
        self.id = id
        self.name = name
        self.contentText = contentText
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.contentText = try container.decode(String.self, forKey: .contentText)
        self.id = UUID()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(contentText, forKey: .contentText)
    }
}

struct OllamaChatMessage: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    let role: String      // "user", "assistant", "system"
    let content: String
    var images: [String]? // Base64 encoded JPEG representations
    var documents: [OllamaDocumentAttachment]?
    
    enum CodingKeys: String, CodingKey {
        case role, content, images, documents
    }
    
    init(id: String = UUID().uuidString, role: String, content: String, images: [String]? = nil, documents: [OllamaDocumentAttachment]? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.images = images
        self.documents = documents
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
        self.images = try container.decodeIfPresent([String].self, forKey: .images)
        self.documents = try container.decodeIfPresent([OllamaDocumentAttachment].self, forKey: .documents)
        self.id = UUID().uuidString
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(documents, forKey: .documents)
    }
}

struct OllamaChatResponse: Decodable {
    let message: OllamaChatMessage
}

struct OllamaChatStreamChunk: Decodable {
    let message: OllamaChatStreamMessageChunk?
    let done: Bool?
}

struct OllamaChatStreamMessageChunk: Decodable {
    let role: String?
    let content: String?
}

enum OllamaError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API Key is missing. Please go to Settings to configure it."
        case .invalidResponse:
            return "Invalid response from the server."
        case .apiError(let message):
            return message
        }
    }
}

final class OllamaClient {
    private let modelName: String
    private let apiKey: String?
    private let baseURL: URL

    init(
        modelName: String? = nil,
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://ollama.com")!
    ) {
        self.modelName = modelName ?? UserDefaults.standard.string(forKey: "ollama_model_name") ?? "gemma4:31b"
        self.apiKey = apiKey ?? KeychainHelper.shared.readApiKey()
        self.baseURL = baseURL
    }

    func generate(prompt: String, system: String? = nil, image: UIImage? = nil) async throws -> String {
        guard let resolvedKey = apiKey, !resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.missingAPIKey
        }
        
        let url = URL(string: "/api/generate", relativeTo: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(resolvedKey)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.2,
                "top_p": 0.9,
                "num_predict": 1024
            ]
        ]
        
        if let image = image, let jpegData = image.jpegData(compressionQuality: 0.75) {
            body["images"] = [jpegData.base64EncodedString()]
            body["thinking"] = "low"
        }
        
        if let system = system {
            body["system"] = system
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw OllamaError.apiError("Unauthorized: The API Key is incorrect or inactive.")
            } else if httpResponse.statusCode == 429 {
                throw OllamaError.apiError("Usage Limit Exceeded: You have reached your weekly usage limit.")
            } else if httpResponse.statusCode != 200 {
                if let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errMsg = errObj["error"] as? String {
                    throw OllamaError.apiError(errMsg)
                }
                throw OllamaError.apiError("API Error: HTTP Status \(httpResponse.statusCode)")
            }
        }
        
        do {
            return try JSONDecoder().decode(OllamaGenerateResponse.self, from: data).response
        } catch {
            throw OllamaError.invalidResponse
        }
    }
    
    func chat(
        messages: [OllamaChatMessage],
        reasoningLevel: String? = nil,
        creativity: Double? = nil,
        memorySize: Int? = nil
    ) async throws -> OllamaChatMessage {
        guard let resolvedKey = apiKey, !resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.missingAPIKey
        }
        
        let url = URL(string: "/api/chat", relativeTo: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(resolvedKey)", forHTTPHeaderField: "Authorization")
        
        var options: [String: Any] = [
            "num_predict": 1024
        ]
        if let creativity = creativity {
            options["temperature"] = creativity
        }
        if let memorySize = memorySize {
            options["num_ctx"] = memorySize
        }
        
        var body: [String: Any] = [
            "model": modelName,
            "messages": messages.map { msg in
                var dict: [String: Any] = ["role": msg.role, "content": msg.content]
                if let images = msg.images {
                    dict["images"] = images
                }
                return dict
            },
            "stream": false,
            "options": options
        ]
        
        if let reasoningLevel = reasoningLevel, reasoningLevel.lowercased() != "off" {
            body["thinking"] = reasoningLevel.lowercased()
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw OllamaError.apiError("Unauthorized: The API Key is incorrect or inactive.")
            } else if httpResponse.statusCode == 429 {
                throw OllamaError.apiError("Usage Limit Exceeded: You have reached your weekly usage limit.")
            } else if httpResponse.statusCode != 200 {
                if let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errMsg = errObj["error"] as? String {
                    throw OllamaError.apiError(errMsg)
                }
                throw OllamaError.apiError("API Error: HTTP Status \(httpResponse.statusCode)")
            }
        }
        
        do {
            let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            return chatResponse.message
        } catch {
            throw OllamaError.invalidResponse
        }
    }
    
    func chatStream(
        messages: [OllamaChatMessage],
        reasoningLevel: String? = nil,
        creativity: Double? = nil,
        memorySize: Int? = nil,
        onChunkReceived: @escaping (String) -> Void
    ) async throws -> OllamaChatMessage {
        guard let resolvedKey = apiKey, !resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.missingAPIKey
        }
        
        let url = URL(string: "/api/chat", relativeTo: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(resolvedKey)", forHTTPHeaderField: "Authorization")
        
        var options: [String: Any] = [
            "num_predict": 1024
        ]
        if let creativity = creativity {
            options["temperature"] = creativity
        }
        if let memorySize = memorySize {
            options["num_ctx"] = memorySize
        }
        
        var body: [String: Any] = [
            "model": modelName,
            "messages": messages.map { msg in
                var dict: [String: Any] = ["role": msg.role, "content": msg.content]
                if let images = msg.images {
                    dict["images"] = images
                }
                return dict
            },
            "stream": true,
            "options": options
        ]
        
        if let reasoningLevel = reasoningLevel, reasoningLevel.lowercased() != "off" {
            body["thinking"] = reasoningLevel.lowercased()
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw OllamaError.apiError("Unauthorized: The API Key is incorrect or inactive.")
            } else if httpResponse.statusCode == 429 {
                throw OllamaError.apiError("Usage Limit Exceeded: You have reached your weekly usage limit.")
            } else if httpResponse.statusCode != 200 {
                throw OllamaError.apiError("API Error: HTTP Status \(httpResponse.statusCode)")
            }
        }
        
        var fullContent = ""
        
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8) else { continue }
            
            if let chunk = try? JSONDecoder().decode(OllamaChatStreamChunk.self, from: data) {
                if let content = chunk.message?.content {
                    fullContent += content
                    onChunkReceived(content)
                }
            }
        }
        
        return OllamaChatMessage(role: "assistant", content: fullContent)
    }
}
