//
//  SwiftMandarinApp.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI
import AppIntents

@main
struct SwiftMandarinApp: App {
    // Shared stores for app-wide state using @Observable
    @State private var savedTermsStore = SavedTermsStore.shared
    @State private var historyStore = TranslationHistoryStore.shared
    @State private var learningStore = LearningProgressStore.shared
    @State private var activityStore = LearningActivityStore.shared
    @State private var routeStore = AppRouteStore.shared
    // Drives the in-app English ⇄ 中文 language switch. Accessing the singleton
    // here also applies the saved language to Bundle.main before the first view.
    @State private var localization = LocalizationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    #if os(macOS)
    // Menu-bar quick translate. The Settings toggle writes this key; binding it
    // through `isInserted` adds/removes the status item live.
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    #endif

    /// Kept for the life of the process so the termination observer below
    /// stays registered.
    private static var terminationObserver: (any NSObjectProtocol)?

    init() {
        // Audio-input files are working copies scoped to one app session. A
        // startup sweep removes anything abandoned by a crash or force-quit.
        AudioInputFileStore.removeAllTemporaryFiles()
        // Ensures app shortcuts are registered and entity-backed parameters are refreshed.
        SwiftMandarinShortcutsProvider.updateAppShortcutParameters()
        Self.installTerminationFlush()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(savedTermsStore)
                .environment(historyStore)
                .environment(learningStore)
                .environment(activityStore)
                .environment(routeStore)
                // Switch UI language live: format with the chosen locale and
                // rebuild the tree so every localized string re-resolves.
                .environment(\.locale, localization.locale)
                .id(localization.language)
        }
        // Store writes are coalesced and deferred off the main thread (see
        // `PersistentCodableStore.save`). Leaving the foreground is the moment
        // the system may suspend or kill the process without another turn, so
        // whatever is pending is written synchronously right here.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                PersistentCodableStore.flushPendingWritesNow()
            }
        }

        #if os(macOS)
        Settings {
            MacOSSettingsView()
                .environment(savedTermsStore)
                .environment(historyStore)
                .environment(learningStore)
                .environment(activityStore)
                .environment(routeStore)
                .environment(\.locale, localization.locale)
                .id(localization.language)
        }

        // Quick translate from the menu bar — always available, even when the
        // main window is closed. Window style so the panel keeps focus while
        // the user types.
        MenuBarExtra(isInserted: $showInMenuBar) {
            MenuBarTranslateView()
                .environment(\.locale, localization.locale)
                .id(localization.language)
        } label: {
            Image(systemName: "character.bubble")
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    /// A deferred store write is a lost write if the process exits first, and
    /// a normal quit (⌘Q, or the system reclaiming a backgrounded app) does
    /// not always pass through a scene-phase change — so termination gets its
    /// own synchronous flush.
    private static func installTerminationFlush() {
        guard terminationObserver == nil else { return }
        #if os(iOS)
        let name = UIApplication.willTerminateNotification
        #else
        let name = NSApplication.willTerminateNotification
        #endif
        terminationObserver = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { _ in
            // Delivered on the main queue; the explicit assumption is what lets
            // the main-actor flush run inside a nonisolated notification block.
            MainActor.assumeIsolated {
                PersistentCodableStore.flushPendingWritesNow()
            }
        }
    }
}
