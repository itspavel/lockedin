import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService (the modern, no-helper approach). Registering the
/// main app makes macOS start it when you log in.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns the new enabled state (may differ from requested if the user must approve
    /// in System Settings > General > Login Items).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LockedIn login-item toggle failed: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
