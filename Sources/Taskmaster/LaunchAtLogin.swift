import AppKit
import ServiceManagement

/// Open at login, through macOS's Login Items (the same approach as Luna).
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    /// The user has to allow Taskmaster in System Settings › General › Login Items.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                // register() isn't idempotent: it adds a second entry when called again.
                if service.status != .enabled { try service.register() }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            NSLog("Taskmaster couldn't change Open at login: %@", error.localizedDescription)
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
