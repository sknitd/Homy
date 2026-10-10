import SwiftUI

@main
struct HomyApp: App {
    @State private var appState: AppState
    @State private var folders: FolderAccessManager
    @State private var library: LibraryStore

    init() {
        SettingsKey.registerDefaults()
        _appState = State(initialValue: AppState())
        _folders = State(initialValue: FolderAccessManager())
        _library = State(initialValue: LibraryStore())
    }

    var body: some Scene {
        WindowGroup("Homy") {
            RootView()
                .environment(appState)
                .environment(folders)
                .environment(library)
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1260, height: 820)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            HomyCommands(appState: appState, folders: folders, library: library)
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(folders)
                .environment(library)
                .frame(width: 680, height: 720)
                .preferredColorScheme(.light)
        }
    }
}

struct HomyCommands: Commands {
    let appState: AppState
    let folders: FolderAccessManager
    let library: LibraryStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Folders…") { folders.pickFolders() }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .textEditing) {
            Button("Search…") { appState.requestSearchFocus() }
                .keyboardShortcut("f")
        }
        CommandMenu("Library") {
            Button("Rescan") {
                library.rescan(roots: folders.scanRoots(
                    includeApplications: UserDefaults.standard.bool(forKey: SettingsKey.includeApplications)
                ))
            }
            .keyboardShortcut("r")
            Button("Find Duplicates") { library.findDuplicates() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button("Back") { appState.goBack() }
                .keyboardShortcut("[")
            Button("Forward") { appState.goForward() }
                .keyboardShortcut("]")
            Divider()
            ForEach(Array((SidebarItem.mediaGroup + SidebarItem.toolsGroup).enumerated()), id: \.element) { pair in
                if pair.offset < 9 {
                    Button(pair.element.title) { appState.go(.section(pair.element)) }
                        .keyboardShortcut(KeyEquivalent(Character("\(pair.offset + 1)")))
                } else {
                    Button(pair.element.title) { appState.go(.section(pair.element)) }
                }
            }
        }
    }
}
