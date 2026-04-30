import Foundation
import WidgetKit
import core

final class BackgroundPoller {
    static let shared = BackgroundPoller()

    private var timer: Timer?
    private var config: AppConfig?
    private var client: GitHubGraphQLClient?

    func start() async {
        do {
            let cfg = try ConfigLoader.load()
            config = cfg
            let token = try cfg.github.resolvedToken()
            client = GitHubGraphQLClient(token: token)

            await poll()

            let interval = Double(max(cfg.github.updateInterval, 300))
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in await self?.poll() }
            }
        } catch {
            print("GitWidget config error: \(error.localizedDescription)")
        }
    }

    func poll() async {
        guard let config, let client else { return }
        do {
            let snapshot = try await client.fetchAll(config: config)
            let previous = try? AppGroupStorage.load()

            if !AppGroupStorage.isFirstRun() {
                await NotificationManager.shared.check(new: snapshot, previous: previous, config: config)
            } else {
                AppGroupStorage.markFirstRunDone()
            }

            try AppGroupStorage.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("GitWidget poll error: \(error.localizedDescription)")
            let errSnapshot = WidgetSnapshot(
                repositories: [], fetchedAt: Date(), viewerLogin: "",
                errorMessage: error.localizedDescription
            )
            try? AppGroupStorage.save(errSnapshot)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
