import SwiftUI

/// Byte-identical files, grouped by SHA-256, with Keep / Trash choices per copy.
@MainActor
struct DuplicatesView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AppState.self) private var appState
    @State private var confirmAll = false

    var body: some View {
        let groups = library.duplicateGroups
        let extra = groups.reduce(0) { $0 + $1.extraCopies }
        let wasted = groups.reduce(Int64(0)) { $0 + $1.wastedBytes }
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    symbol: "square.on.square",
                    tint: Theme.red,
                    title: "Duplicates",
                    subtitle: library.hasScannedDuplicates
                        ? "\(Format.plural(groups.count, "group")) · \(Format.plural(extra, "extra copy", "extra copies")) · \(Format.bytes(wasted)) to free"
                        : "Matching files byte-for-byte with SHA-256"
                ) {
                    HStack(spacing: 10) {
                        Button {
                            library.findDuplicates()
                        } label: {
                            Label("Scan Again", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(CapsuleButtonStyle(tint: Theme.blue, filled: false))
                        .disabled(library.isFindingDuplicates || library.isScanning)
                        if !groups.isEmpty {
                            Button("Trash All Extras") { confirmAll = true }
                                .buttonStyle(CapsuleButtonStyle(tint: Theme.red))
                        }
                    }
                }

                if library.isFindingDuplicates {
                    HashingProgress(progress: library.duplicateProgress)
                }

                if groups.isEmpty && !library.isFindingDuplicates {
                    EmptyStateView(
                        title: library.hasScannedDuplicates ? "No duplicates" : "Looking for duplicates",
                        message: library.hasScannedDuplicates
                            ? "Every file in your folders is one of a kind. Nice and tidy!"
                            : "Homy compares files of the same size using SHA-256 fingerprints."
                    ) {
                        if !library.hasScannedDuplicates {
                            Button("Find Duplicates") { library.findDuplicates() }
                                .buttonStyle(CapsuleButtonStyle())
                        }
                    }
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(groups) { group in
                            DuplicateGroupCard(group: group)
                                .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.9).combined(with: .opacity)))
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: groups.map(\.id))
                }
            }
            .padding(28)
        }
        .background(Color.white)
        .confirmationDialog(
            "Move \(Format.plural(extra, "extra copy", "extra copies")) to the Trash?",
            isPresented: $confirmAll,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                let targets = groups.flatMap { group -> [FileItem] in
                    let keep = group.suggestedKeep?.path
                    return group.items.filter { $0.path != keep }
                }
                FileActions.trash(targets, library: library, appState: appState)
            }
        } message: {
            Text("Homy keeps the oldest copy of each file and frees \(Format.bytes(wasted)). You can restore files from the Trash.")
        }
    }
}

struct HashingProgress: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "number.square.fill").foregroundStyle(Theme.blue)
                Text("Comparing fingerprints with SHA-256…")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.blue)
            }
            ProgressView(value: progress)
                .tint(Theme.blue)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.lightBlue))
    }
}

/// One duplicate set: polaroid thumbnails with Keep/Trash badges and a merge animation.
@MainActor
struct DuplicateGroupCard: View {
    let group: DuplicateGroup

    @Environment(LibraryStore.self) private var library
    @Environment(AppState.self) private var appState
    @State private var keepPaths: Set<String> = []
    @State private var confirming = false
    @State private var merging = false
    @State private var matched = false

    private let cardWidth: CGFloat = 168
    private let spacing: CGFloat = 20

