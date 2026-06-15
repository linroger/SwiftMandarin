//
//  CameraImagePicker.swift
//  SwiftMandarin
//
//  Presents the device camera to capture a single still photo and returns its
//  JPEG bytes. Used by the workbook grader so users can shoot a workbook page
//  directly, instead of only picking from the Photos library or Files.
//

import SwiftUI

#if os(iOS)
import UIKit

/// A SwiftUI wrapper around `UIImagePickerController` configured for direct
/// camera capture. Present it from a `.fullScreenCover` (the camera UI requires
/// full-screen presentation). The captured image is delivered as JPEG `Data`.
struct CameraImagePicker: UIViewControllerRepresentable {
    /// Called with the captured photo's JPEG bytes. Not called on cancel.
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    /// Whether a camera is present (false on Simulator and camera-less devices).
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Guard against devices without a camera so we never assert at runtime.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        }
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker
        init(_ parent: CameraImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#else

/// macOS has no `UIImagePickerController` camera capture; this stub is never
/// presented because the camera button is hidden on macOS.
struct CameraImagePicker: View {
    let onCapture: (Data) -> Void
    static var isAvailable: Bool { false }
    var body: some View { EmptyView() }
}

#endif
