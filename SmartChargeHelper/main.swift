import Foundation
import IOKit

let controlPath = "/tmp/smartcharge-control"
let statusPath = "/tmp/smartcharge-status"

// MARK: - SMC Struct (must match kernel layout exactly — 80 bytes)

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

// MARK: - SMC Helper

final class SMCHelper {
    private var connection: io_connect_t = 0
    private let structSize = MemoryLayout<SMCParamStruct>.size

    func open() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess
    }

    func close() {
        if connection != 0 { IOServiceClose(connection); connection = 0 }
    }

    func enableCharging() -> Bool {
        writeKey("CH0B", value: 0x00)
    }

    func disableCharging() -> Bool {
        writeKey("CH0B", value: 0x02)
    }

    func readKey(_ keyStr: String) -> UInt8? {
        var input = SMCParamStruct()
        input.key = fourCC(keyStr)
        input.data8 = 5
        input.keyInfo.dataSize = 1

        var output = SMCParamStruct()
        var outSize = structSize
        guard IOConnectCallStructMethod(connection, 2, &input, structSize, &output, &outSize) == kIOReturnSuccess else { return nil }
        return output.bytes.0
    }

    func writeKey(_ keyStr: String, value: UInt8) -> Bool {
        var input = SMCParamStruct()
        input.key = fourCC(keyStr)
        input.data8 = 6
        input.keyInfo.dataSize = 1
        input.bytes.0 = value

        var output = SMCParamStruct()
        var outSize = structSize
        return IOConnectCallStructMethod(connection, 2, &input, structSize, &output, &outSize) == kIOReturnSuccess
    }

    private func fourCC(_ s: String) -> UInt32 {
        var r: UInt32 = 0; for c in s.utf8.prefix(4) { r = (r << 8) | UInt32(c) }; return r
    }
}

// MARK: - Entry point

let smc = SMCHelper()
guard smc.open() else {
    try? "error:cannot_open_smc".write(toFile: statusPath, atomically: true, encoding: .utf8)
    fputs("Error: Cannot open AppleSMC\n", stderr)
    exit(1)
}

fputs("SMC opened. Struct size: \(MemoryLayout<SMCParamStruct>.size)\n", stderr)

if let val = smc.readKey("CH0B") {
    fputs("CH0B current value: 0x\(String(format: "%02x", val))\n", stderr)
} else {
    fputs("Warning: Cannot read CH0B\n", stderr)
}

try? FileManager.default.removeItem(atPath: controlPath)
try? FileManager.default.removeItem(atPath: statusPath)
FileManager.default.createFile(atPath: controlPath, contents: nil)
try? "ready".write(toFile: statusPath, atomically: true, encoding: .utf8)
chmod(controlPath, 0o666)
chmod(statusPath, 0o666)

fputs("SmartCharge helper running. Polling \(controlPath)\n", stderr)

signal(SIGTERM, SIG_IGN)
let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSource.setEventHandler {
    fputs("SIGTERM received — re-enabling charging\n", stderr)
    _ = smc.enableCharging()
    smc.close()
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
        let ok = smc.enableCharging()
        response = ok ? "ok:enabled" : "error:enable_failed"
        fputs("enable -> \(response)\n", stderr)
    case "disable":
        let ok = smc.disableCharging()
        response = ok ? "ok:disabled" : "error:disable_failed"
        fputs("disable -> \(response)\n", stderr)
    case "status":
        if let val = smc.readKey("CH0B") {
            response = "ok:ch0b=\(String(format: "0x%02x", val))"
        } else {
            response = "ok:ready"
        }
        fputs("status -> \(response)\n", stderr)
    default:
        response = "error:unknown"
    }

    try? response.write(toFile: statusPath, atomically: true, encoding: .utf8)
}
timer.resume()

dispatchMain()
