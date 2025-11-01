//
//  FoundationModelsService.swift
//  VisionFoundationModel
//
//  Created by 三浦知明 on 2025/11/01.
//

import Foundation
import FoundationModels

// MARK: - Data Models for Structured Output
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

// MARK: - Foundation Models Service
@MainActor
class FoundationModelsService {
    var isProcessing = false
    var modelAvailability: SystemLanguageModel.Availability = .unavailable(.deviceNotEligible)

    private let model = SystemLanguageModel.default

    init() {
        checkModelAvailability()
    }

    func checkModelAvailability() {
        modelAvailability = model.availability
    }

    /// OCRで読み取ったテキストから単語帳データを抽出する
    func extractVocabularyData(from text: String) async throws -> VocabularyData {
        guard case .available = modelAvailability else {
            throw FoundationModelsError.modelUnavailable
        }

        isProcessing = true
        defer { isProcessing = false }

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

        let prompt = """
        以下のテキストから英単語とその関連情報を抽出してください：

        \(text)

        重要な注意事項：
        - 例文は必ずテキスト内に実際に存在する英文を使用してください
        - 例文を新しく作成してはいけません
        - テキスト内に例文がない場合は、exampleSentenceを空文字列("")にしてください

        テキスト内の英単語を分析し、学習に適した単語を選んで単語帳データとして整理してください。
        """

        let session = LanguageModelSession(instructions: instructions)

        let response = try await session.respond(
            to: prompt,
            generating: VocabularyData.self
        )

        return response.content
    }
}

// MARK: - Errors
enum FoundationModelsError: LocalizedError {
    case modelUnavailable
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "このデバイスではAI機能が利用できません"
        case .processingFailed:
            return "テキストの処理に失敗しました"
        }
    }
}
