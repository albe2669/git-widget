import Foundation

public enum ConfigError: Error, LocalizedError {
    case fileNotFound
    case missingToken
    case emptyTokenFile(String)
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Config not found. Create ~/.config/git-widget/config.toml (see config.example.toml)"
        case .missingToken:
            return "No GitHub token configured. Set 'token' or 'token_file' in config."
        case .emptyTokenFile(let path):
            return "Token file is empty: \(path)"
        case .parseError(let msg):
            return "Config parse error: \(msg)"
        }
    }
}

public struct ConfigLoader {

    private static var searchPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.config/git-widget/config.toml",
            "/etc/git-widget/config.toml",
        ]
    }

    public static func load() throws -> AppConfig {
        for path in searchPaths where FileManager.default.fileExists(atPath: path) {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            return try parse(content)
        }
        throw ConfigError.fileNotFound
    }

    static func parse(_ content: String) throws -> AppConfig {
        var github = GitHubConfig()
        var repos: [RepoConfig] = []

        enum Section { case none, github, repositories, repoNotifications }
        var section = Section.none
        var currentRepo: RepoConfig?

        for rawLine in content.components(separatedBy: .newlines) {
            let line = stripInlineComment(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line == "[github]" {
                section = .github
                if let r = currentRepo { repos.append(r); currentRepo = nil }
                continue
            }
            if line == "[[repositories]]" {
                section = .repositories
                if let r = currentRepo { repos.append(r) }
                currentRepo = RepoConfig()
                continue
            }
            if line == "[repositories.notifications]" {
                section = .repoNotifications
                continue
            }

            guard let (key, rawVal) = parseKV(line) else { continue }

            switch section {
            case .github:
                switch key {
                case "token":           github.token = parseStr(rawVal)
                case "token_file":      github.tokenFile = parseStr(rawVal)
                case "username":        github.username = parseStr(rawVal)
                case "update_interval": github.updateInterval = parseInt(rawVal) ?? 900
                default: break
                }
            case .repositories:
                switch key {
                case "owner":          currentRepo?.owner = parseStr(rawVal) ?? ""
                case "name":           currentRepo?.name = parseStr(rawVal) ?? ""
                case "filter":         currentRepo?.filter = FilterMode(rawValue: parseStr(rawVal) ?? "") ?? .assigned
                case "assigned_group": currentRepo?.assignedGroup = parseStr(rawVal)
                default: break
                }
            case .repoNotifications:
                switch key {
                case "new_pr":           currentRepo?.notifications.newPR = parseBool(rawVal) ?? true
                case "assigned":         currentRepo?.notifications.assigned = parseBool(rawVal) ?? true
                case "review_requested": currentRepo?.notifications.reviewRequested = parseBool(rawVal) ?? true
                case "ci_failed":        currentRepo?.notifications.ciFailed = parseBool(rawVal) ?? false
                default: break
                }
            case .none: break
            }
        }

        if let r = currentRepo { repos.append(r) }
        return AppConfig(github: github, repositories: repos)
    }

    private static func stripInlineComment(_ line: String) -> String {
        var inString = false
        var result = ""
        for ch in line {
            if ch == "\"" { inString.toggle() }
            if ch == "#" && !inString { break }
            result.append(ch)
        }
        return result
    }

    private static func parseKV(_ line: String) -> (String, String)? {
        guard let eqIdx = line.firstIndex(of: "=") else { return nil }
        let key = String(line[..<eqIdx]).trimmingCharacters(in: .whitespaces)
        let val = String(line[line.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        return (key, val)
    }

    private static func parseStr(_ s: String) -> String? {
        guard s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 else { return nil }
        return String(s.dropFirst().dropLast())
    }

    private static func parseBool(_ s: String) -> Bool? {
        switch s {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    private static func parseInt(_ s: String) -> Int? { Int(s) }
}
