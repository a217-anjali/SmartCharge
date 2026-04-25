import Foundation
import os

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var updateAvailable: String?
    @Published var isChecking = false
    @Published var checkError: String?

    private let repoOwner = "a217-anjali"
    private let repoName = "SmartCharge"
    private var currentTask: URLSessionDataTask?
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "UpdateChecker")

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func checkForUpdate() {
        guard !isChecking else { return }
        isChecking = true
        checkError = nil

        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        Self.logger.info("Checking for updates (current: v\(self.appVersion))")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isChecking = false
                self.currentTask = nil

                if let error = error {
                    if (error as NSError).code == NSURLErrorCancelled { return }
                    self.checkError = error.localizedDescription
                    Self.logger.error("Update check failed: \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.checkError = "Invalid response from GitHub"
                    Self.logger.error("Update check: invalid API response")
                    return
                }

                let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                if self.isNewer(latestVersion, than: self.appVersion) {
                    self.updateAvailable = latestVersion
                    Self.logger.info("Update available: v\(latestVersion)")
                } else {
                    self.updateAvailable = nil
                    Self.logger.info("App is up to date")
                }
            }
        }
        currentTask = task
        task.resume()
    }

    func cancelCheck() {
        currentTask?.cancel()
        currentTask = nil
        isChecking = false
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }

    var releaseURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")!
    }
}
