import Foundation

@objc protocol HelperProtocol {
    func enableCharging(reply: @escaping (Bool, String?) -> Void)
    func disableCharging(reply: @escaping (Bool, String?) -> Void)
    func isChargingEnabled(reply: @escaping (Bool) -> Void)
    func getChargingStatus(reply: @escaping (Bool, Bool, Int) -> Void) // isEnabled, isPluggedIn, batteryLevel
}

enum HelperConstants {
    static let machServiceName = "com.smartcharge.helper"
}
