# VisionFoundationModel

カメラで撮影したテキストからOCRで英単語を認識し、Foundation Modelsを使用して単語データを自動生成します。

## 機能
- **OCR（テキスト認識）**: Visionフレームワークによる文字認識
- **AI単語抽出**: Foundation Modelsによる英単語の自動分類と意味抽出

## 技術スタック
- **Vision Framework**: 画像からのテキスト認識
- **Foundation Models**: Apple Intelligenceによる自然言語処理

## Visionフレームワークによるテキスト検出の仕組み

### 1. VNRecognizeTextRequestの設定

Visionフレームワークの`VNRecognizeTextRequest`を使用してテキストを認識します：

```swift
let request = VNRecognizeTextRequest { request, error in
    // 認識結果の処理
}

request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.revision = VNRecognizeTextRequestRevision3
request.automaticallyDetectsLanguage = false
request.recognitionLanguages = ["ja-JP","en-US"]
```

**設定パラメータの詳細:**

- **recognitionLevel = .accurate**:
  - 高精度モードを使用（`.fast`より精度が高いが処理時間は長い）
  - 複雑なフォントや小さな文字でも正確に認識

- **usesLanguageCorrection = false**:
  - スペル自動修正を無効化
  - 単語帳の情報を正確に読み取るため、OCRの生の結果を使用
  - 誤修正による意図しない単語変更を防止

- **revision = VNRecognizeTextRequestRevision3**:
  - 最新のアルゴリズムを使用
  - より高い認識精度と多言語サポート

- **recognitionLanguages = ["ja-JP","en-US"]**:
  - 日本語と英語を認識対象に設定
  - 混在したテキストでも正確に認識

### 2. テキスト認識の実行

```swift
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try handler.perform([request])
```

### 3. 認識結果の取得

```swift
guard let observations = request.results as? [VNRecognizedTextObservation] else {
    return
}

var recognizedStrings: [String] = []
for observation in observations {
    guard let topCandidate = observation.topCandidates(1).first else {
        continue
    }
    recognizedStrings.append(topCandidate.string)
}

let recognizedText = recognizedStrings.joined(separator: "\n")
```

**VNRecognizedTextObservation:**
- `topCandidates(n)`: 信頼度が高い上位n個の認識候補を取得
  - 引数`n`は取得する候補の数を指定（`topCandidates(1)`で最も信頼度の高い1つの候補を含む配列を返す）
  - `.first`で配列から単一の`VNRecognizedText`オブジェクトを取得

## Foundation Modelsによる単語分類の仕組み

### 1. 構造化データモデルの定義

`@Generable`マクロを使用して、AIが生成すべきデータ構造を定義します：

```swift
@Generable(description: "Extracted vocabulary data from text")
struct VocabularyData {
    @Guide(description: "List of vocabulary entries extracted from the text")
    var entries: [VocabularyEntry]
}

@Generable(description: "A single vocabulary entry with word, meaning, and example")
struct VocabularyEntry {
    @Guide(description: "The English word or phrase")
    var word: String

    @Guide(description: "The meaning or definition of the word in Japanese")
    var meaning: String

    @Guide(description: "An example sentence using the word in English")
    var exampleSentence: String

    @Guide(description: "Part of speech (e.g., 名詞, 動詞, 形容詞) in Japanese")
    var partOfSpeech: String?
}
```

**@Generableマクロの役割:**
- AIに生成すべきデータ構造を明示的に指示
- 型安全性を保証しながら構造化出力を実現
- `@Guide`で各フィールドの意味をAIに説明

### 2. インストラクション

```swift
let instructions = """
あなたは英語学習を支援するAIアシスタントです。
与えられたテキストから英単語とその意味、例文を抽出して単語帳データを作成してください。

重要：以下のルールに厳密に従ってください：
1. 英単語は基本形（原形）を使用する
2. 意味は日本語で簡潔に説明する
3. 例文は必ずテキスト内から抽出すること。新しく例文を作成してはいけない。テキストに含まれている英文をそのまま使用すること。
4. テキスト内に例文がない単語は、exampleSentenceを空文字列("")にすること
5. 品詞は日本語で記載する（名詞、動詞、形容詞 など）
6. 重複する単語は除外する
7. 一般的でない固有名詞は除外する
8. 最大10個の単語まで抽出する
"""
```

