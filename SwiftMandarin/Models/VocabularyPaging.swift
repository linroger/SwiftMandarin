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

    /// Return the live identifiers the pager may retain after a transition.
    /// Keeping this policy in the model makes stale-host eviction directly
    /// testable instead of relying only on a controller-level assertion.
    static func pageWindowIDs(
        currentID: UUID?,
        orderedIDs: [UUID]
    ) -> Set<UUID> {
        Set(
            pageWindowIndices(currentID: currentID, orderedIDs: orderedIDs)
                .map { orderedIDs[$0] }
        )
    }

    /// Resolve the page UIKit and SwiftUI should agree on after an interactive
    /// or programmatic transition finishes. UIKit's visible page is
    /// authoritative when it survived a concurrent store mutation; otherwise
    /// prefer a live request, settled binding, or prior current page in that
    /// order, then the first survivor. Nil means the session is empty.
    static func resolvedIDAfterTransition(
        visibleID: UUID?,
        requestedID: UUID?,
        settledID: UUID?,
        currentID: UUID?,
        orderedIDs: [UUID]
    ) -> UUID? {
        let availableIDs = Set(orderedIDs)
        for candidate in [visibleID, requestedID, settledID, currentID] {
            if let candidate, availableIDs.contains(candidate) {
                return candidate
            }
        }
        return orderedIDs.first
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
