import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var updateAvailable: String?

    private let currentVersion: String
    private let repoOwner = "a217-anjali"
    private let repoName = "SmartCharge"

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func checkForUpdate() {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }

            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isNewer(latestVersion, than: self.currentVersion) {
                    self.updateAvailable = latestVersion
                }
            }
        }.resume()
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