**インストラクションの設計ポイント:**

- **役割定義**: AIの目的と責任を明確化
- **具体的な制約**: 出力形式と品質基準を指定
- **エラー防止**: 望ましくない動作（例文の創作など）を明示的に禁止
- **データ品質管理**: 重複排除や固有名詞のフィルタリング

### 3. プロンプトの構成

```swift
let prompt = """
以下のテキストから英単語とその関連情報を抽出してください：

\(text)

重要な注意事項：
- 例文は必ずテキスト内に実際に存在する英文を使用してください
- 例文を新しく作成してはいけません
- テキスト内に例文がない場合は、exampleSentenceを空文字列("")にしてください

テキスト内の英単語を分析し、学習に適した単語を選んで単語帳データとして整理してください。
"""
```

**プロンプトエンジニアリングの技法:**
- OCRで認識したテキストを直接挿入
- 重要な制約を繰り返し強調（例文の扱いなど）
- タスクの最終目標を明確に記述

### 4. LanguageModelSessionによる処理

```swift
let session = LanguageModelSession(instructions: instructions)

let response = try await session.respond(
    to: prompt,
    generating: VocabularyData.self
)

return response.content
```

**Foundation Modelsの処理フロー:**

1. **セッション初期化**:
   - `instructions`でAIの動作モードを設定
   - コンテキストとして全体的なルールを保持

2. **構造化生成リクエスト**:
   - `generating: VocabularyData.self`で出力型を指定
   - AIは`@Generable`定義に従ってJSONスキーマを認識

3. **構造化データ生成**:
   - `VocabularyEntry`の配列を作成
   - 各フィールドに適切な値を設定
   - 制約（最大10個、重複排除など）を適用

## プロジェクト構成

```
VisionFoundationModel/
├── VisionFoundationModelApp.swift       # アプリエントリーポイント
├── AvailabilityView.swift              # Foundation Models可用性チェック
├── MainView.swift                       # メインUI
├── MainViewModel.swift                  # ビジネスロジック
├── ImagePickerCoordinator.swift         # カメラ撮影
├── VisionTextRecognitionService.swift   # OCRサービス
└── FoundationModelsService.swift        # AI処理サービス
```

## 動作フロー

1. **起動時**: `AvailabilityView`でFoundation Modelsの可用性を確認
2. **カメラ権限**: `MainViewModel`でAVFoundationを使用して権限をリクエスト
3. **写真撮影**: `ImagePicker`でカメラを起動し画像をキャプチャ
4. **OCR処理**:
   - `VisionTextRecognitionService`が画像を前処理
   - `VNRecognizeTextRequest`でテキストを認識
   - 日英混在テキストを正確に抽出
5. **AI処理**:
   - `FoundationModelsService`が認識テキストを受け取り
   - `LanguageModelSession`に構造化生成リクエストを送信
   - AIが単語を分析・分類し、`VocabularyData`を生成
6. **結果表示**: 抽出された単語、意味、品詞、例文をUIに表示

## 必要要件

- iOS 26.0以降
- Apple Intelligence対応デバイス
- Apple Intelligenceが有効になっていること

## 技術的な特徴

### Vision Framework
- **高精度OCR**: VNRecognizeTextRequestRevision3を使用
- **多言語対応**: 日本語と英語を同時認識
- **正確な読み取り**: スペル自動修正を無効化し、単語帳の固有表記を正確に認識

### Foundation Models
- **構造化出力**: `@Generable`マクロで型安全なデータ生成
- **プロンプトエンジニアリング**: 詳細なインストラクションで精度向上
- **コンテキスト理解**: OCRテキストから単語の意味と用法を抽出
- **品質管理**: 重複排除、固有名詞フィルタリング、例文の真正性保証
