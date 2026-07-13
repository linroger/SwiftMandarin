//
//  VocabularyPaging.swift
//  SwiftMandarin
//
//  Deterministic, UI-independent vocabulary paging rules.
//

import Foundation

enum VocabularyPaging {
    /// Remove duplicate identifiers without changing the learner-visible order.
    static func uniqueIDs(_ orderedIDs: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return orderedIDs.filter { seen.insert($0).inserted }
    }

    /// Return the non-wrapping neighbor in the supplied visible order.
    ///
    /// The caller owns the order (for example, its filtered and sorted list),
    /// so paging never silently falls back to raw storage order.
    static func neighborID(
        currentID: UUID?,
        offset: Int,
        orderedIDs: [UUID]
    ) -> UUID? {
        guard offset != 0,
              let currentID,
              let currentIndex = orderedIDs.firstIndex(of: currentID) else {
            return nil
        }

        let targetIndex = currentIndex + offset
        guard orderedIDs.indices.contains(targetIndex) else { return nil }
        return orderedIDs[targetIndex]
    }

    /// Return the current page and, when available, its immediate neighbors.
    ///
    /// Keeping this rule independent from SwiftUI makes the pager's bounded
    /// memory behavior deterministic and directly testable for small and very
    /// large vocabulary sessions.
    static func pageWindowIndices(
        currentID: UUID?,
        orderedIDs: [UUID]
    ) -> [Int] {
        guard let currentID,
              let currentIndex = orderedIDs.firstIndex(of: currentID) else {
            return []
        }

        let lowerBound = max(orderedIDs.startIndex, currentIndex - 1)
        let upperBound = min(orderedIDs.endIndex, currentIndex + 2)
        return Array(lowerBound..<upperBound)
    }

    /// Keep the current page when possible, otherwise return the session's
    /// initial page, then the first surviving page. Nil means the session has
    /// no content left and should close.
    static func reconciledID(
        preferredID: UUID?,
        initialID: UUID,
        orderedIDs: [UUID]
    ) -> UUID? {
        if let preferredID, orderedIDs.contains(preferredID) {
            return preferredID
        }
        if orderedIDs.contains(initialID) {
            return initialID
        }
        return orderedIDs.first
    }
}
