import Foundation
import IOKit

struct SMCVersion {
    var major: UInt8
    var minor: UInt8
    var build: UInt8
    var reserved: UInt8
    var release: UInt16
}

struct SMCPLimitData {
    var version: UInt16
    var length: UInt16
    var cpuPLimit: UInt32
    var gpuPLimit: UInt32
    var memPLimit: UInt32
}

struct SMCKeyInfoData {
    var dataSize: UInt32
    var dataType: UInt32
    var dataAttributes: UInt8
}

struct SMCKeyData {
    var key: UInt32
    var vers: SMCVersion
    var pLimitData: SMCPLimitData
    var keyInfo: SMCKeyInfoData
    var result: UInt8
    var status: UInt8
    var data8: UInt8
    var data32: UInt32
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    init() {
        key = 0
        vers = SMCVersion(major: 0, minor: 0, build: 0, reserved: 0, release: 0)
        pLimitData = SMCPLimitData(version: 0, length: 0, cpuPLimit: 0, gpuPLimit: 0, memPLimit: 0)
        keyInfo = SMCKeyInfoData(dataSize: 0, dataType: 0, dataAttributes: 0)
        result = 0
        status = 0
        data8 = 0
        data32 = 0
        bytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }
}

final class SMCKit {
    private var connection: io_connect_t = 0
    private static let smcReadKey: UInt8 = 5
    private static let smcWriteKey: UInt8 = 6

    // SMC keys for charge control (Apple Silicon)
    static let chargingDisableKey = "CH0B"
    static let chargingDisableKeyAlt = "CH0C"

    func open() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        return result == kIOReturnSuccess
    }

    func close() {
        IOServiceClose(connection)
        connection = 0
    }

    func readKey(_ key: String) -> [UInt8]? {
        var inputData = SMCKeyData()
        var outputData = SMCKeyData()

        inputData.key = fourCharCode(key)
        inputData.data8 = Self.smcReadKey

        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size

        let result = IOConnectCallStructMethod(
            connection,
            2, // kSMCHandleYPCEvent
            &inputData,
            inputSize,
            &outputData,
            &outputSize
        )

        guard result == kIOReturnSuccess else { return nil }

        return withUnsafeBytes(of: outputData.bytes) { Array($0) }
    }

    func writeKey(_ key: String, value: [UInt8]) -> Bool {
        var inputData = SMCKeyData()
        inputData.key = fourCharCode(key)
        inputData.data8 = Self.smcWriteKey

        var bytes = inputData.bytes
        withUnsafeMutableBytes(of: &bytes) { buffer in
            for (i, byte) in value.enumerated() where i < buffer.count {
                buffer[i] = byte
            }
        }
        inputData.bytes = bytes

        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputData = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.size

        let result = IOConnectCallStructMethod(
            connection,
            2,
            &inputData,
            inputSize,
            &outputData,
            &outputSize
        )

        return result == kIOReturnSuccess
    }

    func enableCharging() -> Bool {
        writeKey(Self.chargingDisableKey, value: [0x00])
    }

    func disableCharging() -> Bool {
        writeKey(Self.chargingDisableKey, value: [0x02])
    }

    func isChargingEnabled() -> Bool {
        guard let data = readKey(Self.chargingDisableKey), !data.isEmpty else { return true }
        return data[0] == 0x00
    }

    private func fourCharCode(_ key: String) -> UInt32 {
        var result: UInt32 = 0
        for char in key.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
}
