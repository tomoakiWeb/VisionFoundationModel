//
//  main.swift
//  VisionFoundationModel
//
//  Created by 三浦知明 on 2025/11/01.
//

import SwiftUI
import AVFoundation

struct MainView: View {
    @State private var viewModel = MainViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = viewModel.capturedImage {
                        VStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 400)
                                .cornerRadius(10)
                                .shadow(radius: 5)

                            Text("画像が選択されました")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("写真を撮影してください")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .frame(height: 200)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.requestCameraPermission()
                            if viewModel.cameraPermissionStatus == .authorized {
                                viewModel.showCamera = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("カメラで撮影")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                ImagePicker(
                    selectedImage: $viewModel.capturedImage,
                    sourceType: .camera
                )
                .ignoresSafeArea()
            }
            .alert("カメラへのアクセスが必要です", isPresented: $viewModel.showPermissionAlert) {
                if !viewModel.errorMessage.contains("利用できません") {
                    Button("設定を開く") {
                        viewModel.openSettings()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage.isEmpty ? "このアプリでカメラを使用するには、設定からカメラへのアクセスを許可してください。" : viewModel.errorMessage)
            }
        }
    }
}
