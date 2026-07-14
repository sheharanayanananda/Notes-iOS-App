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

    nonisolated init(
        modelName: String? = nil,
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://ollama.com")!
    ) {
        self.modelName = modelName ?? UserDefaults.standard.string(forKey: "ollama_model_name") ?? "gemma4:31b"
        self.apiKey = apiKey ?? KeychainHelper.shared.readApiKey()
        self.baseURL = baseURL
    }

    func generate(prompt: String, system: String? = nil, image: UIImage? = nil, reasoningLevel: String = "low") async throws -> String {
        var body: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.2,
                "top_p": 0.9
            ]
        ]
        
        if let image = image, let jpegData = image.jpegData(compressionQuality: 0.75) {
            body["images"] = [jpegData.base64EncodedString()]
        }
        
        if reasoningLevel.lowercased() != "off" {
            body["thinking"] = reasoningLevel.lowercased()
        }
        
        if let system = system {
            body["system"] = system
        }
        
        let request = try buildRequest(endpoint: "/api/generate", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        
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
        let body = buildChatBody(
            messages: messages,
            reasoningLevel: reasoningLevel,
            creativity: creativity,
            memorySize: memorySize,
            stream: false
        )
        
        let request = try buildRequest(endpoint: "/api/chat", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        
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
        let body = buildChatBody(
            messages: messages,
            reasoningLevel: reasoningLevel,
            creativity: creativity,
            memorySize: memorySize,
            stream: true
        )
        
        let request = try buildRequest(endpoint: "/api/chat", body: body)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try validateResponse(response, data: nil)
        
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
    
    // MARK: - Private Helpers
    
    private func buildRequest(endpoint: String, body: [String: Any]) throws -> URLRequest {
        guard let resolvedKey = apiKey, !resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.missingAPIKey
        }
        
        let url = URL(string: endpoint, relativeTo: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(resolvedKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    private func validateResponse(_ response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        if httpResponse.statusCode == 401 {
            throw OllamaError.apiError("Unauthorized: The API Key is incorrect or inactive.")
        } else if httpResponse.statusCode == 429 {
            throw OllamaError.apiError("Usage Limit Exceeded: You have reached your weekly usage limit.")
        } else if httpResponse.statusCode != 200 {
            if let data = data,
               let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errMsg = errObj["error"] as? String {
                throw OllamaError.apiError(errMsg)
            }
            throw OllamaError.apiError("API Error: HTTP Status \(httpResponse.statusCode)")
        }
    }
    
    private func buildChatBody(
        messages: [OllamaChatMessage],
        reasoningLevel: String?,
        creativity: Double?,
        memorySize: Int?,
        stream: Bool
    ) -> [String: Any] {
        var options: [String: Any] = [:]
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
            "stream": stream,
            "options": options
        ]
        
        if let reasoningLevel = reasoningLevel, reasoningLevel.lowercased() != "off" {
            body["thinking"] = reasoningLevel.lowercased()
        }
        
        return body
    }
}