    private var trashItems: [FileItem] { group.items.filter { !keepPaths.contains($0.path) } }
    private var keepIndex: Int { group.items.firstIndex { keepPaths.contains($0.path) } ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.items.first?.name ?? "Duplicate")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                    Text("\(group.items.count) identical copies · \(Format.bytes(group.fileSize)) each · SHA-256 \(group.shortHash)…")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Button {
                    confirming = true
                } label: {
                    Label(
                        trashItems.isEmpty ? "Keeping all" : "Trash \(trashItems.count) · free \(Format.bytes(Int64(trashItems.count) * group.fileSize))",
                        systemImage: "sparkles"
                    )
                }
                .buttonStyle(CapsuleButtonStyle(tint: Theme.red))
                .disabled(trashItems.isEmpty || merging)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { pair in
                        let index = pair.offset
                        let item = pair.element
                        let keep = keepPaths.contains(item.path)
                        PolaroidCard(
                            item: item,
                            keep: keep,
                            width: cardWidth,
                            tilt: index.isMultiple(of: 2) ? -1.5 : 1.5,
                            showsMatch: matched && keep
                        ) {
                            toggle(item)
                        }
                        .zIndex(keep ? 1 : 0)
                        .offset(x: merging && !keep ? CGFloat(keepIndex - index) * (cardWidth + spacing) : 0)
                        .scaleEffect(merging && !keep ? 0.55 : 1)
                        .rotationEffect(.degrees(merging && !keep ? Double(keepIndex - index) * 8 : 0))
                        .opacity(merging && !keep ? 0 : 1)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: 0xFFF7F7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.red.opacity(0.08))
        )
        .onAppear(perform: resetKeep)
        .onChange(of: group) { _, _ in resetKeep() }
        .confirmationDialog(
            "Move \(Format.plural(trashItems.count, "copy", "copies")) to the Trash?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { mergeAndTrash() }
        } message: {
            Text("The files are identical (SHA-256 match). The copy marked Keep stays where it is; the others go to the Trash, where you can restore them.")
        }
    }

    private func resetKeep() {
        let alive = Set(group.items.map(\.path))
        let current = keepPaths.intersection(alive)
        if current.isEmpty, let keep = group.suggestedKeep {
            keepPaths = [keep.path]
        } else {
            keepPaths = current
        }
    }

    private func toggle(_ item: FileItem) {
        guard !merging else { return }
        if keepPaths.contains(item.path) {
            // Always keep at least one copy.
            guard keepPaths.count > 1 else { return }
            keepPaths.remove(item.path)
        } else {
            keepPaths.insert(item.path)
        }
    }

    private func mergeAndTrash() {
        let targets = trashItems
        guard !targets.isEmpty else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
            merging = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                matched = true
            }
            try? await Task.sleep(for: .milliseconds(900))
            FileActions.trash(targets, library: library, appState: appState)
            // If some files couldn't be trashed, bring the cards back.
            withAnimation(.spring()) {
                merging = false
                matched = false
            }
        }
    }
}

/// Polaroid-style thumbnail with path, size, and a Keep/Trash badge.
struct PolaroidCard: View {
    let item: FileItem
    let keep: Bool
    let width: CGFloat
    var tilt: Double = 0
    var showsMatch = false
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThumbnailView(url: item.url, side: 240, contentMode: item.isImage || item.category == .videos ? .fill : .fit)
                .frame(width: width - 16, height: width - 16)
                .background(Color(hex: 0xF4F5F7))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .center) {
                    if showsMatch {
                        Text("SHA-256 MATCH")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.green))
                            .softShadow(radius: 8, y: 3, opacity: 0.25)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayFolder)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.navy)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text("\(Format.bytes(item.size)) · \(Format.date(item.created))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 6)
        }
        .padding(8)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
        .softShadow(radius: 10, y: 5, opacity: 0.12)
        .overlay(alignment: .topTrailing) {
            Button(action: onToggle) {
                HStack(spacing: 4) {
                    Image(systemName: keep ? "checkmark" : "trash")
                    Text(keep ? "Keep" : "Trash")
                }
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(keep ? Theme.green : Theme.red))
                .softShadow(radius: 4, y: 2, opacity: 0.2)
            }
            .buttonStyle(.plain)
            .offset(x: 8, y: -8)
            .help(keep ? "Click to trash this copy" : "Click to keep this copy")
        }
        .rotationEffect(.degrees(tilt))
        .onTapGesture(count: 2) { FileActions.open(item) }
        .contextMenu {
            Button("Open") { FileActions.open(item) }
            Button("Show in Finder") { FileActions.reveal([item]) }
            Button(keep ? "Mark as Trash" : "Mark as Keep") { onToggle() }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: keep)
    }
}
