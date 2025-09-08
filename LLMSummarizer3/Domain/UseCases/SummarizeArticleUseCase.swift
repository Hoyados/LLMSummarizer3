import Foundation

protocol SummarizeArticleUseCase {
    func execute(url: URL, template: PromptTemplate) async throws -> SummaryItem
}

