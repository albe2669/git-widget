import Foundation

public enum FilterMode: String, Codable, Sendable {
    case all, opened, assigned, none
    case assignedDirect = "assigned-direct"
    case assignedGroup = "assigned-group"
}

public struct NotificationPrefs: Codable, Sendable {
    public var newPR: Bool
    public var assigned: Bool
    public var reviewRequested: Bool
    public var ciFailed: Bool

    public init(newPR: Bool = true, assigned: Bool = true, reviewRequested: Bool = true, ciFailed: Bool = false) {
        self.newPR = newPR
        self.assigned = assigned
        self.reviewRequested = reviewRequested
        self.ciFailed = ciFailed
    }
}

public struct RepoConfig: Sendable {
    public var owner: String
    public var name: String
    public var filters: [FilterMode]
    public var assignedGroup: String?
    public var notifications: NotificationPrefs

    public init(
        owner: String = "",
        name: String = "",
        filters: [FilterMode] = [.assigned],
        assignedGroup: String? = nil,
        notifications: NotificationPrefs = .init()
    ) {
        self.owner = owner
        self.name = name
        self.filters = filters
        self.assignedGroup = assignedGroup
        self.notifications = notifications
    }
}

public struct GitHubConfig: Sendable {
    public var token: String?
    public var tokenFile: String?
    public var username: String?
    public var updateInterval: Int

    public init(token: String? = nil, tokenFile: String? = nil, username: String? = nil, updateInterval: Int = 900) {
        self.token = token
        self.tokenFile = tokenFile
        self.username = username
        self.updateInterval = updateInterval
    }

    public func resolvedToken() throws -> String {
        if let path = tokenFile, !path.isEmpty {
            let raw = try String(contentsOfFile: path, encoding: .utf8)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ConfigError.emptyTokenFile(path) }
            return trimmed
        }
        guard let t = token, !t.isEmpty else { throw ConfigError.missingToken }
        return t
    }
}

public struct AppConfig: Sendable {
    public var github: GitHubConfig
    public var repositories: [RepoConfig]

    public init(github: GitHubConfig = .init(), repositories: [RepoConfig] = []) {
        self.github = github
        self.repositories = repositories
    }
}

public enum ReviewDecision: String, Codable, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
}

public enum CIState: String, Codable, Sendable {
    case success = "SUCCESS"
    case failure = "FAILURE"
    case pending = "PENDING"
    case error = "ERROR"
    case expected = "EXPECTED"
}

public struct ReviewInfo: Codable, Sendable {
    public var authorLogin: String
    public var state: String
    public var isCopilot: Bool

    public init(authorLogin: String, state: String, isCopilot: Bool) {
        self.authorLogin = authorLogin
        self.state = state
        self.isCopilot = isCopilot
    }
}

public struct PRData: Codable, Sendable, Identifiable {
    public var id: Int { number }
    public var number: Int
    public var title: String
    public var url: String
    public var isDraft: Bool
    public var authorLogin: String
    public var assigneeLogins: [String]
    public var requestedReviewerLogins: [String]
    public var requestedTeamNames: [String]
    public var reviewDecision: ReviewDecision?
    public var reviews: [ReviewInfo]
    public var totalComments: Int
    public var resolvedThreads: Int
    public var totalThreads: Int
    public var ciState: CIState?
    public var repoOwner: String
    public var repoName: String

    public init(
        number: Int, title: String, url: String, isDraft: Bool,
        authorLogin: String, assigneeLogins: [String],
        requestedReviewerLogins: [String], requestedTeamNames: [String],
        reviewDecision: ReviewDecision?, reviews: [ReviewInfo],
        totalComments: Int, resolvedThreads: Int, totalThreads: Int,
        ciState: CIState?, repoOwner: String, repoName: String
    ) {
        self.number = number
        self.title = title
        self.url = url
        self.isDraft = isDraft
        self.authorLogin = authorLogin
        self.assigneeLogins = assigneeLogins
        self.requestedReviewerLogins = requestedReviewerLogins
        self.requestedTeamNames = requestedTeamNames
        self.reviewDecision = reviewDecision
        self.reviews = reviews
        self.totalComments = totalComments
        self.resolvedThreads = resolvedThreads
        self.totalThreads = totalThreads
        self.ciState = ciState
        self.repoOwner = repoOwner
        self.repoName = repoName
    }
}

public struct RepoData: Codable, Sendable {
    public var owner: String
    public var name: String
    public var prs: [PRData]

    public init(owner: String, name: String, prs: [PRData]) {
        self.owner = owner
        self.name = name
        self.prs = prs
    }

    public var displayName: String { "\(owner)/\(name)" }
}

public struct WidgetSnapshot: Codable, Sendable {
    public var repositories: [RepoData]
    public var fetchedAt: Date
    public var viewerLogin: String
    public var errorMessage: String?

    public init(repositories: [RepoData], fetchedAt: Date, viewerLogin: String, errorMessage: String? = nil) {
        self.repositories = repositories
        self.fetchedAt = fetchedAt
        self.viewerLogin = viewerLogin
        self.errorMessage = errorMessage
    }
}
