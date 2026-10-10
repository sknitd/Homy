import Foundation

/// UserDefaults keys shared by `@AppStorage` views and the library store.
enum SettingsKey {
    static let hasOnboarded = "hasOnboarded"
    static let includeApplications = "includeApplications"
    static let includeHiddenFiles = "includeHiddenFiles"
    static let largeFileThresholdMB = "largeFileThresholdMB"
    static let forgottenDownloadDays = "forgottenDownloadDays"
    static let oldScreenshotDays = "oldScreenshotDays"
    static let unusedAppDays = "unusedAppDays"
    static let autoFindDuplicates = "autoFindDuplicates"
    static let spotlightContentSearch = "spotlightContentSearch"
    static let confirmBeforeTrash = "confirmBeforeTrash"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            hasOnboarded: false,
            includeApplications: true,
            includeHiddenFiles: false,
            largeFileThresholdMB: 500,
            forgottenDownloadDays: 30,
            oldScreenshotDays: 30,
            unusedAppDays: 90,
            autoFindDuplicates: true,
            spotlightContentSearch: true,
            confirmBeforeTrash: true,
        ])
    }

    static var defaults: UserDefaults { .standard }
}
