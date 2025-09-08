import XCTest
import SwiftData
@testable import LLMSummarizer3

final class UseCaseTests: XCTestCase {
    func test_execute_success() async throws {
        let container = try ModelContainer(for: SummaryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let useCase = DefaultSummarizeArticleUseCase(
            fetcher: MockFetcher(html: "<html><head><title>T</title></head><body><article><p>hello world</p></article></body></html>"),
            parser: SwiftSoupContentParser(),
            llm: MockLLM(),
            repo: SwiftDataSummaryRepository(context: ctx)
        )
        let url = URL(string: "https://example.com")!
        let item = try await useCase.execute(url: url, template: PromptTemplate.default)
        XCTAssertEqual(item.domain, "example.com")
    }

    func test_invalid_url_throws() async {
        let container = try! ModelContainer(for: SummaryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let useCase = DefaultSummarizeArticleUseCase(
            fetcher: MockFetcher(html: ""),
            parser: SwiftSoupContentParser(),
            llm: MockLLM(),
            repo: SwiftDataSummaryRepository(context: ctx)
        )
        await XCTAssertThrowsErrorAsync(try await useCase.execute(url: URL(string: "ftp://invalid")!, template: PromptTemplate.default))
    }
}

private struct MockFetcher: URLFetcher {
    let html: String
    func fetch(url: URL) async throws -> String { html }
}

private struct MockLLM: LLMProvider {
    var id: String { "mock" }
    func summarize(input: LLMInput) async throws -> LLMOutput {
        LLMOutput(text: "ok: \(input.content.prefix(10))", tokensInput: 1, tokensOutput: 1)
    }
}

extension XCTestCase {
    func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure @escaping () async throws -> T) async {
        do { _ = try await expression(); XCTFail("Expected error") } catch { }
    }
}
