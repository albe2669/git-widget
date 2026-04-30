import SwiftUI
import core

struct MenuBarView: View {
    @State private var snapshot: WidgetSnapshot?

    var body: some View {
        Group {
            let total = snapshot?.repositories.flatMap(\.prs).count ?? 0
            if total > 0 {
                Text("\(total) open PR\(total == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
            }

            Button("Refresh Now") {
                Task { await BackgroundPoller.shared.poll() }
            }

            Divider()

            Button("Open Config…") {
                let configURL = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".config/git-widget/config.toml")
                NSWorkspace.shared.open(configURL)
            }

            Divider()

            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .task {
            snapshot = try? AppGroupStorage.load()
        }
    }
}
