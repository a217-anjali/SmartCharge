import Foundation
import IOKit.ps

final class HelperToolDelegate: NSObject, NSXPCListenerDelegate, HelperProtocol {
    private let smc = SMCKit()
    private var smcReady = false

    override init() {
        super.init()
        smcReady = smc.open()
        if !smcReady {
            print("Warning: Could not connect to SMC")
        }
    }

    deinit {
        if smcReady {
            _ = smc.enableCharging()
            smc.close()
        }
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    // MARK: - HelperProtocol

    func enableCharging(reply: @escaping (Bool, String?) -> Void) {
        guard smcReady else {
            reply(false, "SMC not available")
            return
        }
        let success = smc.enableCharging()
        reply(success, success ? nil : "Failed to write SMC key")
    }

    func disableCharging(reply: @escaping (Bool, String?) -> Void) {
        guard smcReady else {
            reply(false, "SMC not available")
            return
        }
        let success = smc.disableCharging()
        reply(success, success ? nil : "Failed to write SMC key")
    }

    func isChargingEnabled(reply: @escaping (Bool) -> Void) {
        guard smcReady else {
            reply(true)
            return
        }
        reply(smc.isChargingEnabled())
    }

    func getChargingStatus(reply: @escaping (Bool, Bool, Int) -> Void) {
        let isEnabled = smcReady ? smc.isChargingEnabled() : true

        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        guard let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            reply(isEnabled, false, -1)
            return
        }

        let level = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
        let powerSource = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        let isPluggedIn = powerSource == kIOPSACPowerValue

        reply(isEnabled, isPluggedIn, level)
    }
}

// MARK: - Entry point

let delegate = HelperToolDelegate()
let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()

signal(SIGTERM, SIG_IGN)
let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigTermSource.setEventHandler {
    delegate.enableCharging { _, _ in }
    exit(0)
}
sigTermSource.resume()

RunLoop.main.run()
