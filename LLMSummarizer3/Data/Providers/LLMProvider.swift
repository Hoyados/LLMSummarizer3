import Foundation

protocol LLMProvider {
    var id: String { get }
    func summarize(input: LLMInput) async throws -> LLMOutput
}

struct LLMInput: Sendable, Equatable {
    let systemPrompt: String
    let userPrompt: String
    let content: String
    let maxTokens: Int?
    let temperature: Double?
    let stream: Bool
}

struct LLMOutput: Sendable, Equatable {
    let text: String
    let tokensInput: Int?
    let tokensOutput: Int?
}

