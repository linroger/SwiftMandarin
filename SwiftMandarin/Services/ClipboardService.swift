//
//  ClipboardService.swift
//  SwiftMandarin
//
//  Cross-platform clipboard service
//

import os.log

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ClipboardService {

    private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "Clipboard")

    /// Copy text to the system clipboard. Returns whether the write succeeded
    /// (it practically always does; failures are logged so they are not
    /// silently swallowed).
    @discardableResult
    static func copy(_ text: String) -> Bool {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let ok = pasteboard.setString(text, forType: .string)
        if !ok {
            log.error("NSPasteboard.setString failed")
        }
        return ok
        #else
        UIPasteboard.general.string = text
        return true
        #endif
    }

    static func paste() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}
