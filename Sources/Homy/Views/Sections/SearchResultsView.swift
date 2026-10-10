import SwiftUI

/// Natural-language search results with the "+ Understood as" pills.
@MainActor
struct SearchResultsView: View {
    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var library
    @AppStorage(SettingsKey.spotlightContentSearch) private var useSpotlight = true

    @State private var spotlight = SpotlightSearch()
    @State private var contentMatches: Set<String> = []
    @State private var isSearchingContents = false

    var body: some View {
        let query = QueryParser.parse(appState.searchText)
        let results = library.search(query, contentMatches: contentMatches)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Label("Understood as", systemImage: "plus")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(query.pills) { pill in
                                FilterPill(symbol: pill.symbol, label: pill.label)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Text("\(Format.plural(results.count, "result"))")
                            .font(Theme.title(22))
                            .contentTransition(.numericText())
                        if isSearchingContents {
                            ProgressView().controlSize(.small)
                            Text("Searching inside files with Spotlight…")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }

                FileGridView(
                    items: Array(results.prefix(600)),
                    emptyTitle: "No matches",
                    emptyMessage: "Try something like “pdfs from last week”, “large videos”, “screenshots from yesterday” or “files from WhatsApp”."
                )
            }
            .padding(28)
        }
        .background(Color.white)
        .task(id: appState.searchText) {
            contentMatches = []
            guard useSpotlight, !query.terms.isEmpty else {
                isSearchingContents = false
                return
            }
            // Debounce typing before asking Spotlight.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearchingContents = true
            let paths = await spotlight.search(terms: query.terms, scopes: library.scopeURLs)
            guard !Task.isCancelled else { return }
            contentMatches = paths
            isSearchingContents = false
        }
        .onDisappear { spotlight.cancel() }
    }
}
