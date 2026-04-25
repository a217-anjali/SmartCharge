import Foundation
import os

// TODO: Replace with Sparkle framework integration. Add SPM dependency: https://github.com/sparkle-project/Sparkle

@MainActor
final class SparkleUpdateManager: ObservableObject {

    @Published var canCheckForUpdates = true

    @Published var automaticUpdatesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticUpdatesEnabled, forKey: Self.defaultsKey)
        }
    }

    private let updateChecker = UpdateChecker()
    private static let defaultsKey = "AutomaticUpdatesEnabled"
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "SparkleUpdateManager")

    // MARK: - Init

    init() {
        self.automaticUpdatesEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    // MARK: - Actions

    /// Checks for available updates by querying the GitHub Releases API.
    ///
    /// This is a temporary implementation using the existing `UpdateChecker`.
    /// Once Sparkle is integrated, this method should delegate to
    /// `SPUUpdater.checkForUpdates()` instead.
    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        canCheckForUpdates = false

        Self.logger.info("Checking for updates via GitHub API (Sparkle stub)")
        updateChecker.checkForUpdate()

        // Re-enable the button after a short delay to prevent rapid clicks
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            canCheckForUpdates = true
        }
    }

    /// The latest available version string, if an update was found.
    var updateAvailable: String? {
        updateChecker.updateAvailable
    }

    /// Whether an update check is currently in progress.
    var isChecking: Bool {
        updateChecker.isChecking
    }

    /// URL to the latest release page on GitHub.
    var releaseURL: URL {
        updateChecker.releaseURL
    }
}
