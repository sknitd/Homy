import SwiftUI

/// First-launch welcome: what Homy is, privacy promises, and folder access.
@MainActor
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(FolderAccessManager.self) private var folders
    @State private var page = 0
    @State private var blink = false
    @State private var bob = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xF5FAFF), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    if page == 0 {
                        welcome.transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
                    } else {
                        access.transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Theme.blue : Color.black.opacity(0.12))
                            .frame(width: index == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(), value: page)
                .padding(.bottom, 28)
            }
        }
        .task {
            // Gentle idle animation: bobbing and the occasional blink.
            bob = true
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.2))
                blink = true
                try? await Task.sleep(for: .milliseconds(140))
                blink = false
            }
        }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 22) {
            MascotView(eyesClosed: blink)
                .frame(width: 220, height: 186)
                .offset(y: bob ? -6 : 6)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: bob)

            VStack(spacing: 8) {
                Text("Welcome to Homy")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.navy)
                Text("Your Mac deserves a better home for everything.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            HStack(spacing: 14) {
                feature("square.grid.2x2.fill", Theme.blue, "All in one place", "Photos, videos, music and documents, neatly sorted.")
                feature("magnifyingglass", Color(hex: 0x7D54FA), "Find anything", "Search like you talk: “pdfs from last week”.")
                feature("sparkles", Theme.green, "Stay tidy", "Duplicates, old screenshots and forgotten downloads.")
            }
            .frame(maxWidth: 760)

            HStack(spacing: 18) {
                promise("person.crop.circle.badge.xmark", "No account")
                promise("icloud.slash", "No cloud")
                promise("hand.raised.fill", "No uploads")
                promise("apple.logo", "100% native")
            }
            .padding(.top, 4)

            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { page = 1 }
            } label: {
                Text("Get Started")
                    .frame(minWidth: 160)
            }
            .buttonStyle(CapsuleButtonStyle())
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 8)
        }
        .padding(40)
    }

    private var access: some View {
        VStack(spacing: 20) {
            MascotView(eyesClosed: blink)
                .frame(width: 120, height: 102)
            VStack(spacing: 6) {
                Text("Which folders should Homy tidy?")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.navy)
                Text("Homy only sees the folders you choose. Access is remembered with secure bookmarks, and nothing ever leaves your Mac.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(FolderAccessManager.suggestedFolderNames, id: \.self) { name in
                    folderRow(name)
                }
            }
            .frame(maxWidth: 720)

            HStack(spacing: 12) {
                Button("Choose Other Folders…") {
                    folders.pickFolders()
                }
                .buttonStyle(CapsuleButtonStyle(filled: false))

                Button {
                    onFinish()
                } label: {
                    Text(folders.hasAnyFolder ? "Start Exploring" : "Skip for Now")
                        .frame(minWidth: 140)
                }
                .buttonStyle(CapsuleButtonStyle())
                .keyboardShortcut(.defaultAction)
            }

            let extraFolders = folders.folders.filter { folder in
                !FolderAccessManager.suggestedFolderNames.contains { RealHome.folder($0).path == folder.path }
            }
            if !extraFolders.isEmpty {
                Text("Also sharing: " + extraFolders.map(\.name).joined(separator: ", "))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(40)
    }

    // MARK: Pieces

    private func folderRow(_ name: String) -> some View {
        let granted = folders.isGranted(suggested: name)
        return Button {
            if !granted { folders.grantSuggested(name) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol(for: name))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(granted ? Color.white : Theme.blue)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(granted ? Theme.blue : Theme.lightBlue))
                Text(name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.navy)
                Spacer()
                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Grant")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.lightBlue))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
            .softShadow(radius: 10, y: 4, opacity: 0.07)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35), value: granted)
    }

    private func symbol(for folder: String) -> String {
        switch folder {
        case "Pictures": "photo.on.rectangle"
        case "Movies": "film"
        case "Music": "music.note"
        case "Documents": "doc.text"
        case "Downloads": "arrow.down.circle"
        case "Desktop": "menubar.dock.rectangle"
        default: "folder"
        }
    }

    private func feature(_ symbol: String, _ tint: Color, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint))
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.navy)
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
        .softShadow(radius: 14, y: 6, opacity: 0.07)
    }

    private func promise(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.navy.opacity(0.75))
    }
}
