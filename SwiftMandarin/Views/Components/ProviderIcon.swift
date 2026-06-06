//
//  ProviderIcon.swift
//  SwiftMandarin
//
//  Renders an AI provider's brand mark from the asset catalog (vector SVG),
//  falling back to the provider's SF Symbol if the asset cannot be loaded.
//
//  Full-color brand marks (Claude, Qwen, DeepSeek, …) render in their original
//  colors. Single-color glyphs (Apple, OpenAI, Ollama) render as template
//  images so they inherit the surrounding `.foregroundStyle`/`.tint` and adapt
//  to light and dark mode.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ProviderIcon: View {
    let provider: AIProvider
    /// Side length of the (square) icon in points. Defaults to a value that
    /// reads well alongside body text.
    var size: CGFloat = 18

    var body: some View {
        if Self.assetExists(provider.brandAssetName) {
            Image(provider.brandAssetName)
                .renderingMode(provider.brandAssetIsMonochrome ? .template : .original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .accessibilityLabel(provider.displayName)
        } else {
            Image(systemName: provider.iconName)
        }
    }

    /// Confirms the brand asset is bundled before using it, so a missing or
    /// mistyped asset name degrades gracefully to the SF Symbol fallback.
    private static func assetExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #elseif canImport(AppKit)
        return NSImage(named: name) != nil
        #else
        return true
        #endif
    }
}
