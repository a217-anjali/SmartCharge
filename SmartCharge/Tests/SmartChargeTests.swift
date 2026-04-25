import XCTest
@testable import SmartCharge

// MARK: - ChargeConfig Tests

final class ChargeConfigTests: XCTestCase {

    // MARK: Default config

    func testDefaultConfig() {
        let config = ChargeConfig.default
        XCTAssertEqual(config.chargeStartThreshold, 20)
        XCTAssertEqual(config.chargeStopThreshold, 85)
        XCTAssertTrue(config.notificationsEnabled)
        XCTAssertFalse(config.launchAtLogin)
        XCTAssertTrue(config.isValid)
    }

    // MARK: Validity checks

    func testValidConfig_TypicalValues() {
        let config = ChargeConfig(chargeStartThreshold: 30, chargeStopThreshold: 80,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertTrue(config.isValid)
    }

    func testValidConfig_MinimumGap() {
        // Exactly 10 apart should be valid (stop - start == 10)
        let config = ChargeConfig(chargeStartThreshold: 40, chargeStopThreshold: 50,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertTrue(config.isValid)
    }

    func testValidConfig_BoundaryLow() {
        // start at minimum allowed (5), stop at 15 (gap of 10)
        let config = ChargeConfig(chargeStartThreshold: 5, chargeStopThreshold: 15,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertTrue(config.isValid)
    }

    func testValidConfig_BoundaryHigh() {
        // stop at maximum allowed (100), start at 90 (gap of 10)
        let config = ChargeConfig(chargeStartThreshold: 90, chargeStopThreshold: 100,
                                  notificationsEnabled: false, launchAtLogin: true)
        XCTAssertTrue(config.isValid)
    }

    func testValidConfig_FullRange() {
        // start at 5, stop at 100 (gap of 95)
        let config = ChargeConfig(chargeStartThreshold: 5, chargeStopThreshold: 100,
                                  notificationsEnabled: true, launchAtLogin: true)
        XCTAssertTrue(config.isValid)
    }

    func testInvalidConfig_GapTooSmall() {
        // Gap of 9 -- just below the 10 minimum
        let config = ChargeConfig(chargeStartThreshold: 40, chargeStopThreshold: 49,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertFalse(config.isValid)
    }

    func testInvalidConfig_StartAboveStop() {
        let config = ChargeConfig(chargeStartThreshold: 90, chargeStopThreshold: 80,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertFalse(config.isValid)
    }

    func testInvalidConfig_StartEqualsStop() {
        let config = ChargeConfig(chargeStartThreshold: 50, chargeStopThreshold: 50,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertFalse(config.isValid)
    }

    func testInvalidConfig_StartTooLow() {
        // start < 5 is invalid
        let config = ChargeConfig(chargeStartThreshold: 4, chargeStopThreshold: 80,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertFalse(config.isValid)
    }

    func testInvalidConfig_StartAtZero() {
        let config = ChargeConfig(chargeStartThreshold: 0, chargeStopThreshold: 80,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertFalse(config.isValid)
    }

    func testInvalidConfig_StopTooHigh() {
        // stop > 100 is invalid
        let config = ChargeConfig(chargeStartThreshold: 20, chargeStopThreshold: 105,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertFalse(config.isValid)
    }

    func testInvalidConfig_NegativeStart() {
        let config = ChargeConfig(chargeStartThreshold: -5, chargeStopThreshold: 80,
                                  notificationsEnabled: true, launchAtLogin: false)
        XCTAssertFalse(config.isValid)
    }

    // MARK: JSON round-trip

    func testJSONRoundTrip() {
        let original = ChargeConfig(chargeStartThreshold: 25, chargeStopThreshold: 90,
                                    notificationsEnabled: false, launchAtLogin: true)
        let data = original.toJSON()
        XCTAssertNotNil(data, "toJSON() should produce non-nil data for a valid config")
        let decoded = ChargeConfig.fromJSON(data!)
        XCTAssertEqual(decoded, original)
    }

    func testJSONRoundTrip_DefaultConfig() {
        let original = ChargeConfig.default
        let data = original.toJSON()!
        let decoded = ChargeConfig.fromJSON(data)
        XCTAssertEqual(decoded, original)
    }

    func testFromJSONRejectsInvalidConfig() {
        // start > stop makes it invalid; fromJSON should return nil
        let json = """
        {"chargeStartThreshold":90,"chargeStopThreshold":80,"notificationsEnabled":true,"launchAtLogin":false}
        """
        let result = ChargeConfig.fromJSON(json.data(using: .utf8)!)
        XCTAssertNil(result, "fromJSON should reject a config where start > stop")
    }

    func testFromJSONRejectsMalformedData() {
        let garbage = "not json at all".data(using: .utf8)!
        let result = ChargeConfig.fromJSON(garbage)
        XCTAssertNil(result, "fromJSON should return nil for malformed data")
    }

    func testFromJSONRejectsMissingFields() {
        let partial = """
        {"chargeStartThreshold":20}
        """
        let result = ChargeConfig.fromJSON(partial.data(using: .utf8)!)
        XCTAssertNil(result, "fromJSON should return nil when required fields are missing")
    }

    func testEquality() {
        let a = ChargeConfig(chargeStartThreshold: 20, chargeStopThreshold: 85,
                             notificationsEnabled: true, launchAtLogin: false)
        let b = ChargeConfig(chargeStartThreshold: 20, chargeStopThreshold: 85,
                             notificationsEnabled: true, launchAtLogin: false)
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = ChargeConfig(chargeStartThreshold: 20, chargeStopThreshold: 85,
                             notificationsEnabled: true, launchAtLogin: false)
        let b = ChargeConfig(chargeStartThreshold: 25, chargeStopThreshold: 85,
                             notificationsEnabled: true, launchAtLogin: false)
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - BatteryState Tests

final class BatteryStateTests: XCTestCase {

    // MARK: Unknown state

    func testUnknownState() {
        let state = BatteryState.unknown
        XCTAssertEqual(state.level, -1)
        XCTAssertFalse(state.isPluggedIn)
        XCTAssertFalse(state.isCharging)
        XCTAssertNil(state.timeRemaining)
        XCTAssertNil(state.cycleCount)
        XCTAssertNil(state.batteryHealth)
        XCTAssertNil(state.maxCapacity)
        XCTAssertNil(state.temperature)
        XCTAssertNil(state.chargeRate)
    }

    // MARK: levelDescription

    func testLevelDescription_Unknown() {
        let state = BatteryState.unknown
        XCTAssertEqual(state.levelDescription, "Unknown")
    }

    func testLevelDescription_Zero() {
        let state = makeBattery(level: 0)
        XCTAssertEqual(state.levelDescription, "0%")
    }

    func testLevelDescription_Full() {
        let state = makeBattery(level: 100)
        XCTAssertEqual(state.levelDescription, "100%")
    }

    func testLevelDescription_Mid() {
        let state = makeBattery(level: 57)
        XCTAssertEqual(state.levelDescription, "57%")
    }

    // MARK: statusDescription

    func testStatusDescription_OnBattery() {
        let state = makeBattery(level: 50, isPluggedIn: false, isCharging: false)
        XCTAssertEqual(state.statusDescription, "On Battery")
    }

    func testStatusDescription_Charging() {
        let state = makeBattery(level: 50, isPluggedIn: true, isCharging: true)
        XCTAssertEqual(state.statusDescription, "Charging")
    }

    func testStatusDescription_PluggedInNotCharging() {
        let state = makeBattery(level: 85, isPluggedIn: true, isCharging: false)
        XCTAssertEqual(state.statusDescription, "Plugged In (Not Charging)")
    }

    // MARK: menuBarTitle

    func testMenuBarTitle_Unknown() {
        let state = BatteryState.unknown
        XCTAssertEqual(state.menuBarTitle, "⚡ --%")
    }

    func testMenuBarTitle_Normal() {
        let state = makeBattery(level: 72)
        XCTAssertEqual(state.menuBarTitle, "⚡ 72%")
    }

    func testMenuBarTitle_Full() {
        let state = makeBattery(level: 100)
        XCTAssertEqual(state.menuBarTitle, "⚡ 100%")
    }

    // MARK: timeRemainingFormatted

    func testTimeRemainingFormatted_Nil() {
        let state = makeBattery(level: 50, timeRemaining: nil)
        XCTAssertNil(state.timeRemainingFormatted)
    }

    func testTimeRemainingFormatted_Zero() {
        let state = makeBattery(level: 50, timeRemaining: 0)
        XCTAssertNil(state.timeRemainingFormatted,
                     "0 minutes should return nil (guard requires > 0)")
    }

    func testTimeRemainingFormatted_NegativeOne() {
        // NOTE: Due to the guard condition `minutes > 0`, a value of -1 returns nil
        // before reaching the `if minutes == -1 { return "Calculating..." }` branch.
        // This means the "Calculating..." path is unreachable.
        let state = makeBattery(level: 50, timeRemaining: -1)
        XCTAssertNil(state.timeRemainingFormatted,
                     "-1 returns nil because the guard (minutes > 0) fails first")
    }

    func testTimeRemainingFormatted_MinutesOnly() {
        let state = makeBattery(level: 50, timeRemaining: 45)
        XCTAssertEqual(state.timeRemainingFormatted, "45m")
    }

    func testTimeRemainingFormatted_HoursAndMinutes() {
        let state = makeBattery(level: 50, timeRemaining: 90)
        XCTAssertEqual(state.timeRemainingFormatted, "1h 30m")
    }

    func testTimeRemainingFormatted_ExactHours() {
        let state = makeBattery(level: 50, timeRemaining: 120)
        XCTAssertEqual(state.timeRemainingFormatted, "2h 0m")
    }

    func testTimeRemainingFormatted_LargeValue() {
        let state = makeBattery(level: 10, timeRemaining: 600)
        XCTAssertEqual(state.timeRemainingFormatted, "10h 0m")
    }

    // MARK: healthDescription

    func testHealthDescription_WithValue() {
        let state = makeBattery(level: 80, batteryHealth: "Good")
        XCTAssertEqual(state.healthDescription, "Good")
    }

    func testHealthDescription_Nil() {
        let state = makeBattery(level: 80, batteryHealth: nil)
        XCTAssertEqual(state.healthDescription, "Unknown")
    }

    // MARK: cycleCountDescription

    func testCycleCountDescription_WithValue() {
        let state = makeBattery(level: 80, cycleCount: 342)
        XCTAssertEqual(state.cycleCountDescription, "342")
    }

    func testCycleCountDescription_Nil() {
        let state = makeBattery(level: 80)
        XCTAssertEqual(state.cycleCountDescription, "Unknown")
    }

    // MARK: capacityDescription

    func testCapacityDescription_WithValue() {
        let state = makeBattery(level: 80, maxCapacity: 92)
        XCTAssertEqual(state.capacityDescription, "92%")
    }

    func testCapacityDescription_Nil() {
        let state = makeBattery(level: 80)
        XCTAssertEqual(state.capacityDescription, "Unknown")
    }

    // MARK: temperatureFormatted

    func testTemperatureFormatted_WithValue() {
        let state = makeBattery(level: 50, temperature: 35.7)
        XCTAssertEqual(state.temperatureFormatted, "35.7°C")
    }

    func testTemperatureFormatted_Nil() {
        let state = makeBattery(level: 50, temperature: nil)
        XCTAssertNil(state.temperatureFormatted)
    }

    func testTemperatureFormatted_Zero() {
        let state = makeBattery(level: 50, temperature: 0.0)
        XCTAssertEqual(state.temperatureFormatted, "0.0°C")
    }

    // MARK: isOverheating

    func testIsOverheating_AboveThreshold() {
        let state = makeBattery(level: 50, temperature: 41.0)
        XCTAssertTrue(state.isOverheating)
    }

    func testIsOverheating_AtThreshold() {
        let state = makeBattery(level: 50, temperature: 40.0)
        XCTAssertFalse(state.isOverheating, "Exactly 40.0 should NOT be overheating (> 40 required)")
    }

    func testIsOverheating_BelowThreshold() {
        let state = makeBattery(level: 50, temperature: 35.0)
        XCTAssertFalse(state.isOverheating)
    }

    func testIsOverheating_NilTemperature() {
        let state = makeBattery(level: 50, temperature: nil)
        XCTAssertFalse(state.isOverheating)
    }

    // MARK: estimatedTime(toTarget:)

    func testEstimatedTime_ValidCharge() {
        // level=50, target=100, chargeRate=30W, maxCapacity=90
        // remainingPercent = 50, remainingWh = (50/100)*60 = 30, hours = 30/30 = 1.0 => "1h 0m"
        let state = makeBattery(level: 50, maxCapacity: 90, chargeRate: 30.0)
        let result = state.estimatedTime(toTarget: 100)
        XCTAssertEqual(result, "1h 0m")
    }

    func testEstimatedTime_SmallGap() {
        // level=80, target=85, chargeRate=60W
        // remainingPercent = 5, remainingWh = (5/100)*60 = 3.0, hours = 3/60 = 0.05 => 3 minutes
        let state = makeBattery(level: 80, maxCapacity: 95, chargeRate: 60.0)
        let result = state.estimatedTime(toTarget: 85)
        XCTAssertEqual(result, "3m")
    }

    func testEstimatedTime_AlreadyAtTarget() {
        let state = makeBattery(level: 85, maxCapacity: 95, chargeRate: 30.0)
        let result = state.estimatedTime(toTarget: 85)
        XCTAssertNil(result, "No time needed when already at target")
    }

    func testEstimatedTime_AboveTarget() {
        let state = makeBattery(level: 90, maxCapacity: 95, chargeRate: 30.0)
        let result = state.estimatedTime(toTarget: 85)
        XCTAssertNil(result, "No time needed when above target")
    }

    func testEstimatedTime_ZeroChargeRate() {
        let state = makeBattery(level: 50, maxCapacity: 95, chargeRate: 0.0)
        let result = state.estimatedTime(toTarget: 85)
        XCTAssertNil(result, "Zero charge rate cannot estimate time")
    }

    func testEstimatedTime_NilChargeRate() {
        let state = makeBattery(level: 50, maxCapacity: 95, chargeRate: nil)
        let result = state.estimatedTime(toTarget: 85)
        XCTAssertNil(result)
    }

    func testEstimatedTime_NilMaxCapacity() {
        let state = makeBattery(level: 50, maxCapacity: nil, chargeRate: 30.0)
        let result = state.estimatedTime(toTarget: 85)
        XCTAssertNil(result)
    }

    func testEstimatedTime_UnknownLevel() {
        let state = BatteryState.unknown
        let result = state.estimatedTime(toTarget: 85)
        XCTAssertNil(result)
    }

    // MARK: Equality

    func testBatteryStateEquality() {
        let a = makeBattery(level: 50, isPluggedIn: true, isCharging: true)
        let b = makeBattery(level: 50, isPluggedIn: true, isCharging: true)
        XCTAssertEqual(a, b)
    }

    func testBatteryStateInequality() {
        let a = makeBattery(level: 50)
        let b = makeBattery(level: 51)
        XCTAssertNotEqual(a, b)
    }

    // MARK: Helpers

    private func makeBattery(
        level: Int,
        isPluggedIn: Bool = false,
        isCharging: Bool = false,
        timeRemaining: Int? = nil,
        cycleCount: Int? = nil,
        batteryHealth: String? = nil,
        maxCapacity: Int? = nil,
        temperature: Double? = nil,
        chargeRate: Double? = nil
    ) -> BatteryState {
        BatteryState(
            level: level,
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            timeRemaining: timeRemaining,
            cycleCount: cycleCount,
            batteryHealth: batteryHealth,
            maxCapacity: maxCapacity,
            temperature: temperature,
            chargeRate: chargeRate
        )
    }
}

// MARK: - ChargeEvent Tests

final class ChargeEventTests: XCTestCase {

    func testEventCreation() {
        let event = ChargeEvent(kind: .chargingStarted, batteryLevel: 20, detail: "Test")
        XCTAssertEqual(event.kind, .chargingStarted)
        XCTAssertEqual(event.batteryLevel, 20)
        XCTAssertEqual(event.detail, "Test")
        XCTAssertNotNil(event.id)
        XCTAssertNotNil(event.date)
    }

    func testUniqueIDs() {
        let a = ChargeEvent(kind: .chargingStarted, batteryLevel: 20, detail: "A")
        let b = ChargeEvent(kind: .chargingStarted, batteryLevel: 20, detail: "A")
        XCTAssertNotEqual(a.id, b.id, "Each event should get a unique UUID")
    }

    // MARK: Icons for all kinds

    func testIconName_ChargingStarted() {
        let event = ChargeEvent(kind: .chargingStarted, batteryLevel: 20, detail: "")
        XCTAssertEqual(event.iconName, "bolt.fill")
    }

    func testIconName_ChargingStopped() {
        let event = ChargeEvent(kind: .chargingStopped, batteryLevel: 85, detail: "")
        XCTAssertEqual(event.iconName, "bolt.slash.fill")
    }

    func testIconName_AppLaunched() {
        let event = ChargeEvent(kind: .appLaunched, batteryLevel: 50, detail: "")
        XCTAssertEqual(event.iconName, "power")
    }

    func testIconName_AppTerminated() {
        let event = ChargeEvent(kind: .appTerminated, batteryLevel: 50, detail: "")
        XCTAssertEqual(event.iconName, "power.circle")
    }

    func testIconName_HelperError() {
        let event = ChargeEvent(kind: .helperError, batteryLevel: 50, detail: "")
        XCTAssertEqual(event.iconName, "exclamationmark.triangle.fill")
    }

    func testIconName_ConfigChanged() {
        let event = ChargeEvent(kind: .configChanged, batteryLevel: 50, detail: "")
        XCTAssertEqual(event.iconName, "gearshape.fill")
    }

    // MARK: Colors for all kinds

    func testColor_ChargingStarted() {
        let event = ChargeEvent(kind: .chargingStarted, batteryLevel: 20, detail: "")
        XCTAssertEqual(event.color, .green)
    }

    func testColor_ChargingStopped() {
        let event = ChargeEvent(kind: .chargingStopped, batteryLevel: 85, detail: "")
        XCTAssertEqual(event.color, .orange)
    }

    func testColor_AppLaunched() {
        let event = ChargeEvent(kind: .appLaunched, batteryLevel: 50, detail: "")
        XCTAssertEqual(event.color, .blue)
    }

    func testColor_AppTerminated() {
        let event = ChargeEvent(kind: .appTerminated, batteryLevel: 50, detail: "")
        XCTAssertEqual(event.color, .gray)
    }

    func testColor_HelperError() {
        let event = ChargeEvent(kind: .helperError, batteryLevel: 50, detail: "")
        XCTAssertEqual(event.color, .red)
    }

    func testColor_ConfigChanged() {
        let event = ChargeEvent(kind: .configChanged, batteryLevel: 50, detail: "")
        XCTAssertEqual(event.color, .purple)
    }

    // MARK: Kind raw values

    func testKindRawValues() {
        XCTAssertEqual(ChargeEvent.Kind.chargingStarted.rawValue, "Charging Started")
        XCTAssertEqual(ChargeEvent.Kind.chargingStopped.rawValue, "Charging Stopped")
        XCTAssertEqual(ChargeEvent.Kind.appLaunched.rawValue, "App Launched")
        XCTAssertEqual(ChargeEvent.Kind.appTerminated.rawValue, "App Terminated")
        XCTAssertEqual(ChargeEvent.Kind.helperError.rawValue, "Helper Error")
        XCTAssertEqual(ChargeEvent.Kind.configChanged.rawValue, "Config Changed")
    }

    func testAllKindsCovered() {
        // Ensure CaseIterable gives us exactly 6 kinds
        XCTAssertEqual(ChargeEvent.Kind.allCases.count, 6)
    }

    // MARK: Codable round-trip

    func testChargeEventCodableRoundTrip() throws {
        let original = ChargeEvent(kind: .helperError, batteryLevel: 42, detail: "SMC failed")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChargeEvent.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.kind, original.kind)
        XCTAssertEqual(decoded.batteryLevel, original.batteryLevel)
        XCTAssertEqual(decoded.detail, original.detail)
    }
}

// MARK: - Version Comparison Tests
//
// UpdateChecker.isNewer(_:than:) is private, so we replicate its logic here
// to validate the algorithm used for semantic version comparison.

final class VersionComparisonTests: XCTestCase {

    /// Mirrors the logic from UpdateChecker.isNewer(_:than:)
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

    func testNewerMajor() {
        XCTAssertTrue(isNewer("2.0.0", than: "1.0.0"))
    }

    func testNewerMinor() {
        XCTAssertTrue(isNewer("1.2.0", than: "1.1.0"))
    }

    func testNewerPatch() {
        XCTAssertTrue(isNewer("1.0.2", than: "1.0.1"))
    }

    func testSameVersion() {
        XCTAssertFalse(isNewer("1.0.0", than: "1.0.0"))
    }

    func testOlderVersion() {
        XCTAssertFalse(isNewer("1.0.0", than: "2.0.0"))
    }

    func testDifferentSegmentCounts() {
        // "1.1" vs "1.0.0" -- remote has implicit .0, so 1.1.0 > 1.0.0
        XCTAssertTrue(isNewer("1.1", than: "1.0.0"))
    }

    func testShorterLocalVersion() {
        // "1.0.1" vs "1" -- local treated as 1.0.0
        XCTAssertTrue(isNewer("1.0.1", than: "1"))
    }

    func testBothShort() {
        XCTAssertFalse(isNewer("1", than: "1"))
    }

    func testRemoteMuchNewer() {
        XCTAssertTrue(isNewer("10.0.0", than: "1.9.9"))
    }

    func testMajorTrumpsMinor() {
        // 2.0.0 > 1.99.99
        XCTAssertTrue(isNewer("2.0.0", than: "1.99.99"))
    }
}
