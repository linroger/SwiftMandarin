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

    var selectedTab: AppTab = .home
    var pendingAction: AppPendingAction?

    private init() {}

    func trigger(_ kind: AppPendingAction.Kind, preferredTab: AppTab? = nil) {
        if let preferredTab {
            selectedTab = preferredTab
        }
        pendingAction = AppPendingAction(kind: kind)
    }

    func triggerReview(mode: String, source: String) {
        // On iOS the Learn screen lives inside the Study hub, which pushes it
        // when this action arrives; on macOS Learn is its own sidebar item.
        #if os(iOS)
        selectedTab = .study
        #else
        selectedTab = .learn
        #endif
        pendingAction = AppPendingAction(kind: .startReview(mode: mode, source: source))
    }

    /// Open a specific destination inside the Study hub. On iOS the hub is a
    /// tab whose `NavigationStack` pushes the destination; on macOS the target
    /// is its own sidebar item, so we select it directly. `route` values match
    /// `StudyRoute` raw values (e.g. "stats", "vocabulary", "reader").
    func openStudy(route: String) {
        #if os(iOS)
        selectedTab = .study
        pendingAction = AppPendingAction(kind: .openStudyRoute(route))
        #else
        switch route {
        case "vocabulary": selectedTab = .vocabulary
        case "phrases": selectedTab = .phrases
        case "history": selectedTab = .history
        case "stats": selectedTab = .stats
        case "reader": selectedTab = .reader
        case "practice": selectedTab = .practice
        case "conversation": selectedTab = .conversation
        default: selectedTab = .learn
        }
        #endif
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
        /// Push a destination inside the Study hub (raw value of `StudyRoute`).
        case openStudyRoute(String)
    }

    let id: UUID = UUID()
    let kind: Kind
}
