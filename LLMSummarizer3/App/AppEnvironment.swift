import Foundation
import SwiftData

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    func makeUseCase(context: ModelContext, settings: SettingsStore) throws -> SummarizeArticleUseCase {
        let fetcher = DefaultURLFetcher()
        let parser = SwiftSoupContentParser()
        guard let key = try settings.getAPIKey(for: .gemini), !key.isEmpty else { throw AppError.apiKeyMissing }
        let provider: LLMProvider = GeminiProvider(model: settings.model, apiKey: key)
        let repo = SwiftDataSummaryRepository(context: context)
        return DefaultSummarizeArticleUseCase(fetcher: fetcher, parser: parser, llm: provider, repo: repo)
    }
}
