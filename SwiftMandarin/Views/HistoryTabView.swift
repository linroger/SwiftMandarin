//
//  HistoryTabView.swift
//  SwiftMandarin
//
//  History view as a standalone tab with restore functionality
//

import SwiftUI
import UniformTypeIdentifiers

/// History tab view that allows users to view and restore previous translations
struct HistoryTabView: View {
    @Environment(TranslationHistoryStore.self) private var historyStore
    @Binding var selectedTab: AppTab
    @State private var searchText: String = ""
    @State private var draggedEntry: TranslationHistoryEntry?
    @State private var directionFilter: TranslationDirection?
    @State private var showClearConfirmation: Bool = false

    private var filteredEntries: [TranslationHistoryEntry] {
        var entries = historyStore.entries
        if let directionFilter {
            entries = entries.filter { $0.direction == directionFilter }
        }
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.source.localizedCaseInsensitiveContains(searchText) ||
                entry.target.localizedCaseInsensitiveContains(searchText)
            }
        }
        return entries
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if historyStore.entries.isEmpty {
                    ContentUnavailableView {
                        Label("No History", systemImage: "clock")
                    } description: {
                        Text("Your translation history will appear here")
                    }
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView {
                        Label("No Matches", systemImage: "magnifyingglass")
                    } description: {
                        Text("No history entries match the current search or filter")
                    } actions: {
                        Button("Clear Filter") {
                            searchText = ""
                            directionFilter = nil
                        }
                    }
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            HistoryItemRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    restoreTranslation(entry)
                                }
                                .contextMenu {
                                    historyContextMenu(for: entry)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        historyStore.remove(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        restoreTranslation(entry)
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.blue)
                                }
                                .draggable(entry.id.uuidString) {
                                    // Drag preview
                                    HistoryDragPreview(entry: entry)
                                }
                        }
                        .onMove { source, destination in
                            historyStore.move(from: source, to: destination)
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle("History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .searchable(text: $searchText, prompt: "Search history")
            .toolbar {
                if !historyStore.entries.isEmpty {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                    #endif
                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            Picker("Direction", selection: $directionFilter) {
                                Text("All Directions").tag(TranslationDirection?.none)
                                ForEach(TranslationDirection.allCases, id: \.self) { direction in
                                    Text("\(direction.sourceLanguageName) → \(direction.targetLanguageName)")
                                        .tag(TranslationDirection?.some(direction))
                                }
                            }
                        } label: {
                            Label("Filter", systemImage: directionFilter == nil
                                  ? "line.3.horizontal.decrease.circle"
                                  : "line.3.horizontal.decrease.circle.fill")
                        }
                        .accessibilityLabel(Text("Filter by direction"))
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(Text("Clear all history"))
                    }
                }
            }
            .confirmationDialog(
                "Clear all translation history?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    historyStore.clear()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every saved translation and cannot be undone.")
            }
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func historyContextMenu(for entry: TranslationHistoryEntry) -> some View {
        Button {
            restoreTranslation(entry)
        } label: {
            Label("Restore", systemImage: "arrow.uturn.backward")
        }
        
        Button {
            reverseTranslate(entry)
        } label: {
            Label("Reverse Translate", systemImage: "arrow.left.arrow.right")
        }
        
        Divider()
        
        Button {
            copySource(entry)
        } label: {
            Label("Copy Source", systemImage: "doc.on.doc")
        }
        
        Button {
            copyTranslation(entry)
        } label: {
            Label("Copy Translation", systemImage: "doc.on.doc.fill")
        }
        
        Button {
            copyBoth(entry)
        } label: {
            Label("Copy Both", systemImage: "rectangle.on.rectangle")
        }
        
        Divider()
        
        Button {
            duplicateEntry(entry)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        
        Divider()
        
        Button(role: .destructive) {
            historyStore.remove(entry)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func restoreTranslation(_ entry: TranslationHistoryEntry) {
        TranslationState.shared.restore(from: entry)
        selectedTab = .translate
    }
    
    private func reverseTranslate(_ entry: TranslationHistoryEntry) {
        // Use the translation result as the new source, reverse direction
        TranslationState.shared.sourceText = entry.target
        TranslationState.shared.translatedText = ""
        TranslationState.shared.direction = entry.direction.opposite
        TranslationState.shared.translationError = nil
        selectedTab = .translate
    }
    
    private func copySource(_ entry: TranslationHistoryEntry) {
        ClipboardService.copy(entry.source)
    }
    
    private func copyTranslation(_ entry: TranslationHistoryEntry) {
        ClipboardService.copy(entry.target)
    }
    
    private func copyBoth(_ entry: TranslationHistoryEntry) {
        let text = "\(entry.source)\n\n\(entry.target)"
        ClipboardService.copy(text)
    }
    
    private func duplicateEntry(_ entry: TranslationHistoryEntry) {
        historyStore.add(
            source: entry.source,
            target: entry.target,
            direction: entry.direction
        )
    }
}

// MARK: - History Drag Preview

struct HistoryDragPreview: View {
    let entry: TranslationHistoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.source)
                .font(.caption)
                .lineLimit(1)
            Text(entry.target)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .frame(width: 200)
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let entry: TranslationHistoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with direction and date
            HStack {
                // Direction indicator
                HStack(spacing: 4) {
                    Text(entry.direction.sourceLanguageName)
                        .font(.caption2)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    
                    Text(entry.direction.targetLanguageName)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.1))
                )
                
                Spacer()
                
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Source text
            Text(entry.source)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            // Target text
            Text(entry.target)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    HistoryTabView(selectedTab: .constant(.history))
        .environment(TranslationHistoryStore.shared)
}
