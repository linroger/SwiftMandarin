//
//  CameraScannerView.swift
//  SwiftMandarin
//
//  Camera scanner component using VisionKit DataScannerViewController
//  For real-time text recognition from camera
//

import SwiftUI

#if os(iOS)
import VisionKit

/// SwiftUI wrapper for DataScannerViewController
struct CameraScannerView: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var isScanning: Bool
    let onTextRecognized: (String) -> Void
    let onDismiss: () -> Void
    
    // Check if device supports data scanning
    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }
    
    static var isAvailable: Bool {
        DataScannerViewController.isAvailable
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Double-check availability before creating scanner
        guard DataScannerViewController.isSupported && DataScannerViewController.isAvailable else {
            // Return a placeholder controller if scanner isn't available
            let placeholder = UIViewController()
            placeholder.view.backgroundColor = .systemBackground
            return placeholder
        }
        
        // Pass the user's scan-language preference so live camera OCR can read
        // Chinese (the no-argument `.text()` was locked to system/locale defaults).
        let languages = AppPreferences.shared.photoScanLanguage.recognitionLanguages
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: languages)],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Only control scanning if we have a DataScannerViewController
        guard let scanner = uiViewController as? DataScannerViewController else { return }
        
        if isScanning {
            if !scanner.isScanning {
                try? scanner.startScanning()
            }
        } else {
            if scanner.isScanning {
                scanner.stopScanning()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: CameraScannerView
        private var lastRecognizedText: String = ""
        
        init(_ parent: CameraScannerView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                let cleanedText = cleanTextForSentences(text.transcript)
                parent.recognizedText = cleanedText
                parent.onTextRecognized(cleanedText)
            default:
                break
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Combine all recognized text and clean it
            let rawText = allItems.compactMap { item -> String? in
                if case .text(let text) = item {
                    return text.transcript
                }
                return nil
            }.joined(separator: " ")
            
            let cleanedText = cleanTextForSentences(rawText)
            
            // Only update if text changed significantly
            if cleanedText != lastRecognizedText {
                lastRecognizedText = cleanedText
                parent.recognizedText = cleanedText
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Update text when items are removed
            let rawText = allItems.compactMap { item -> String? in
                if case .text(let text) = item {
                    return text.transcript
                }
                return nil
            }.joined(separator: " ")
            
            let cleanedText = cleanTextForSentences(rawText)
            lastRecognizedText = cleanedText
            parent.recognizedText = cleanedText
        }
        
        /// Clean OCR text in a language-aware way: Chinese text has its
        /// inter-character whitespace removed, English text gets sentence cleanup.
        private func cleanTextForSentences(_ text: String) -> String {
            let language = ChineseTextAnalyzer.shared.detectLanguageRobust(text)
            if language.isChinese {
                return TextRecognitionResult.cleanChineseText([text])
            } else {
                return TextRecognitionResult.cleanTextForSentences(text)
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            parent.isScanning = false
        }
    }
}

/// Full-screen camera scanner sheet
struct CameraScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var capturedText: String
    
    @State private var recognizedText: String = ""
    @State private var isScanning: Bool = true
    @State private var showConfirmation: Bool = false
    @State private var scannerError: String?
    
    private var isScannerAvailable: Bool {
        CameraScannerView.isSupported && CameraScannerView.isAvailable
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isScannerAvailable {
                    CameraScannerView(
                        recognizedText: $recognizedText,
                        isScanning: $isScanning,
                        onTextRecognized: { text in
                            // Optional: Auto-capture on tap
                        },
                        onDismiss: {
                            dismiss()
                        }
                    )
                    .ignoresSafeArea()
                    
                    // Overlay controls
                    VStack {
                        Spacer()
                        
                        // Recognized text preview
                        if !recognizedText.isEmpty {
                            VStack(spacing: 12) {
                                Text("识别到的文字")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                ScrollView {
                                    Text(recognizedText)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 120)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding()
                        }
                        
                        // Capture button
                        HStack(spacing: 20) {
                            Button {
                                dismiss()
                            } label: {
                                Text("取消")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 80, height: 44)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                            
                            Button {
                                capturedText = recognizedText
                                dismiss()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 4)
                            }
                            .disabled(recognizedText.isEmpty)
                            .opacity(recognizedText.isEmpty ? 0.5 : 1)
                            
                            Button {
                                isScanning.toggle()
                            } label: {
                                Image(systemName: isScanning ? "pause.fill" : "play.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 80, height: 44)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, 40)
                    }
                } else {
                    // Scanner not available
                    ContentUnavailableView {
                        Label("相机不可用", systemImage: "camera.fill")
                    } description: {
                        if !CameraScannerView.isSupported {
                            Text("您的设备不支持文字扫描功能")
                        } else {
                            Text("请在设置中允许相机访问权限")
                        }
                    }
                }
            }
            .navigationTitle("扫描文字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#else
// macOS placeholder - no camera scanning support
struct CameraScannerView: View {
    var body: some View {
        ContentUnavailableView {
            Label("相机扫描", systemImage: "camera.fill")
        } description: {
            Text("相机扫描功能仅在 iOS 设备上可用")
        }
    }
    
    static var isSupported: Bool { false }
    static var isAvailable: Bool { false }
}

struct CameraScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var capturedText: String
    
    var body: some View {
        CameraScannerView()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
    }
}
#endif

// MARK: - Preview

#Preview {
    @Previewable @State var text = ""
    CameraScannerSheet(capturedText: $text)
}
