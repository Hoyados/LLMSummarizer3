# URL要約AI — Codex実装ブリーフ（必要十分版 v3）

> **目的**: このドキュメントは、Codex（コード生成アシスタント）に提示して**誤解なく実装を完了**させるための、MVPに必要十分な仕様・入出力契約・受け入れ基準をまとめたものです。曖昧表現を避け、具体的な I/F・構造・テスト観点を明示します。

---

## 0. Codexへの指令（そのまま貼り付けてください）

**役割**: あなたはiOSエンジニアです。Swift/SwiftUIで本仕様のMVPを**動作するアプリ**として実装してください。外部仕様・I/F・命名・テスト・アクセシビリティIDは本書に**厳密準拠**します。

**遵守事項**:

1. Swift 5.10 / Xcode 16 / iOS 17 以降でビルド可能にします。
2. PackageはSPMのみ使用します。外部通信は `URLSession` を使います。
3. 履歴は SwiftData、APIキーは Keychain（共有グループで拡張と共有）に保存します。
4. 本文抽出は `SwiftSoup` を用い、Readability相当のルールで主要本文を抽出します。
5. LLM呼び出しは抽象化プロトコル `LLMProvider` 経由で行い、MVPでは **ダミー実装** と **OpenAI実装** を同居させます。
6. すべての公開I/F（UseCase/Repository/Provider）にユニットテストを付与します。
7. 本書の\*\*受け入れ基準（DoD）\*\*を満たすまでコードを出力してください。

**出力物**: 完全なXcodeプロジェクト一式（SPM設定、SwiftDataモデル、App/Scene、SwiftUI画面、UseCase/Repository/Provider、テストコード、ダミーデータ、設定画面）。

---

## 1. スコープ / 非スコープ（MVP）

- **スコープ**: URL入力→HTML取得→主要本文抽出→LLM要約→結果表示→履歴保存。設定画面（APIキー・モデル選択・固定/カスタムプロンプト）。履歴画面（再要約・削除）。
- **非スコープ**: マルチプロバイダ同時実行、Notion連携、iCloud同期、サーバー側キャッシュ、Watchアプリ。

---

## 2. 成果物（ターゲット・モジュール）

```
Targets
├─ URLSummaryApp (iOS App)
├─ URLSummaryShare (Share Extension)
└─ URLSummaryTests (Unit/UI Tests)

Modules (Groups)
├─ App
├─ Features
│  ├─ Home
│  ├─ History
│  └─ Settings
├─ Domain (Protocols / UseCases / Entities)
├─ Data   (Repositories / Store / Parsers / Providers)
└─ Support (DesignSystem / Utilities / Logging)
```

---

## 3. 技術スタック & バージョン

- Swift 5.10 / Xcode 16 / iOS 17+
- **依存（SPM）**: `SwiftSoup`（HTML解析）
- **データ**: SwiftData（履歴）, Keychain（APIキー）, FileManager（HTML/抽出結果キャッシュ）

---

## 4. 画面仕様（UI/UX）

### 4.1 Home（アクセシビリティID）

- `TextField`(URL) — `aid.home.urlField`
- `Button`(Paste) — `aid.home.pasteButton`
- `Button`(Summarize) — `aid.home.summarizeButton`
- 進捗インジケータ（取得→抽出→要約）— `aid.home.progress`
- 結果ビュー（タイトル/要約/メタ）— `aid.home.result`

**状態遷移**

```
Idle → FetchingHTML → ParsingContent → Summarizing → Succeeded | Failed
```

### 4.2 Settings

- APIキー入力（SecureField）— `aid.settings.apiKey`
- プロバイダ選択（OpenAI / Dummy）— `aid.settings.provider`
- モデル名文字列（例: `gpt-4o-mini`）— `aid.settings.model`
- カスタムプロンプト（Multiline）— `aid.settings.prompt`

### 4.3 History

- リスト（タイトル/ドメイン/日付/ピン）— `aid.history.list`
- 詳細（要約／再要約／削除）— `aid.history.detail`

---

## 5. ユースケース（Gherkin）

**UC-01 URLを要約する**

- Given: 有効なURLが入力されている
- When: Summarizeをタップする
- Then: HTML取得→本文抽出→LLM要約の順に進捗を表示し、10秒以内に初稿を表示する（ストリーミング非対応時は完了時に一括表示）。

**UC-02 履歴から再要約**

- Given: 履歴アイテムが存在する
- When: 「再要約」を押す
- Then: 現在の設定（モデル／プロンプト）で再要約し、結果を新規履歴として保存する。

**UC-03 APIキー未設定**

- Given: APIキーが未設定
- When: Summarizeをタップ
- Then: 設定画面への誘導ダイアログを表示し、処理を開始しない。

---

## 6. 入出力契約（Contracts）

### 6.1 Entities（SwiftData）

```swift
@Model
final class SummaryItem {
    @Attribute(.unique) var id: UUID
    var url: URL
    var domain: String
    var title: String
    var summary: String
    var createdAt: Date
    var modelId: String
    var promptId: String?
    var lang: String?
    var pinned: Bool
    var tags: [String]
}
```

### 6.2 UseCase I/F

```swift
protocol SummarizeArticleUseCase {
    func execute(url: URL, template: PromptTemplate) async throws -> SummaryItem
}
```

### 6.3 Provider I/F（厳守）

