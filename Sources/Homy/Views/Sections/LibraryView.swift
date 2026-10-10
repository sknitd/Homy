import SwiftUI

/// Home screen: folder-shaped category cards, Clean Up suggestions, and "Downloaded From".
@MainActor
struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var library

    private let cardColumns = [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 22)]
    private let pillColumns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                if library.isScanning && !library.hasScanned {
                    ScanningBanner(count: library.scannedCount)
                }

                LazyVGrid(columns: cardColumns, spacing: 22) {
                    ForEach(FileCategory.libraryCards) { category in
                        Button {
                            appState.go(.category(category))
                        } label: {
                            LibraryCardView(category: category, stat: library.stats[category] ?? CategoryStat())
                        }
                        .buttonStyle(.plain)
                    }
                }

                cleanUpSection
                downloadedFromSection
            }
            .padding(28)
        }
        .scrollContentBackground(.hidden)
        .background(Color.white)
    }

    // MARK: Clean Up

    private var cleanUpSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Clean Up",
                subtitle: library.hasScanned ? "Free up to \(Format.gigabytes(library.reclaimableTotal))" : "Scanning your folders…"
            ) {
                SeeAllButton { appState.go(.section(.cleanUp)) }
            }
            LazyVGrid(columns: pillColumns, spacing: 14) {
                ForEach([CleanupKind.duplicates, .forgottenDownloads, .oldScreenshots, .unusedApps]) { kind in
                    CleanUpPillCard(
                        kind: kind,
                        count: library.count(for: kind),
                        bytes: library.reclaimableBytes(for: kind),
                        isWorking: kind == .duplicates && library.isFindingDuplicates
                    ) {
                        appState.go(kind == .duplicates ? .section(.duplicates) : .cleanup(kind))
                    }
                }
            }
        }
    }

    // MARK: Downloaded From

    private var downloadedFromSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Downloaded From", subtitle: "Where your downloads came from") {
                SeeAllButton(title: "Downloads") { appState.go(.section(.downloads)) }
            }
            if library.sources.isEmpty {
                Text(library.hasScanned
                     ? "No download sources found yet. Files downloaded with Safari, Chrome, Slack, WhatsApp and others will appear here."
                     : "Looking at where your files came from…")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                FlowLayout(spacing: 10, lineSpacing: 12) {
                    ForEach(library.sources) { source in
                        SourcePill(source: source) {
                            appState.go(.source(source.name))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Library card

struct LibraryCardView: View {
    let category: FileCategory
    let stat: CategoryStat

    @State private var hovering = false

    private let tabHeight: CGFloat = 30

    var body: some View {
        let shape = FolderCardShape(tabWidthRatio: 0.42, tabHeight: tabHeight, cornerRadius: Theme.cardRadius)
        ZStack(alignment: .topLeading) {
            shape.fill(category.background)

            // Icon + title sit on the raised tab.
            HStack(spacing: 7) {
                Image(systemName: category.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(category.tint)
                Text(category.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.navy)
            }
            .padding(.leading, 16)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Text(Format.bytes(stat.size))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(category.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white))
                        .softShadow(radius: 4, y: 1, opacity: 0.06)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Format.count(stat.count))
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.navy)
                            .contentTransition(.numericText())
                        Text(stat.count == 1 ? "item" : "items")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.navy.opacity(0.55))
                    }
                    Spacer()
                    ThumbnailStack(items: stat.recent, category: category, spread: hovering)
                }
            }
            .padding(.top, tabHeight + 12)
            .padding([.horizontal, .bottom], 16)
        }
        .frame(height: 178)
        .contentShape(shape)
        .softShadow(radius: hovering ? 18 : 10, y: hovering ? 9 : 4, opacity: hovering ? 0.1 : 0.05)
        .offset(y: hovering ? -2 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hovering)
        .onHover { hovering = $0 }
    }
}

/// Three overlapping, slightly rotated thumbnails.
struct ThumbnailStack: View {
    let items: [FileItem]
    let category: FileCategory
    var spread = false

    var body: some View {
        ZStack {
            if items.isEmpty {
                ForEach(0..<3, id: \.self) { index in
                    placeholder
                        .rotationEffect(.degrees(Double(index - 1) * 8))
                        .offset(x: CGFloat(index - 1) * 16)
                }
            } else {
                ForEach(Array(items.prefix(3).enumerated().reversed()), id: \.offset) { pair in
                    let index = pair.offset
                    ThumbnailView(url: pair.element.url, side: 120, contentMode: .fill)
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.white, lineWidth: 2.5)
                        )
                        .softShadow(radius: 6, y: 3, opacity: 0.14)
                        .rotationEffect(.degrees(Double(index) * (spread ? -10 : -6) + 6))
                        .offset(x: CGFloat(index) * (spread ? -26 : -18), y: CGFloat(index) * -2)
                }
            }
        }
        .frame(width: 110, height: 72, alignment: .trailing)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.white.opacity(0.7))
            .frame(width: 52, height: 52)
            .overlay(
                Image(systemName: category.symbol)
                    .foregroundStyle(category.tint.opacity(0.35))
            )
    }
}

// MARK: - Clean Up pill card

struct CleanUpPillCard: View {
    let kind: CleanupKind
    let count: Int
    let bytes: Int64
    var isWorking = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(kind.tint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy)
                    Text(isWorking ? "Checking…" : Format.bytes(bytes))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    if isWorking {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text(kind.actionLabel(count: count))
                    }
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(kind.tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white))
                .softShadow(radius: 4, y: 1, opacity: 0.06)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Capsule().fill(kind.background))
            .scaleEffect(hovering ? 1.01 : 1)
            .animation(.spring(response: 0.3), value: hovering)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Source pill

struct SourcePill: View {
    let source: SourceStat
    var isSelected = false
    let action: () -> Void

    var body: some View {
        let style = DownloadSource.style(for: source.name)
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: style.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(style.color))
                Text(source.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : Theme.navy)
                Text(Format.count(source.count))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Theme.secondaryText)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? Theme.blue : Color.white))
            .softShadow(radius: 8, y: 3, opacity: 0.08)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Shown on first scan.
struct ScanningBanner: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text("Tidying up… found \(Format.plural(count, "file")) so far")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.navy)
                .contentTransition(.numericText())
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.lightBlue))
    }
}
