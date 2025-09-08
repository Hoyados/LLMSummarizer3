import Foundation

final class DefaultSummarizeArticleUseCase: SummarizeArticleUseCase {
    let fetcher: URLFetcher
    let parser: ContentParser
    let llm: LLMProvider
    let repo: SummaryRepository

    init(fetcher: URLFetcher, parser: ContentParser, llm: LLMProvider, repo: SummaryRepository) {
        self.fetcher = fetcher
        self.parser = parser
        self.llm = llm
        self.repo = repo
    }

    func execute(url: URL, template: PromptTemplate) async throws -> SummaryItem {
        guard url.scheme?.hasPrefix("http") == true else { throw AppError.invalidURL }

        Telemetry.shared.logEvent(.fetchStarted, props: [.urlDomain: url.host ?? ""])
        let html = try await fetcher.fetch(url: url)

        Telemetry.shared.logEvent(.parseStarted, props: [.urlDomain: url.host ?? "", .chars: String(html.count)])
        let article = try parser.extract(html: html, baseURL: url)
        Telemetry.shared.logEvent(.parseFinished, props: [.urlDomain: url.host ?? ""])

        let input = LLMInput(
            systemPrompt: template.system,
            userPrompt: template.user(url: url),
            content: article.contentMarkdown,
            maxTokens: 1024,
            temperature: 0.2,
            stream: false
        )

        Telemetry.shared.logEvent(.summarizeStarted, props: [.urlDomain: url.host ?? "", .modelId: llm.id])
        let out = try await llm.summarize(input: input)
        Telemetry.shared.logEvent(.summarizeFinished, props: [.urlDomain: url.host ?? "", .modelId: llm.id])

        return try await repo.save(url: url, title: article.title, summary: out.text, modelId: llm.id, promptId: nil, isUnread: false)
    }
}