```swift
protocol LLMProvider {
    var id: String { get }
    func summarize(input: LLMInput) async throws -> LLMOutput
}

struct LLMInput {
    let systemPrompt: String
    let userPrompt: String
    let content: String
    let maxTokens: Int?
    let temperature: Double?
    let stream: Bool // MVPではfalse固定でも可
}

struct LLMOutput {
    let text: String
    let tokensInput: Int?
    let tokensOutput: Int?
}
```

### 6.4 Parser I/F

```swift
protocol ContentParser {
    func extract(html: String, baseURL: URL) throws -> ParsedArticle
}

struct ParsedArticle {
    let title: String
    let contentMarkdown: String // LLMへ渡す本文（Markdown整形済）
}
```

---

## 7. 本文抽出アルゴリズム（要件）

1. `<script|style|noscript|nav|footer|header|aside>` を除去します。
2. 見出し・段落を保持しつつテキストをMarkdown化します（リンクは `[text](url)`）。
3. 本文候補は、ノードのテキスト長・リンク密度・タグスコアで選びます（簡易Readability）。
4. 文字コードは `meta charset` / BOM / HTTP Header の順で推定します。
5. 出力は `ParsedArticle(title, contentMarkdown)` とします。

---

## 8. プロンプト（テンプレート）

**System**

```
あなたは正確で中立な記事要約の編集者です。数値・固有名詞は原文を尊重し、事実と推測を区別してください。出力は日本語です。
```

**User**

```
対象URL: {url}
本文:
{content}

出力:
1) 3行サマリ
2) 重要ポイント(最大5)
3) 詳細(300語以内)
4) 信頼性の簡易評価(根拠)
```

---

## 9. エラー設計

```swift
enum AppError: Error {
    case invalidURL
    case network(Error)
    case httpStatus(Int)
    case charsetDetectionFailed
    case contentParseFailed
    case emptyContent
    case apiKeyMissing
    case llmFailed(String)
}
```

**表示方針**: どのステップで失敗したかをトースト＋リトライ導線で明示します。

---

## 10. セキュリティ・プライバシー

- APIキー: Keychain（本体/拡張の共有アクセスグループ）。
- 送信データ: 抽出済み本文のみ（URL/タイトル含む）。
- ログ: 端末内（OSLog、プライバシーマスク）。外部送信なし（デフォルト）。

---

## 11. パフォーマンス/コスト要件

- 体感: 3秒以内に進捗表示、10秒以内に初稿表示（非ストリーミング時）。
- コスト表示（任意）: `推定料金 = (入力tokens×単価_in) + (出力tokens×単価_out)` を計算し注記します。

---

## 12. テレメトリ（ローカル）

- `event.fetch.started/finished/failed`
- `event.parse.started/finished/failed`
- `event.summarize.started/finished/failed`

プロパティ: `urlDomain`, `durationMs`, `chars`, `modelId`, `errorCode`。

---

## 13. テスト戦略（最小セット）

- **Unit**: Parser（ゴールデンHTML3種/失敗2種）、LLMProvider（Dummyで確定出力）、UseCase（成功/失敗、再要約）。
- **UI**: Home/Settings/History のスナップショット（Dynamic Type含む）。
- **Contracts**: `LLMProvider` / `ContentParser` のモックを使い、I/F破壊を検知します。

---

## 14. ビルド/実行手順

1. Xcodeで開く → URLSummaryApp を選択してRun。
2. 初回起動で Settings にて OpenAI APIキーを入力。
3. HomeでURLを貼り付け → Summarize。

**SPM追加**: `https://github.com/scinfu/SwiftSoup`（最新版）

---

## 15. 受け入れ基準（Definition of Done）

-

---

## 16. 将来拡張のための差し替え点（インターフェース固定）

- `LLMProvider` / `ContentParser` / `SummaryRepository` は**プロトコル公開**し、モジュール境界を維持します。

---

## 17. 参考スケルトン

```swift
final class DefaultSummarizeArticleUseCase: SummarizeArticleUseCase {
    let fetcher: URLFetcher
    let parser: ContentParser
    let llm: LLMProvider
    let repo: SummaryRepository

    func execute(url: URL, template: PromptTemplate) async throws -> SummaryItem {
        guard url.scheme?.hasPrefix("http") == true else { throw AppError.invalidURL }
        let html = try await fetcher.fetch(url: url)
        let article = try parser.extract(html: html, baseURL: url)
        let input = LLMInput(
            systemPrompt: template.system,
            userPrompt: template.user(url: url),
            content: article.contentMarkdown,
            maxTokens: 1024,
            temperature: 0.2,
            stream: false
        )
        let out = try await llm.summarize(input: input)
        return try await repo.save(url: url, title: article.title, summary: out.text, modelId: llm.id)
    }
}
```

---

## 18. 付録

### 18.1 PromptTemplate 例

```swift
struct PromptTemplate {
    let system: String
    let userBase: String
    func user(url: URL) -> String { userBase.replacingOccurrences(of: "{url}", with: url.absoluteString) }
}
```

### 18.2 ゴールデンHTML例（テスト用の最小断片）

- `news.sample.html`（記事主体、画像多め）
- `blog.sample.html`（コードブロック含む）
- `doc.sample.html`（長見出し+表）
- `error.empty.html`（本文なし）
- `error.charset.html`（文字化け想定）

---

以上の仕様に厳密に従って、Codexは**コンパイル通過・画面遷移・要約実行まで確認可能なMVP**を生成してください。

