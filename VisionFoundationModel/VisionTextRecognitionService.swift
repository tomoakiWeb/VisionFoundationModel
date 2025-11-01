//
//  VisionTextRecognitionService.swift
//  VisionFoundationModel
//
//  Created by 三浦知明 on 2025/11/01.
//

import Foundation
import Vision
import UIKit

@MainActor
class VisionTextRecognitionService {
    var isProcessing = false
    var recognizedText = ""
    var errorMessage: String?

    func recognizeText(from image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            isProcessing = true
            errorMessage = nil
            
            guard let cgImage = image.cgImage else {
                isProcessing = false
                continuation.resume(throwing: VisionError.invalidImage)
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                DispatchQueue.main.async {
                    self.isProcessing = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        let error = VisionError.noTextFound
                        self.errorMessage = error.localizedDescription
                        continuation.resume(throwing: error)
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
                    self.recognizedText = recognizedText

                    if recognizedText.isEmpty {
                        let error = VisionError.noTextFound
                        self.errorMessage = error.localizedDescription
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: recognizedText)
                    }
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.revision = VNRecognizeTextRequestRevision3
            request.automaticallyDetectsLanguage = false
            request.recognitionLanguages = ["ja-JP","en-US"]

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        guard let grayImage = context?.makeImage() else { return nil }
        return UIImage(cgImage: grayImage)
    }
}

// MARK: - Errors
enum VisionError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "画像の形式が無効です"
        case .noTextFound:
            return "画像内にテキストが見つかりませんでした"
        case .processingFailed:
            return "テキスト認識に失敗しました"
        }
    }
}
