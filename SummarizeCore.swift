//
//  SummarizeCore.swift
//  LLMSummarizer2
//
//  Created by 大志田洋輝 on 2025/04/16.
//

// ネットワークリクエストや文字列操作に必要な標準ライブラリをインポート
import Foundation

// 要約処理のコアロジックを担当する構造体
struct SummarizeCore {
    // 入力されたURLからHTMLを取得し、Gemini APIに送信して要約を得る非同期処理
    static func execute(inputURL: String, completion: @escaping (String) -> Void) {
        Task {
            // Gemini APIのエンドポイントURLを生成。失敗時はエラーメッセージを返して終了
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyDE6E6SWmOg2YMcJoqjcbyqDJIgqDpdQRw") else {
                completion("URLが不正です")
                return
            }

            do {
                // 入力されたURLが有効な形式かを検証
                guard let inputURL = URL(string: inputURL) else {
                    completion("入力されたURLが不正です")
                    return
                }

                // 入力URLにアクセスするためのリクエストを作成
                let htmlRequest = URLRequest(url: inputURL)
                // 入力URLからHTMLデータを非同期で取得
                let (htmlData, _) = try await URLSession.shared.data(for: htmlRequest)
                // 取得したHTMLデータをUTF-8で文字列に変換
                let htmlString = String(decoding: htmlData, as: UTF8.self)

                // HTMLタグや特殊文字を削除し、テキスト本文を抽出
                let bodyText = htmlString
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .replacingOccurrences(of: "\n", with: "")

                // Geminiに渡す要約用のプロンプトを定義。記事内容の冒頭20000文字に限定
                let prompt = "次の記事本文の内容を、⭐️をマークにした合計300字程度の箇条書きで要約してください。列挙されている記事の場合、列挙されているもの全てを出力して下さい。なお、「次が記事の要約です」のような前置きはなしで、要約のみを出力してください。また、ウェブサイトや著者や編集部などの内容は不要です。：\n\(bodyText.prefix(20000))"

                // Gemini APIに送信するJSON形式のリクエストボディを作成
                let payload: [String: Any] = [
                    "contents": [
                        [
                            "parts": [
                                ["text": prompt]
                            ]
                        ]
                    ]
                ]

                // JSONのシリアライズに失敗した場合はエラー終了
                guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
                    completion("リクエストデータの生成に失敗しました")
                    return
                }

                // POSTリクエストの準備（URL、メソッド、ヘッダー、ボディ）
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = httpBody

#if DEBUG
                print("Request URL: \(request.url?.absoluteString ?? "nil")")
                if let bodyString = String(data: httpBody, encoding: .utf8) {
                    print("Request Body: \(bodyString)")
                }
#endif

                // Alt-Svcによる転送を回避するためのカスタム設定を適用したURLSession
                let config = URLSessionConfiguration.default
                config.httpAdditionalHeaders = ["Alt-Svc": "clear"]
                let session = URLSession(configuration: config)
                // Gemini APIにリクエストを送信し、レスポンスを取得
                let (data, _) = try await session.data(for: request)

                // レスポンスのJSONをパースし、要約結果の本文を抽出
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    // 表示用に整形（改行や箇条書き記号の調整）
                    let formattedText = text
                        .replacingOccurrences(of: "\\n", with: "\n")
                        .replacingOccurrences(of: "*", with: "•")
                    // 成功時の要約結果をコールバックで返却
                    completion(formattedText)
                } else {
                    // レスポンスが想定形式でない場合のエラー返却
                    completion("レスポンスの解析に失敗しました")
                }
            } catch {
                // ネットワーク処理中にエラーが発生した場合のエラー返却
                completion("HTML取得中にエラーが発生しました：\(error.localizedDescription)")
            }
        }
    }
}
