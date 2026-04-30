import SwiftUI

@main
struct GitWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("GitHub PRs", systemImage: "arrow.triangle.pull") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}
