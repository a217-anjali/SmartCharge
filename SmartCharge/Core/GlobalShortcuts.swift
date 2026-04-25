import Foundation
import AppKit
import os

@MainActor
final class GlobalShortcuts: ObservableObject {

    @Published var shortcutsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(shortcutsEnabled, forKey: Self.defaultsKey)
            if shortcutsEnabled {
                register()
            } else {
                unregister()
            }
        }
    }

    /// Closure invoked when the user presses Cmd+Shift+B to toggle charging.
    var onToggleCharging: (() -> Void)?

    /// Closure invoked when the user presses Cmd+Shift+S to bring the window forward.
    var onShowWindow: (() -> Void)?

    private var globalMonitor: Any?
    private static let defaultsKey = "GlobalShortcutsEnabled"
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "GlobalShortcuts")

    // MARK: - Init

    init() {
        self.shortcutsEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    // MARK: - Register / Unregister

    /// Registers global keyboard shortcut monitors.
    /// - Cmd+Shift+B: Toggle charging on/off
    /// - Cmd+Shift+S: Open/bring forward the SmartCharge window
    func register() {
        guard globalMonitor == nil else {
            Self.logger.debug("Global shortcuts already registered")
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }

        Self.logger.info("Global keyboard shortcuts registered")
    }

    /// Removes all global keyboard shortcut monitors.
    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
            Self.logger.info("Global keyboard shortcuts unregistered")
        }
    }

    // MARK: - Private

    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]

        guard flags == requiredFlags else { return }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "b":
            Self.logger.info("Shortcut triggered: Cmd+Shift+B (toggle charging)")
            onToggleCharging?()
        case "s":
            Self.logger.info("Shortcut triggered: Cmd+Shift+S (show window)")
            onShowWindow?()
        default:
            break
        }
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
