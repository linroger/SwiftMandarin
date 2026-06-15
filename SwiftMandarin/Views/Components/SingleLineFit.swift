//
//  SingleLineFit.swift
//  SwiftMandarin
//
//  A small helper that keeps a label on a single line. The system first shrinks
//  the font (down to `minimumScale` of nominal) to make the text fit the
//  available width, then truncates with a trailing ellipsis if it still cannot.
//
//  Use on width-constrained controls — buttons, pills, menu labels, list rows —
//  whose text is long or localized. Several labels combine English and Chinese
//  (e.g. provider names like "Qwen 通义千问" or actions like "保存所有错题词汇到词汇本")
//  and would otherwise wrap to two lines on a narrow iPhone.
//

import SwiftUI

extension View {
    /// Constrains the receiver to one line, scaling the font down to
    /// `minimumScale` of its nominal size before truncating.
    /// - Parameter minimumScale: smallest fraction of the font size the text may
    ///   shrink to (0…1). Defaults to 0.7.
    func fitSingleLine(_ minimumScale: CGFloat = 0.7) -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(minimumScale)
            .truncationMode(.tail)
    }
}
