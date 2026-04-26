import Foundation
import IOKit

let controlPath = "/tmp/smartcharge-control"
let statusPath = "/tmp/smartcharge-status"

// MARK: - SMC Struct (80 bytes, matching kernel layout)

struct SMCVersion { var major: UInt8 = 0; var minor: UInt8 = 0; var build: UInt8 = 0; var reserved: UInt8 = 0; var release: UInt16 = 0 }
struct SMCPLimitData { var version: UInt16 = 0; var length: UInt16 = 0; var cpuPLimit: UInt32 = 0; var gpuPLimit: UInt32 = 0; var memPLimit: UInt32 = 0 }
struct SMCKeyInfoData { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0 }
typealias SMCBytes = (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8)
struct SMCParamStruct {
    var key: UInt32 = 0; var vers = SMCVersion(); var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData(); var padding: UInt16 = 0; var result: UInt8 = 0
    var status: UInt8 = 0; var data8: UInt8 = 0; var data32: UInt32 = 0
    var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

// MARK: - Charge Controller

final class ChargeController {
    private var conn: io_connect_t = 0
    private let sz = MemoryLayout<SMCParamStruct>.size
    private var supportsTahoe = false

    func openSMC() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else { return false }

        // Detect Tahoe-era Mac (CHTE key exists)
        if smcRead("CHTE", dataSize: 4) != nil {
            supportsTahoe = true
            fputs("Detected Tahoe-era Mac (CHTE key found)\n", stderr)
        } else {
            fputs("Legacy Mac (using CH0B/CH0C)\n", stderr)
        }
        return true
    }

    func closeSMC() {
        if conn != 0 { IOServiceClose(conn); conn = 0 }
    }

    func disableCharging() -> Bool {
        if supportsTahoe {
            // CHTE: write 01 00 00 00 (4 bytes) to disable charging
            let ok = smcWrite4("CHTE", b0: 0x01, b1: 0x00, b2: 0x00, b3: 0x00)
            fputs("CHTE disable: \(ok ? "OK" : "FAIL")\n", stderr)
            return ok
        } else {
            let a = smcWrite1("CH0B", value: 0x02)
            let b = smcWrite1("CH0C", value: 0x02)
            fputs("CH0B/CH0C disable: \(a)/\(b)\n", stderr)
            return a || b
        }
    }

    func enableCharging() -> Bool {
        if supportsTahoe {
            // CHTE: write 00 00 00 00 (4 bytes) to enable charging
            let ok = smcWrite4("CHTE", b0: 0x00, b1: 0x00, b2: 0x00, b3: 0x00)
            fputs("CHTE enable: \(ok ? "OK" : "FAIL")\n", stderr)
            return ok
        } else {
            let a = smcWrite1("CH0B", value: 0x00)
            let b = smcWrite1("CH0C", value: 0x00)
            fputs("CH0B/CH0C enable: \(a)/\(b)\n", stderr)
            return a || b
        }
    }

    func readStatus() -> String {
        if supportsTahoe {
            if let data = smcRead("CHTE", dataSize: 4) {
                let hex = data.map { String(format: "%02x", $0) }.joined()
                return hex == "00000000" ? "enabled" : "disabled"
            }
            return "unknown"
        } else {
            if let data = smcRead("CH0B", dataSize: 1) {
                return data[0] == 0x00 ? "enabled" : "disabled"
            }
            return "unknown"
        }
    }

    // MARK: - SMC Low-Level

    private func fourCC(_ s: String) -> UInt32 {
        var r: UInt32 = 0; for c in s.utf8.prefix(4) { r = (r << 8) | UInt32(c) }; return r
    }

    private func smcRead(_ key: String, dataSize: UInt32) -> [UInt8]? {
        var input = SMCParamStruct()
        input.key = fourCC(key)
        input.data8 = 5 // kSMCReadKey
        input.keyInfo.dataSize = dataSize
        var output = SMCParamStruct()
        var outSize = sz
        guard IOConnectCallStructMethod(conn, 2, &input, sz, &output, &outSize) == kIOReturnSuccess else { return nil }
        return withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(dataSize))) }
    }

    private func smcWrite1(_ key: String, value: UInt8) -> Bool {
        var input = SMCParamStruct()
        input.key = fourCC(key)
        input.data8 = 6 // kSMCWriteKey
        input.keyInfo.dataSize = 1
        input.bytes.0 = value
        var output = SMCParamStruct()
        var outSize = sz
        return IOConnectCallStructMethod(conn, 2, &input, sz, &output, &outSize) == kIOReturnSuccess
    }

    private func smcWrite4(_ key: String, b0: UInt8, b1: UInt8, b2: UInt8, b3: UInt8) -> Bool {
        var input = SMCParamStruct()
        input.key = fourCC(key)
        input.data8 = 6 // kSMCWriteKey
        input.keyInfo.dataSize = 4
        input.bytes.0 = b0
        input.bytes.1 = b1
        input.bytes.2 = b2
        input.bytes.3 = b3
        var output = SMCParamStruct()
        var outSize = sz
        return IOConnectCallStructMethod(conn, 2, &input, sz, &output, &outSize) == kIOReturnSuccess
    }
}

// MARK: - Entry point

let controller = ChargeController()
guard controller.openSMC() else {
    try? "error:cannot_open_smc".write(toFile: statusPath, atomically: true, encoding: .utf8)
    fputs("Error: Cannot open AppleSMC\n", stderr)
    exit(1)
}

fputs("Current charging status: \(controller.readStatus())\n", stderr)

try? FileManager.default.removeItem(atPath: controlPath)
try? FileManager.default.removeItem(atPath: statusPath)
FileManager.default.createFile(atPath: controlPath, contents: nil)
try? "ready".write(toFile: statusPath, atomically: true, encoding: .utf8)
chmod(controlPath, 0o666)
chmod(statusPath, 0o666)

fputs("SmartCharge helper running\n", stderr)

signal(SIGTERM, SIG_IGN)
let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSource.setEventHandler {
    fputs("SIGTERM — re-enabling charging\n", stderr)
    _ = controller.enableCharging()
    controller.closeSMC()
    try? FileManager.default.removeItem(atPath: controlPath)
    try? FileManager.default.removeItem(atPath: statusPath)
    exit(0)
}
sigSource.resume()

let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now(), repeating: .milliseconds(300))
timer.setEventHandler {
    guard let data = FileManager.default.contents(atPath: controlPath),
          let command = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !command.isEmpty else { return }

    try? "".write(toFile: controlPath, atomically: false, encoding: .utf8)

    var response: String
    switch command {
    case "enable":
        response = controller.enableCharging() ? "ok:enabled" : "error:enable_failed"
    case _ where command.hasPrefix("disable"):
        response = controller.disableCharging() ? "ok:disabled" : "error:disable_failed"
    case "status":
        response = "ok:\(controller.readStatus())"
    default:
        response = "error:unknown"
    }

    try? response.write(toFile: statusPath, atomically: true, encoding: .utf8)
    fputs("\(command) -> \(response)\n", stderr)
}
timer.resume()

dispatchMain()
