import Foundation

enum AppError: Error, LocalizedError {
    case invalidURL
    case network(Error)
    case httpStatus(Int)
    case charsetDetectionFailed
    case contentParseFailed
    case emptyContent
    case apiKeyMissing
    case llmFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URLが不正です。"
        case .network(let err): return "ネットワークエラー: \(err.localizedDescription)"
        case .httpStatus(let code): return "HTTPステータスエラー: \(code)"
        case .charsetDetectionFailed: return "文字コードの判定に失敗しました。"
        case .contentParseFailed: return "本文抽出に失敗しました。"
        case .emptyContent: return "本文が空でした。"
        case .apiKeyMissing: return "APIキーが未設定です。"
        case .llmFailed(let msg): return "LLMエラー: \(msg)"
        }
    }
}

