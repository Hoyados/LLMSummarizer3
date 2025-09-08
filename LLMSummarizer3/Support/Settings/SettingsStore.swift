import Foundation

enum ProviderKind: String, CaseIterable, Identifiable {
    case gemini
    var id: String { rawValue }
    var displayName: String { "Gemini" }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var provider: ProviderKind {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider)
            Task { await refreshMask() }
        }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }
    @Published var customPrompt: String {
        didSet { UserDefaults.standard.set(customPrompt, forKey: Keys.customPrompt) }
    }
    @Published var apiKeyMasked: String = "" // for UI display only

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.provider), let k = ProviderKind(rawValue: raw) {
            provider = k
        } else { provider = .gemini }
        model = UserDefaults.standard.string(forKey: Keys.model) ?? "gemini-2.5-flash"
        if let stored = UserDefaults.standard.string(forKey: Keys.customPrompt), !stored.isEmpty {
            customPrompt = stored
        } else {
            customPrompt = PromptTemplate.default.userBase
            UserDefaults.standard.set(customPrompt, forKey: Keys.customPrompt)
        }
        Task { await refreshMask() }
    }

    func refreshMask() async {
        let key = try? KeychainService.shared.get(service: Keys.kcService, account: Keys.account(for: provider))
        apiKeyMasked = key?.isEmpty == false ? "••••••••" : ""
    }

    func setAPIKey(_ key: String, for provider: ProviderKind? = nil) throws {
        let p = provider ?? self.provider
        try KeychainService.shared.set(key, service: Keys.kcService, account: Keys.account(for: p))
        Task { await refreshMask() }
    }

    func getAPIKey(for provider: ProviderKind? = nil) throws -> String? {
        let p = provider ?? self.provider
        return try KeychainService.shared.get(service: Keys.kcService, account: Keys.account(for: p))
    }

    func resetPromptToDefault() {
        customPrompt = PromptTemplate.default.userBase
    }
}

enum Keys {
    static let provider = "settings.provider"
    static let model = "settings.model"
    static let customPrompt = "settings.customPrompt"
    static let kcService = "URLSummaryAPI"
    static func account(for provider: ProviderKind) -> String { "Gemini" }
}

extension SettingsStore {
    static let geminiModels: [String] = [
        "gemini-2.5-flash",
        "gemini-1.5-flash",
        "gemini-1.5-pro"
    ]
}
