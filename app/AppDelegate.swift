import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        Task {
            await BackgroundPoller.shared.start()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            NSWorkspace.shared.open(url)
        }
    }
}
