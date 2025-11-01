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

    init() {
        checkCameraPermission()
    }

    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestCameraPermission() async {
        // シミュレーターかカメラが利用不可の場合はエラーを表示
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
}
