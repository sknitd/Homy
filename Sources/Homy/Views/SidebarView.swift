import SwiftUI

/// Header-less sidebar with three groups: media, tools, and Settings pinned at the bottom.
@MainActor
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomyWordmark(size: 22)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SidebarItem.mediaGroup) { row($0) }
                    Spacer().frame(height: 18)
                    ForEach(SidebarItem.toolsGroup) { row($0) }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 0)

            if library.isScanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Scanning… \(Format.count(library.scannedCount))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            row(.settings)
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
        }
    }

    private func row(_ item: SidebarItem) -> some View {
        SidebarRow(
            item: item,
            isSelected: !appState.isSearching && appState.route.sidebarItem == item,
            badge: badge(for: item)
        ) {
            appState.go(.section(item))
        }
    }

    private func badge(for item: SidebarItem) -> String? {
        switch item {
        case .duplicates:
            let count = library.count(for: .duplicates)
            return count > 0 ? Format.count(count) : nil
        case .cleanUp:
            let total = library.reclaimableTotal
            return total > 0 ? Format.bytes(total) : nil
        default:
            return nil
        }
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    var badge: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.blue : Color.primary.opacity(0.7))
                    .frame(width: 22)
                Text(item.title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Theme.navy : Color.primary.opacity(0.85))
                Spacer(minLength: 4)
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.sidebarRadius, style: .continuous)
                    .fill(isSelected ? Theme.sidebarSelection : (hovering ? Color.black.opacity(0.04) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.sidebarRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
