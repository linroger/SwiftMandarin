//
//  OpenCameraScannerIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct OpenCameraScannerIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Live Text Scanner"
    static var description = IntentDescription("Open SwiftMandarin directly to the live camera text scanner.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppRouteStore.shared.trigger(.openCameraScanner, preferredTab: .photo)
        }
        return .result()
    }
}
