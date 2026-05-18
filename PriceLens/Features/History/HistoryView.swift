import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var history: ScanHistoryStore
    @StateObject private var viewModel = HistoryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if history.items.isEmpty {
                    EmptyStateView(title: "No saved scans", message: "Open a detected price and save it to keep it here.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(viewModel.grouped(history.items), id: \.0) { section, items in
                                Text(section).font(.caption.bold()).foregroundStyle(AppTheme.textSecondary).padding(.horizontal)
                                VStack(spacing: 0) {
                                    ForEach(items) { item in
                                        HistoryRowView(item: item)
                                        if item.id != items.last?.id { Divider().overlay(AppTheme.border) }
                                    }
                                }
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Clear") { history.clear() }.disabled(history.items.isEmpty) }
            }
        }
    }
}

