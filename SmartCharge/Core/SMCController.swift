import Foundation
import os

@MainActor
final class SMCController: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published var lastError: String?

    private static let controlPath = "/tmp/smartcharge-control"
    private static let statusPath = "/tmp/smartcharge-status"
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "SMCController")
    private static let timeout: TimeInterval = 3.0

    func open() -> Bool {
        if FileManager.default.fileExists(atPath: Self.statusPath),
           let status = try? String(contentsOfFile: Self.statusPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           status == "ready" || status.hasPrefix("ok:") {
            isAvailable = true
            Self.logger.info("Helper is ready")
            return true
        }
        Self.logger.error("Helper not responding — status file missing or not ready")
        lastError = "SmartCharge helper is not running. Please reinstall using the .pkg installer."
        isAvailable = false
        return false
    }

    func close() {
        isAvailable = false
    }

    func enableCharging() -> Bool {
        sendCommand("enable")
    }

    func disableCharging() -> Bool {
        sendCommand("disable")
    }

    func isChargingEnabled() -> Bool {
        guard sendCommand("status") else { return true }
        return true
    }

    private func sendCommand(_ command: String) -> Bool {
        guard FileManager.default.fileExists(atPath: Self.controlPath) else {
            Self.logger.error("Control file does not exist — helper not running")
            lastError = "Helper not running. Reinstall via .pkg installer."
            return false
        }

        do {
            try command.write(toFile: Self.controlPath, atomically: true, encoding: .utf8)
        } catch {
            Self.logger.error("Failed to write command: \(error.localizedDescription)")
            lastError = "Cannot send command to helper"
            return false
        }

        // Wait for response
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline {
            if let data = FileManager.default.contents(atPath: Self.statusPath),
               let response = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !response.isEmpty {
                if response.hasPrefix("ok:") {
                    Self.logger.info("Command '\(command)' succeeded: \(response)")
                    lastError = nil
                    return true
                } else if response.hasPrefix("error:") {
                    Self.logger.error("Command '\(command)' failed: \(response)")
                    lastError = "Helper error: \(response)"
                    return false
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        Self.logger.error("Command '\(command)' timed out")
        lastError = "Helper did not respond in time"
        return false
    }
}
