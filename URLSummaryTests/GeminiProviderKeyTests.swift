import XCTest
@testable import LLMSummarizer3

final class GeminiProviderKeyTests: XCTestCase {
    func test_missing_api_key_throws() async {
        let provider = GeminiProvider(model: "gemini-2.5-flash", apiKey: "")
        let input = LLMInput(systemPrompt: "s", userPrompt: "u", content: "Hello", maxTokens: 10, temperature: 0.1, stream: false)
        do {
            _ = try await provider.summarize(input: input)
            XCTFail("Expected apiKeyMissing")
        } catch let e as AppError {
            guard case .apiKeyMissing = e else { return XCTFail("Unexpected error: \(e)") }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

