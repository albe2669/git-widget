import Foundation

public let appGroupID = "group.maliciousgoose.git-widget.shared"
public let extensionBundleID = "maliciousgoose.git-widget.extension"

public enum AppGroupError: Error, LocalizedError {
    case containerUnavailable

    public var errorDescription: String? {
        "Widget snapshot container unavailable."
    }
}

public struct AppGroupStorage {

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var snapshotURL: URL? {
        if Bundle.main.bundleIdentifier == extensionBundleID {
            return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("widget-snapshot.json")
        } else {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/\(extensionBundleID)/Data/Library/widget-snapshot.json")
        }
    }

    public static func save(_ snapshot: WidgetSnapshot) throws {
        guard let url = snapshotURL else { throw AppGroupError.containerUnavailable }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public static func load() throws -> WidgetSnapshot {
        guard let url = snapshotURL else { throw AppGroupError.containerUnavailable }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }

    private static var firstRunURL: URL? {
        containerURL?.appendingPathComponent("first-run-done")
    }

    public static func isFirstRun() -> Bool {
        guard let url = firstRunURL else { return true }
        return !FileManager.default.fileExists(atPath: url.path)
    }

    public static func markFirstRunDone() {
        guard let url = firstRunURL else { return }
        try? Data().write(to: url)
    }
}
