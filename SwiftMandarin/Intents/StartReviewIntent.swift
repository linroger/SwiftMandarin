//
//  StartReviewIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct StartReviewIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Review"
    static var description = IntentDescription("Open SwiftMandarin directly into a configured review session.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Review Mode", default: .due)
    var reviewMode: ShortcutReviewMode

    @Parameter(title: "Card Source", default: .combined)
    var cardSource: ShortcutCardSource

    static var parameterSummary: some ParameterSummary {
        Summary("Start review with \(\.$reviewMode)") {
            \.$cardSource
        }
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppRouteStore.shared.triggerReview(
                mode: reviewMode.rawValue,
                source: cardSource.rawValue
            )
        }
        return .result()
    }
}
