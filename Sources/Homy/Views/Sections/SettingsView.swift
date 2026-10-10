import SwiftUI

/// Settings: folders, scanning, clean-up thresholds, privacy.
@MainActor
struct SettingsView: View {
    @Environment(FolderAccessManager.self) private var folders
    @Environment(LibraryStore.self) private var library

    @AppStorage(SettingsKey.includeApplications) private var includeApplications = true
    @AppStorage(SettingsKey.includeHiddenFiles) private var includeHiddenFiles = false
    @AppStorage(SettingsKey.largeFileThresholdMB) private var largeFileThresholdMB = 500
    @AppStorage(SettingsKey.forgottenDownloadDays) private var forgottenDownloadDays = 30
    @AppStorage(SettingsKey.oldScreenshotDays) private var oldScreenshotDays = 30
    @AppStorage(SettingsKey.unusedAppDays) private var unusedAppDays = 90
    @AppStorage(SettingsKey.autoFindDuplicates) private var autoFindDuplicates = true
    @AppStorage(SettingsKey.spotlightContentSearch) private var spotlightContentSearch = true
    @AppStorage(SettingsKey.confirmBeforeTrash) private var confirmBeforeTrash = true
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(symbol: "gear", tint: Theme.secondaryText, title: "Settings", subtitle: "Homy works entirely on your Mac")

                card(title: "Folders", symbol: "folder") {
                    VStack(alignment: .leading, spacing: 10) {
                        if folders.folders.isEmpty {
                            Text("No folders shared yet.")
                                .foregroundStyle(Theme.secondaryText)
                        }
                        ForEach(folders.folders) { folder in
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill").foregroundStyle(Theme.blue)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(folder.name).font(.system(size: 13, weight: .semibold, design: .rounded))
                                    Text(folder.path.replacingOccurrences(of: RealHome.path, with: "~"))
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                if folder.bookmark == nil {
                                    Text("No bookmark")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.orange)
                                }
                                Button(role: .destructive) {
                                    folders.remove(folder)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(Theme.red)
                                }
                                .buttonStyle(.plain)
                                .help("Stop scanning this folder")
                            }
                        }
                        HStack {
                            Button("Add Folders…") {
                                folders.pickFolders()
                            }
                            .buttonStyle(CapsuleButtonStyle())
                            Button("Rescan Now") {
                                library.rescan(roots: folders.scanRoots(includeApplications: includeApplications))
                            }
                            .buttonStyle(CapsuleButtonStyle(filled: false))
                            .disabled(library.isScanning)
                        }
                        .padding(.top, 4)
                    }
                }

                card(title: "Scanning", symbol: "magnifyingglass") {
                    Toggle("Include apps in /Applications (for Unused Apps)", isOn: $includeApplications)
                    Toggle("Include hidden files", isOn: $includeHiddenFiles)
                    Toggle("Find duplicates automatically after scanning", isOn: $autoFindDuplicates)
                    Toggle("Search inside files with Spotlight", isOn: $spotlightContentSearch)
                }

                card(title: "Clean Up", symbol: "sparkles") {
                    Stepper("Large files are bigger than \(Format.bytes(Int64(largeFileThresholdMB) * 1_000_000))",
                            value: $largeFileThresholdMB, in: 50...10_000, step: 50)
                    Stepper("Downloads are forgotten after \(forgottenDownloadDays) days",
                            value: $forgottenDownloadDays, in: 7...365, step: 7)
                    Stepper("Screenshots are old after \(oldScreenshotDays) days",
                            value: $oldScreenshotDays, in: 1...365)
                    Stepper("Apps are unused after \(unusedAppDays) days",
                            value: $unusedAppDays, in: 14...720, step: 15)
                    Toggle("Ask before moving files to the Trash", isOn: $confirmBeforeTrash)
                }

                card(title: "Privacy", symbol: "lock.shield") {
                    VStack(alignment: .leading, spacing: 8) {
                        privacyRow("person.crop.circle.badge.xmark", "No account, no sign-in")
                        privacyRow("icloud.slash", "No cloud, no uploads — files never leave your Mac")
                        privacyRow("cpu", "100% native: Spotlight, QuickLook, Vision and CryptoKit run on-device")
                        privacyRow("key", "Access only to the folders you choose, via security-scoped bookmarks")
                    }
                }

                card(title: "About", symbol: "info.circle") {
                    HStack(spacing: 14) {
                        MascotView(showsBackground: true)
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Homy").font(Theme.title(20)).foregroundStyle(Theme.navy)
                            Text("Your Mac deserves a better home for everything.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Button("Show Welcome Again") { hasOnboarded = false }
                            .buttonStyle(CapsuleButtonStyle(filled: false))
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(Color.white)
        .onChange(of: largeFileThresholdMB) { _, _ in library.rebuildIndexes() }
        .onChange(of: forgottenDownloadDays) { _, _ in library.rebuildIndexes() }
        .onChange(of: oldScreenshotDays) { _, _ in library.rebuildIndexes() }
        .onChange(of: unusedAppDays) { _, _ in library.rebuildIndexes() }
        .onChange(of: includeApplications) { _, newValue in
            library.rescan(roots: folders.scanRoots(includeApplications: newValue))
        }
    }

    private func card<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.navy)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .font(.system(size: 13, design: .rounded))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0xF7F9FC)))
    }

    private func privacyRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.green)
                .frame(width: 20)
            Text(text)
        }
    }
}
