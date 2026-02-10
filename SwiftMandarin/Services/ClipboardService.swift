//
//  ClipboardService.swift
//  SwiftMandarin
//
//  Cross-platform clipboard service
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ClipboardService {
    static func copy(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
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
