import Foundation
import ServiceManagement
import os

enum ConnectionState: Equatable {
    case disconnected
    case connected
    case error(String)
}

@MainActor
final class HelperProxy: ObservableObject {
    @Published private(set) var isHelperInstalled = false
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?

    private var connection: NSXPCConnection?
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "HelperProxy")
    private static let maxRetries = 3

    func installHelper() {
        let service = SMAppService.loginItem(identifier: HelperConstants.machServiceName)
        do {
            try service.register()
            isHelperInstalled = true
            Self.logger.info("Helper registered successfully")
        } catch {
            Self.logger.error("Helper installation failed: \(error.localizedDescription)")
            isHelperInstalled = false
            lastError = "Helper installation failed: \(error.localizedDescription)"
        }
    }

    func connectToHelper() -> HelperProtocol? {
        if connection == nil {
            Self.logger.info("Establishing XPC connection to helper")
            let conn = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
            conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
            conn.invalidationHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.connection = nil
                    self?.connectionState = .disconnected
                    Self.logger.warning("XPC connection invalidated")
                }
            }
            conn.interruptionHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.connectionState = .error("Connection interrupted")
                    Self.logger.error("XPC connection interrupted")
                }
            }
            conn.resume()
            connection = conn
            connectionState = .connected
        }
        return connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            Task { @MainActor [weak self] in
                self?.lastError = error.localizedDescription
                self?.connectionState = .error(error.localizedDescription)
                Self.logger.error("XPC proxy error: \(error.localizedDescription)")
            }
        } as? HelperProtocol
    }

    func enableCharging(reply: @escaping (Bool, String?) -> Void) {
        withRetry(operation: "enableCharging") { helper, completion in
            helper.enableCharging { success, error in
                completion(success, error)
            }
        } finalReply: { [weak self] success, error in
            if success {
                self?.lastError = nil
                Self.logger.info("Charging enabled")
            } else {
                self?.lastError = error
                Self.logger.error("Failed to enable charging: \(error ?? "unknown")")
            }
            reply(success, error)
        }
    }

    func disableCharging(reply: @escaping (Bool, String?) -> Void) {
        withRetry(operation: "disableCharging") { helper, completion in
            helper.disableCharging { success, error in
                completion(success, error)
            }
        } finalReply: { [weak self] success, error in
            if success {
                self?.lastError = nil
                Self.logger.info("Charging disabled")
            } else {
                self?.lastError = error
                Self.logger.error("Failed to disable charging: \(error ?? "unknown")")
            }
            reply(success, error)
        }
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
        connectionState = .disconnected
        Self.logger.info("XPC connection closed")
    }

    private func withRetry(
        operation: String,
        attempt: Int = 1,
        action: @escaping (HelperProtocol, @escaping (Bool, String?) -> Void) -> Void,
        finalReply: @escaping (Bool, String?) -> Void
    ) {
        guard let helper = connectToHelper() else {
            finalReply(false, "Cannot connect to helper")
            return
        }

        action(helper) { [weak self] success, error in
            Task { @MainActor [weak self] in
                if success {
                    finalReply(true, nil)
                } else if attempt < Self.maxRetries {
                    let delay = pow(2.0, Double(attempt - 1))
                    Self.logger.warning("\(operation) attempt \(attempt) failed, retrying in \(delay)s")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    self?.connection?.invalidate()
                    self?.connection = nil
                    self?.withRetry(operation: operation, attempt: attempt + 1, action: action, finalReply: finalReply)
                } else {
                    Self.logger.error("\(operation) failed after \(Self.maxRetries) attempts")
                    finalReply(false, error ?? "Failed after \(Self.maxRetries) attempts")
                }
            }
        }
    }
}
