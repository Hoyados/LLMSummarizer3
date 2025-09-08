import Foundation

struct PromptTemplate: Sendable, Equatable {
    let system: String
    let userBase: String

    func user(url: URL) -> String {
        userBase.replacingOccurrences(of: "{url}", with: url.absoluteString)
    }
}

extension PromptTemplate {
    static let `default` = PromptTemplate(
        system: "あなたは正確で中立な記事要約の編集者です。数値・固有名詞は原文を尊重し、事実と推測を区別してください。出力は日本語です。",
        userBase: """
        対象URL: {url}
        本文:
        {content}

        出力:
        1) 3行サマリ
        2) 重要ポイント(最大5)
        3) 詳細(300語以内)
        4) 信頼性の簡易評価(根拠)
        """
    )
}

