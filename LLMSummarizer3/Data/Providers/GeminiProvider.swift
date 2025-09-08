import Foundation

final class GeminiProvider: LLMProvider {
    let id: String = "gemini"
    private let model: String
    private let apiKey: String
    private let session: URLSession

    init(model: String, apiKey: String, session: URLSession = .shared) {
        self.model = model
        self.apiKey = apiKey
        self.session = session
    }

    struct RequestBody: Encodable {
        struct Part: Encodable { let text: String }
        struct Content: Encodable { let role: String; let parts: [Part] }
        let contents: [Content]
    }
    struct ResponseBody: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
        struct PromptFeedback: Decodable { let blockReason: String? }
        let promptFeedback: PromptFeedback?
    }

    func summarize(input: LLMInput) async throws -> LLMOutput {
        guard !apiKey.isEmpty else { throw AppError.apiKeyMissing }
        let base = URL(string: "https://generativelanguage.googleapis.com")!
        let endpoint = base.appendingPathComponent("v1/models/\(model):generateContent")
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        let url = comps.url!

        func makeBody(contentText: String) -> RequestBody {
            // プロンプト制御はテキストベースのみ
            // system + user を単一のユーザーメッセージにまとめて送る
            let merged = """
            [SYSTEM]
            \(input.systemPrompt)

            [USER]
            \(input.userPrompt.replacingOccurrences(of: "{content}", with: contentText))
            """
            return RequestBody(contents: [RequestBody.Content(role: "user", parts: [.init(text: merged)])])
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        var payloadText = input.content
        for attempt in 0..<3 {
            let body = makeBody(contentText: payloadText)
            req.httpBody = try encoder.encode(body)
            do {
                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else { throw AppError.network(NSError(domain: "no_http", code: -1)) }
                guard 200..<300 ~= http.statusCode else {
                    let text = String(data: data, encoding: .utf8) ?? ""
                    throw AppError.llmFailed("HTTP \(http.statusCode): \(text)")
                }

                do {
                    let decoded = try decoder.decode(ResponseBody.self, from: data)
                    if let text = decoded.candidates?.first?.content?.parts?.compactMap({ $0.text }).joined(separator: "\n"), !text.isEmpty {
                        return LLMOutput(text: text, tokensInput: nil, tokensOutput: nil)
                    }
                    if let reason = decoded.promptFeedback?.blockReason, !reason.isEmpty {
                        // プロンプトベース制御のみなので、次の試行では本文を短縮して再試行
                        if attempt < 2 && payloadText.count > 16000 { payloadText = String(payloadText.prefix(16000)); continue }
                        throw AppError.llmFailed("blocked: \(reason)")
                    }
                } catch {
                    // Fallback: try JSONSerialization to be resilient to schema changes
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let content = candidates.first?["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        let texts = parts.compactMap { $0["text"] as? String }
                        if !texts.isEmpty { return LLMOutput(text: texts.joined(separator: "\n"), tokensInput: nil, tokensOutput: nil) }
                    }
                    let snippet = String(data: data.prefix(256), encoding: .utf8) ?? ""
                    if attempt < 2 && payloadText.count > 16000 { payloadText = String(payloadText.prefix(16000)); continue }
                    throw AppError.llmFailed("decode_failed: \(error.localizedDescription) snippet=\(snippet)")
                }
                if attempt < 2 && payloadText.count > 16000 { payloadText = String(payloadText.prefix(16000)); continue }
            } catch let err as AppError {
                if attempt < 2 && payloadText.count > 16000 { payloadText = String(payloadText.prefix(16000)); continue }
                throw err
            } catch {
                if attempt < 2 && payloadText.count > 16000 { payloadText = String(payloadText.prefix(16000)); continue }
                throw AppError.llmFailed(error.localizedDescription)
            }
        }
        throw AppError.llmFailed("empty candidates")
    }
}
