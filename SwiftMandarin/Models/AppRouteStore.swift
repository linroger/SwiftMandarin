//
//  AppRouteStore.swift
//  SwiftMandarin
//
//  App-wide routing for App Intents and shortcuts
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AppRouteStore {
    static let shared = AppRouteStore()

    var selectedTab: AppTab = .translate
    var pendingAction: AppPendingAction?

    private init() {}

    func trigger(_ kind: AppPendingAction.Kind, preferredTab: AppTab? = nil) {
        if let preferredTab {
            selectedTab = preferredTab
        }
        pendingAction = AppPendingAction(kind: kind)
    }

    func triggerReview(mode: String, source: String) {
        // On iOS the Learn screen lives inside the More hub, which pushes it
        // when this action arrives; on macOS Learn is its own sidebar item.
        #if os(iOS)
        selectedTab = .more
        #else
        selectedTab = .learn
        #endif
        pendingAction = AppPendingAction(kind: .startReview(mode: mode, source: source))
    }

    func clearPendingAction() {
        pendingAction = nil
    }
}

struct AppPendingAction: Equatable, Identifiable {
    enum Kind: Equatable {
        case openCameraScanner
        case startReview(mode: String, source: String)
        case translateScreenshots
    }

    let id: UUID = UUID()
    let kind: Kind
}
