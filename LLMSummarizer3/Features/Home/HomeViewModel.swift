import Foundation
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case fetching
        case parsing
        case summarizing
        case succeeded(SummaryItem)
        case failed(String)
    }

    @Published var urlText: String = ""
    @Published var state: State = .idle

    func summarize(context: ModelContext, env: AppEnvironment, settings: SettingsStore) async {
        guard let url = URL(string: urlText) else {
            state = .failed(AppError.invalidURL.localizedDescription)
            return
        }
        do {
            // Build use case each time to reflect settings/provider
            let useCase = try env.makeUseCase(context: context, settings: settings)

            self.state = .fetching
            // Fetch inside use case, we only mirror progress locally for UI
            let template: PromptTemplate = settings.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .default
                : PromptTemplate(system: PromptTemplate.default.system, userBase: settings.customPrompt)
            let articleFetcher = Task {
                try await useCase.execute(url: url, template: template)
            }
            // Simulate staged progress updates
            try await Task.sleep(nanoseconds: 150_000_000)
            if !articleFetcher.isCancelled { self.state = .parsing }
            try await Task.sleep(nanoseconds: 150_000_000)
            if !articleFetcher.isCancelled { self.state = .summarizing }

            let item = try await articleFetcher.value
            self.state = .succeeded(item)
        } catch let e as AppError {
            self.state = .failed(e.localizedDescription)
        } catch {
            self.state = .failed(error.localizedDescription)
        }
    }
}
