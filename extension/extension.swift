import WidgetKit
import SwiftUI
import core

struct GitPRWidget: Widget {
    let kind = "GitPRWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PRTimelineProvider()) { entry in
            PRWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GitHub PRs")
        .description("Shows open pull requests from your configured repositories.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct PRWidgetEntryView: View {
    let entry: PREntry
    @Environment(\.colorScheme) var colorScheme
    var background: Color {
        colorScheme == .dark
            ? Color(.sRGB, white: 0.13, opacity: 1)
            : Color(.sRGB, white: 0.97, opacity: 1)
    }

    var body: some View {
        Group {
            if let error = entry.snapshot?.errorMessage {
                ErrorView(message: error)
            } else if let snapshot = entry.snapshot {
                PRListView(snapshot: snapshot)
            } else {
                PlaceholderView()
            }
        }
        .containerBackground(background, for: .widget)
    }
}

struct PRListView: View {
    let snapshot: WidgetSnapshot

    var activeRepos: [RepoData] {
        snapshot.repositories.filter { !$0.prs.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("GitHub PRs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(snapshot.fetchedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 2)

            if activeRepos.isEmpty {
                Spacer()
                Text("No open PRs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(activeRepos, id: \.displayName) { repo in
                        RepoSectionView(repo: repo)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

struct RepoSectionView: View {
    let repo: RepoData

    var sortedPRs: [PRData] {
        repo.prs.sorted { priority($0) > priority($1) }
    }

    private func priority(_ pr: PRData) -> Int {
        if pr.isDraft { return 0 }
        switch pr.reviewDecision {
        case .changesRequested: return 4
        case .reviewRequired: return 3
        case .none: return 2
        case .approved: return 1
        @unknown default: return 2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(repo.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.top, 3)

            ForEach(sortedPRs) { pr in
                PRRowView(pr: pr)
            }
        }
    }
}

struct PRRowView: View {
    let pr: PRData

    private var statusColor: Color {
        if pr.isDraft { return .secondary }
        switch pr.reviewDecision {
        case .approved: return .green
        case .changesRequested: return .red
        case .reviewRequired: return .orange
        case .none: return .blue
        @unknown default: return .blue
        }
    }

    private var hasCopilotReview: Bool {
        pr.reviews.contains { $0.isCopilot }
    }

    var body: some View {
        Link(destination: URL(string: pr.url)!) {
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)

                if pr.isDraft {
                    Text("DRAFT")
                        .font(.system(size: 7, weight: .semibold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Text("#\(pr.number) \(pr.title)")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                HStack(spacing: 3) {
                    if let ci = pr.ciState {
                        CIIcon(state: ci)
                    }
                    ReviewIcon(decision: pr.reviewDecision)
                    if hasCopilotReview {
                        Image(systemName: "cpu")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    if pr.totalThreads > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "bubble.left")
                            Text("\(pr.resolvedThreads)/\(pr.totalThreads)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CIIcon: View {
    let state: CIState
    var body: some View {
        Group {
            switch state {
            case .success:  Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failure:  Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .pending:  Image(systemName: "clock.fill").foregroundStyle(.orange)
            case .error:    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            case .expected: Image(systemName: "circle.dotted").foregroundStyle(.secondary)
            @unknown default: Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
    }
}

struct ReviewIcon: View {
    let decision: ReviewDecision?
    var body: some View {
        Group {
            switch decision {
            case .approved:
                Image(systemName: "hand.thumbsup.fill").foregroundStyle(.green)
            case .changesRequested:
                Image(systemName: "hand.raised.fill").foregroundStyle(.red)
            case .reviewRequired:
                Image(systemName: "eye").foregroundStyle(.orange)
            case .none:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }
        .font(.caption2)
    }
}

struct ErrorView: View {
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Waiting for data…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
