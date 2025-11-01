import SwiftUI
import FoundationModels
import AVFoundation
import UIKit

@Observable
class MainViewModel {
    var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    var showPermissionAlert = false
    var showCamera = false
    var capturedImage: UIImage?
    var showingActionSheet = false
    var errorMessage = ""
    var recognizedText = ""
    var isProcessingOCR = false

    private let visionService = VisionTextRecognitionService()

    init() {
        checkCameraPermission()
    }

    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestCameraPermission() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            await MainActor.run {
                errorMessage = "このデバイスではカメラが利用できません。"
                showPermissionAlert = true
            }
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                cameraPermissionStatus = granted ? .authorized : .denied
                if !granted {
                    errorMessage = "カメラへのアクセスが拒否されました。設定アプリから許可してください。"
                    showPermissionAlert = true
                }
            }
        case .denied, .restricted:
            await MainActor.run {
                errorMessage = "カメラへのアクセスが拒否されています。設定アプリから許可してください。"
                showPermissionAlert = true
            }
        case .authorized:
            await MainActor.run {
                cameraPermissionStatus = .authorized
            }
        @unknown default:
            break
        }
    }

    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    func processOCR() async {
        guard let image = capturedImage else {
            errorMessage = "画像が選択されていません"
            showPermissionAlert = true
            return
        }

        isProcessingOCR = true
        recognizedText = ""

        do {
            let processedImage = visionService.preprocessImage(image) ?? image
            let text = try await visionService.recognizeText(from: processedImage)
            await MainActor.run {
                recognizedText = text
                isProcessingOCR = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "テキスト認識に失敗しました: \(error.localizedDescription)"
                showPermissionAlert = true
                isProcessingOCR = false
            }
        }
    }
    
    func detectTextRegions() async -> [TextRegion] {
        guard let image = capturedImage else { return [] }

        do {
            let regions = try await visionService.detectTextRegions(in: image)
            return regions
        } catch {
            await MainActor.run {
                errorMessage = "テキスト領域の検出に失敗しました: \(error.localizedDescription)"
                showPermissionAlert = true
            }
            return []
        }
    }
}
