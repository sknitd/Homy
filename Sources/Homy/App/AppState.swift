import SwiftUI
import Observation

/// A transient confirmation shown at the bottom of the window.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    var symbol: String = "checkmark.circle.fill"
    var title: String
    var detail: String?
    var isError = false
}

/// Navigation, search, and transient UI state for the main window.
@Observable
@MainActor
final class AppState {
    private(set) var route: Route = .section(.library)
    private var backStack: [Route] = []
    private var forwardStack: [Route] = []

    var searchText = ""
    var toast: Toast?
    var showingStorageChart = false
    /// Incremented to ask the toolbar search field to take focus (⌘F).
    private(set) var searchFocusRequest = 0

    @ObservationIgnored private var toastTask: Task<Void, Never>?

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    func go(_ destination: Route) {
        if isSearching { searchText = "" }
        guard destination != route else { return }
        backStack.append(route)
        forwardStack.removeAll()
        route = destination
    }

    func goBack() {
        if isSearching {
            searchText = ""
            return
        }
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(route)
        route = previous
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(route)
        route = next
    }

    func requestSearchFocus() {
        searchFocusRequest += 1
    }

    func showToast(_ toast: Toast, duration: Duration = .seconds(3.5)) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.toast = toast
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.toast = nil
            }
        }
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }
}
