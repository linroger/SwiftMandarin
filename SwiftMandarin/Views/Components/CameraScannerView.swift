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

    /// VoiceOver name for the icon-only pause/resume control, hoisted so the
    /// catalog sees one key per branch.
    private var scanToggleLabel: LocalizedStringKey {
        isScanning ? "Pause scanning" : "Resume scanning"
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
                                Text("Recognized Text")
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
                                .glassEffectCompat(cornerRadius: 12)
                            }
                            .padding()
                        }

                        // Capture button. The side controls float over the
                        // camera feed as one group of glass capsules.
                        GlassGroupCompat(spacing: 20) {
                            HStack(spacing: 20) {
                                Button {
                                    dismiss()
                                } label: {
                                    Text("Cancel")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .frame(width: 80, height: 44)
                                        .glassEffectCapsuleCompat(interactive: true)
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
                                .accessibilityLabel(Text("Use recognized text"))

                                Button {
                                    isScanning.toggle()
                                } label: {
                                    Image(systemName: isScanning ? "pause.fill" : "play.fill")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .frame(width: 80, height: 44)
                                        .glassEffectCapsuleCompat(interactive: true)
                                }
                                .accessibilityLabel(Text(scanToggleLabel))
                            }
                        }
                        .padding(.bottom, 40)
                    }
                } else {
                    // Scanner not available
                    ContentUnavailableView {
                        Label("Camera Unavailable", systemImage: "camera.fill")
                    } description: {
                        if !CameraScannerView.isSupported {
                            Text("Your device does not support text scanning")
                        } else {
                            Text("Please allow camera access in Settings")
                        }
                    }
                }
            }
            .navigationTitle("Scan Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
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
            Label("Camera Scan", systemImage: "camera.fill")
        } description: {
            Text("Camera scanning is only available on iOS devices")
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
                    Button("Close") {
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
