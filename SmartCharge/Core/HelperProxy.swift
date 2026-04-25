import Foundation
import ServiceManagement

@MainActor
final class HelperProxy: ObservableObject {
    @Published private(set) var isHelperInstalled = false

    private var connection: NSXPCConnection?

    func installHelper() {
        let service = SMAppService.loginItem(identifier: HelperConstants.machServiceName)
        do {
            try service.register()
            isHelperInstalled = true
        } catch {
            print("Helper installation failed: \(error)")
            isHelperInstalled = false
        }
    }

    func connectToHelper() -> HelperProtocol? {
        if connection == nil {
            let conn = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
            conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
            conn.invalidationHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.connection = nil
                }
            }
            conn.resume()
            connection = conn
        }
        return connection?.remoteObjectProxyWithErrorHandler { error in
            print("XPC error: \(error)")
        } as? HelperProtocol
    }

    func enableCharging(reply: @escaping (Bool, String?) -> Void) {
        guard let helper = connectToHelper() else {
            reply(false, "Cannot connect to helper")
            return
        }
        helper.enableCharging(reply: reply)
    }

    func disableCharging(reply: @escaping (Bool, String?) -> Void) {
        guard let helper = connectToHelper() else {
            reply(false, "Cannot connect to helper")
            return
        }
        helper.disableCharging(reply: reply)
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
    }
}
