import Foundation

enum SummarizeStage: String, Sendable {
    case fetching
    case parsing
    case summarizing
    case completed
}

struct SummarizeProgress: Sendable, Equatable {
    let stage: SummarizeStage
    let timestamp: Date
}

typealias SummarizeProgressHandler = @Sendable (SummarizeProgress) -> Void

protocol SummarizeArticleUseCase {
    func execute(url: URL, template: PromptTemplate) async throws -> SummaryItem
    func execute(url: URL, template: PromptTemplate, progress: SummarizeProgressHandler?) async throws -> SummaryItem
}

extension SummarizeArticleUseCase {
    func execute(url: URL, template: PromptTemplate, progress: SummarizeProgressHandler?) async throws -> SummaryItem {
        try await execute(url: url, template: template)
    }
}
