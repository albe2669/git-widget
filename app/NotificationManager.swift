import UserNotifications
import core

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    func check(new: WidgetSnapshot, previous: WidgetSnapshot?, config: AppConfig) async {
        let prevPRsByRepo: [String: Set<Int>] = Dictionary(
            uniqueKeysWithValues: (previous?.repositories ?? []).map {
                ($0.displayName, Set($0.prs.map(\.number)))
            }
        )
        let prevCIByKey: [String: CIState] = Dictionary(
            uniqueKeysWithValues: (previous?.repositories ?? []).flatMap { repo in
                repo.prs.compactMap { pr -> (String, CIState)? in
                    guard let ci = pr.ciState else { return nil }
                    return ("\(repo.displayName)/#\(pr.number)", ci)
                }
            }
        )

        for (repoData, repoConfig) in zip(new.repositories, config.repositories) {
            let prevNumbers = prevPRsByRepo[repoData.displayName] ?? []
            let notifs = repoConfig.notifications

            for pr in repoData.prs {
                let isNew = !prevNumbers.contains(pr.number)

                if isNew && notifs.newPR {
                    await send(title: "New PR · \(repoData.displayName)", body: "#\(pr.number) \(pr.title)", url: pr.url)
                }
                if isNew && notifs.assigned
                    && (pr.assigneeLogins.contains(new.viewerLogin) || pr.requestedReviewerLogins.contains(new.viewerLogin)) {
                    await send(title: "Assigned · \(repoData.displayName)", body: "#\(pr.number) \(pr.title)", url: pr.url)
                }
                if isNew && notifs.reviewRequested && pr.requestedReviewerLogins.contains(new.viewerLogin) {
                    await send(title: "Review requested · \(repoData.displayName)", body: "#\(pr.number) \(pr.title)", url: pr.url)
                }
                if notifs.ciFailed && pr.ciState == .failure {
                    let key = "\(repoData.displayName)/#\(pr.number)"
                    if prevCIByKey[key] != .failure {
                        await send(title: "CI failed · \(repoData.displayName)", body: "#\(pr.number) \(pr.title)", url: pr.url)
                    }
                }
            }
        }
    }

    private func send(title: String, body: String, url: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["url": url]
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}
