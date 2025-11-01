//
//  main.swift
//  VisionFoundationModel
//
//  Created by 三浦知明 on 2025/11/01.
//

import SwiftUI
import AVFoundation
import FoundationModels

struct MainView: View {
    @State private var viewModel = MainViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = viewModel.capturedImage {
                        VStack(spacing: 12) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
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
                    
                    if viewModel.capturedImage != nil {
                        Button(action: {
                            Task {
                                await viewModel.processOCR()
                            }
                        }) {
                            HStack {
                                if viewModel.isProcessingOCR {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "text.viewfinder")
                                }
                                Text(viewModel.isProcessingOCR ? "テキストを認識中..." : "テキストを認識")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.isProcessingOCR || viewModel.isProcessingAI)
                    }
                    
                    if !viewModel.recognizedText.isEmpty, case .available = viewModel.modelAvailability {
                        Button(action: {
                            Task {
                                await viewModel.processAI()
                            }
                        }) {
                            HStack {
                                if viewModel.isProcessingAI {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "brain.head.profile")
                                }
                                Text(viewModel.isProcessingAI ? "AIで単語を抽出中..." : "AIで単語を抽出")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.isProcessingOCR || viewModel.isProcessingAI)
                    }
                    
                    if !viewModel.recognizedText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("認識されたテキスト:")
                                    .font(.headline)

                                Spacer()

                                Button(action: {
                                    UIPasteboard.general.string = viewModel.recognizedText
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                        Text("コピー")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                            }

                            ScrollView {
                                Text(viewModel.recognizedText)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 300)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    if !viewModel.extractedWords.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("抽出された単語:")
                                .font(.headline)

                            ForEach(Array(viewModel.extractedWords.enumerated()), id: \.offset) { index, entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(entry.word)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        if let partOfSpeech = entry.partOfSpeech {
                                            Text("(\(partOfSpeech))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()
                                    }

                                    Text(entry.meaning)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    if !entry.exampleSentence.isEmpty {
                                        Text(entry.exampleSentence)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                            .padding(.top, 4)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
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
