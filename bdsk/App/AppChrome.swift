import AppKit

enum AppChrome {
    static var openSettingsWindow: (() -> Void)?
    static var openSetupWindow: (() -> Void)?
    private static var pendingSetup = false

    static func becomeRegularApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func showSettings() {
        becomeRegularApp()
        openSettingsWindow?()
    }

    static func showSetup() {
        becomeRegularApp()
        if let openSetupWindow {
            openSetupWindow()
        } else {
            pendingSetup = true
        }
    }

    static func presentPendingWindows() {
        if pendingSetup {
            pendingSetup = false
            showSetup()
        }
    }

    static func resignToMenuBarIfNeeded() {
        let hasMainWindow = NSApp.windows.contains { window in
            window.isVisible && window.canBecomeMain
        }
        guard !hasMainWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

final class BdskAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppChrome.resignToMenuBarIfNeeded()
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppChrome.showSettings()
        } else {
            AppChrome.becomeRegularApp()
        }
        return true
    }
}
