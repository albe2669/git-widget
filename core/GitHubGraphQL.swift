import Foundation

public class GitHubGraphQLClient: @unchecked Sendable {
    private let token: String
    private let session: URLSession
    private static let endpoint = URL(string: "https://api.github.com/graphql")!

    public init(token: String) {
        self.token = token
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: cfg)
    }

    public func fetchAll(config: AppConfig) async throws -> WidgetSnapshot {
        let activeRepos = config.repositories.filter { repo in
            !repo.filters.isEmpty && !repo.filters.allSatisfy { $0 == .none }
        }
        guard !activeRepos.isEmpty else {
            return WidgetSnapshot(repositories: [], fetchedAt: Date(), viewerLogin: config.github.username ?? "")
        }

        let query = buildQuery(repos: activeRepos)
        let bodyData = try JSONSerialization.data(withJSONObject: ["query": query])

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GitHubError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let errors = json["errors"] as? [[String: Any]] {
            let msg = errors.compactMap { $0["message"] as? String }.joined(separator: "; ")
            throw GitHubError.graphQLError(msg)
        }

        let graphQLData = json["data"] as? [String: Any] ?? [:]
        let viewerLogin = (graphQLData["viewer"] as? [String: Any])?["login"] as? String ?? ""

        var repoResults: [RepoData] = []
        for (index, repoConfig) in activeRepos.enumerated() {
            guard let repoJSON = graphQLData["repo\(index)"] as? [String: Any] else { continue }
            let prs = parsePRs(from: repoJSON, repoConfig: repoConfig)
            let filtered = PRFilter.apply(prs: prs, config: repoConfig, viewerLogin: viewerLogin)
            repoResults.append(RepoData(owner: repoConfig.owner, name: repoConfig.name, prs: filtered))
        }

        for repoConfig in config.repositories where repoConfig.filters.allSatisfy({ $0 == .none }) {
            repoResults.append(RepoData(owner: repoConfig.owner, name: repoConfig.name, prs: []))
        }

        return WidgetSnapshot(repositories: repoResults, fetchedAt: Date(), viewerLogin: viewerLogin)
    }

    private func buildQuery(repos: [RepoConfig]) -> String {
        let aliases = repos.enumerated().map { i, repo in
            """
            repo\(i): repository(owner: "\(repo.owner)", name: "\(repo.name)") {
                ...repoFields
            }
            """
        }.joined(separator: "\n")

        return """
        query GitWidgetData {
          viewer { login }
          \(aliases)
        }
        \(repoFieldsFragment)
        """
    }

    private let repoFieldsFragment = """
    fragment repoFields on Repository {
      pullRequests(first: 50, states: [OPEN], orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes {
          number title url isDraft
          author { login }
          assignees(first: 20) { nodes { login } }
          reviewRequests(first: 20) {
            nodes {
              requestedReviewer {
                ... on User { login }
                ... on Team { name }
                ... on Mannequin { login }
              }
            }
          }
          reviewDecision
          reviews(first: 30) {
            nodes {
              author { login }
              state
            }
          }
          reviewThreads(first: 50) {
            totalCount
            nodes { isResolved }
          }
          comments { totalCount }
          commits(last: 1) {
            nodes {
              commit {
                statusCheckRollup { state }
              }
            }
          }
        }
      }
    }
    """

    private func parsePRs(from repoJSON: [String: Any], repoConfig: RepoConfig) -> [PRData] {
        guard let nodes = (repoJSON["pullRequests"] as? [String: Any])?["nodes"] as? [[String: Any]] else {
            return []
        }
        return nodes.compactMap { parsePR(from: $0, owner: repoConfig.owner, name: repoConfig.name) }
    }

    private func parsePR(from json: [String: Any], owner: String, name: String) -> PRData? {
        guard let number = json["number"] as? Int,
              let title = json["title"] as? String,
              let url = json["url"] as? String,
              let isDraft = json["isDraft"] as? Bool
        else { return nil }

        let authorLogin = (json["author"] as? [String: Any])?["login"] as? String ?? ""

        let assigneeNodes = (json["assignees"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        let assigneeLogins = assigneeNodes.compactMap { $0["login"] as? String }

        let reviewRequestNodes = (json["reviewRequests"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        let reviewerObjects = reviewRequestNodes.compactMap { $0["requestedReviewer"] as? [String: Any] }
        let requestedReviewerLogins = reviewerObjects.compactMap { $0["login"] as? String }
        let requestedTeamNames = reviewerObjects.compactMap { $0["name"] as? String }

        let reviewDecision = (json["reviewDecision"] as? String).flatMap { ReviewDecision(rawValue: $0) }

        let reviewNodes = (json["reviews"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        let reviews = reviewNodes.compactMap { rv -> ReviewInfo? in
            guard let state = rv["state"] as? String,
                  let login = (rv["author"] as? [String: Any])?["login"] as? String
            else { return nil }
            let isCopilot = login.lowercased().contains("copilot")
            return ReviewInfo(authorLogin: login, state: state, isCopilot: isCopilot)
        }

        let threadNodes = (json["reviewThreads"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        let totalThreads = (json["reviewThreads"] as? [String: Any])?["totalCount"] as? Int ?? 0
        let resolvedThreads = threadNodes.filter { $0["isResolved"] as? Bool == true }.count
        let totalComments = (json["comments"] as? [String: Any])?["totalCount"] as? Int ?? 0

        let commitNodes = (json["commits"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        let ciStateRaw = (commitNodes.first?["commit"] as? [String: Any])?["statusCheckRollup"] as? [String: Any]
        let ciState = (ciStateRaw?["state"] as? String).flatMap { CIState(rawValue: $0) }

        return PRData(
            number: number, title: title, url: url, isDraft: isDraft,
            authorLogin: authorLogin, assigneeLogins: assigneeLogins,
            requestedReviewerLogins: requestedReviewerLogins,
            requestedTeamNames: requestedTeamNames,
            reviewDecision: reviewDecision, reviews: reviews,
            totalComments: totalComments, resolvedThreads: resolvedThreads,
            totalThreads: totalThreads, ciState: ciState,
            repoOwner: owner, repoName: name
        )
    }
}

public struct PRFilter {
    public static func apply(prs: [PRData], config: RepoConfig, viewerLogin: String) -> [PRData] {
        var seen = Set<Int>()
        var result: [PRData] = []
        for mode in config.filters {
            for pr in matching(prs: prs, mode: mode, config: config, viewerLogin: viewerLogin) {
                if seen.insert(pr.number).inserted {
                    result.append(pr)
                }
            }
        }
        return result
    }

    private static func matching(prs: [PRData], mode: FilterMode, config: RepoConfig, viewerLogin: String) -> [PRData] {
        switch mode {
        case .all:
            return prs
        case .none:
            return []
        case .opened:
            return prs.filter { $0.authorLogin == viewerLogin }
        case .assigned:
            return prs.filter { pr in
                pr.assigneeLogins.contains(viewerLogin) ||
                pr.requestedReviewerLogins.contains(viewerLogin)
            }
        case .assignedDirect:
            return prs.filter { $0.requestedReviewerLogins.contains(viewerLogin) }
        case .assignedGroup:
            guard let group = config.assignedGroup, !group.isEmpty else { return [] }
            return prs.filter { pr in
                pr.requestedTeamNames.contains { $0.lowercased() == group.lowercased() }
            }
        }
    }
}

public enum GitHubError: Error, LocalizedError {
    case httpError(Int)
    case graphQLError(String)

    public var errorDescription: String? {
        switch self {
        case .httpError(let code): return "GitHub API returned HTTP \(code)"
        case .graphQLError(let msg): return "GitHub API error: \(msg)"
        }
    }
}
