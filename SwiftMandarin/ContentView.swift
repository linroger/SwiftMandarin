//
//  ContentView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            Group {
                if items.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(items) { item in
                            ItemRow(item: item)
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .navigationTitle("Swift Mandarin")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        NavigationLink {
            Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
        } label: {
            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Items", systemImage: "tray")
        } description: {
            Text("Tap the plus button to add a new item.")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
