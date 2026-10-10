import SwiftUI

/// Main window: onboarding on first launch, then the sidebar + detail layout.
@MainActor
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var library
    @Environment(FolderAccessManager.self) private var folders

    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(SettingsKey.includeApplications) private var includeApplications = true
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            if hasOnboarded {
                mainWindow
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) { hasOnboarded = true }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
    }

    private var mainWindow: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 280)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .overlay(alignment: .bottom) {
                    if let toast = appState.toast {
                        ToastView(toast: toast)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .toolbar { toolbarContent }
        }
        .toolbar(removing: .title)
        .onAppear {
            if !library.hasScanned && !library.isScanning { rescan() }
        }
        .onChange(of: folders.folders) { _, _ in rescan() }
        .onChange(of: appState.searchFocusRequest) { _, _ in searchFocused = true }
    }

    private func rescan() {
        library.rescan(roots: folders.scanRoots(includeApplications: includeApplications))
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if appState.isSearching {
            SearchResultsView()
        } else if !folders.hasAnyFolder && appState.route != .section(.settings) {
            EmptyStateView(
                title: "Let Homy move in",
                message: "Choose the folders you'd like Homy to organize — like Pictures, Documents and Downloads. Nothing leaves your Mac."
            ) {
                HStack {
                    Button("Choose Folders…") { folders.pickFolders() }
                        .buttonStyle(CapsuleButtonStyle())
                    Button("Show Welcome") { hasOnboarded = false }
                        .buttonStyle(CapsuleButtonStyle(filled: false))
                }
            }
        } else {
            switch appState.route {
            case .section(let item):
                switch item {
                case .library: LibraryView()
                case .images, .videos, .music, .documents: CategoryView(category: item.category ?? .other)
                case .largeFiles: LargeFilesView()
                case .downloads: DownloadsView()
                case .duplicates: DuplicatesView()
                case .screenshots: ScreenshotsView()
                case .cleanUp: CleanUpView()
                case .settings: SettingsView()
                }
            case .category(let category):
                CategoryView(category: category)
            case .source(let name):
                SourceView(source: name)
            case .cleanup(let kind):
                switch kind {
                case .duplicates: DuplicatesView()
                case .largeFiles: LargeFilesView()
                default: CleanupListView(kind: kind)
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                appState.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("Back")
            .disabled(!appState.canGoBack && !appState.isSearching)

            Button {
                appState.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("Forward")
            .disabled(!appState.canGoForward)

            Text(appState.greeting)
                .font(Theme.title(20))
                .foregroundStyle(Theme.navy)
                .padding(.leading, 6)
                .fixedSize()
        }

        ToolbarItem(placement: .principal) {
            SearchCapsule(
                text: Binding(get: { appState.searchText }, set: { appState.searchText = $0 }),
                focused: $searchFocused
            )
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Text("Library size: \(Format.gigabytes(library.totalSize))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()
                .fixedSize()

            Button {
                rescan()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .symbolEffect(.pulse, isActive: library.isScanning)
            }
            .help(library.isScanning ? "Scanning…" : "Rescan your folders")
            .disabled(library.isScanning)

            Button {
                appState.showingStorageChart.toggle()
            } label: {
                Image(systemName: "chart.pie")
            }
            .help("Library breakdown")
            .popover(
                isPresented: Binding(get: { appState.showingStorageChart }, set: { appState.showingStorageChart = $0 }),
                arrowEdge: .bottom
            ) {
                StorageChartView()
            }
        }
    }
}

/// The centered search capsule in the toolbar.
struct SearchCapsule: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search", text: $text, prompt: Text("Search, or try “pdfs from last week”"))
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
                .focused(focused)
                .onExitCommand { text = "" }
            if text.isEmpty {
                Keycap(text: "⌘F")
            } else {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 420, height: 30)
        .background(Capsule().fill(Color(hex: 0xF1F3F6)))
        .overlay(Capsule().strokeBorder(Color.black.opacity(0.05)))
    }
}
