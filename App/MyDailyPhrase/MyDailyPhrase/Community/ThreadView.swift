import SwiftUI
import UIKit
import Domain
import Presentation

struct ThreadView: View {
    let challenge: ChallengeEvent
    @ObservedObject var vm: CommunityViewModel

    /// 親側の ShareSheet を使うためのコールバック（items をそのまま渡す）
    let shareItems: ([Any]) -> Void

    @Environment(\.currentDecorationId) private var decorationId

    @State private var commentText: String = ""
    @State private var activityMessage: String? = nil

    private let emojis: [String] = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    var body: some View {
        let items = vm.threadItems(for: challenge)

        ZStack {
            ThreadGradientBackground()
                .ignoresSafeArea()

            List {
                challengeSection
                replySection
                threadSection(items: items)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Thread")
        .task { vm.refresh() }
        .onChange(of: commentText) { _, newValue in
            // ✅ 200文字制限（超えたらカット）
            if newValue.count > 200 {
                commentText = String(newValue.prefix(200))
            }
        }
    }

    // MARK: - Sections

    private var challengeSection: some View {
        Section("Challenge") {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(challenge.link.prompt)
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 4) {
                        NavigationLink {
                            UserProfileView(userId: challenge.link.fromId, name: challenge.link.fromName)
                        } label: {
                            Text("from: \(challenge.link.fromName)")
                        }
                        Text("/ dateKey: \(challenge.link.dateKey)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        if let room = challenge.link.room { Text("room: \(room)") }
                        if let chain = challenge.link.chainId { Text("chain: \(chain)") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Button {
                        shareChallengeAsCard()
                    } label: {
                        Label("このスレッドをカードで共有", systemImage: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        vm.importToDiary(challenge)
                        vm.refresh()
                    } label: {
                        Label("このチャレンジを日記に取り込む", systemImage: "tray.and.arrow.down")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 2)
            }
            .contextMenu {
                moderationContextMenu(
                    userId: challenge.link.fromId,
                    name: challenge.link.fromName,
                    source: "thread_challenge"
                )
            }
        }
    }

    private var replySection: some View {
        Section("Reply") {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("コメント（200文字まで）")
                            .font(.headline)
                        Spacer()
                        Text("\(commentText.count)/200")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextEditor(text: $commentText)
                        .frame(minHeight: 110)
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.secondary.opacity(0.18))
                        )

                    Button {
                        shareCommentLink()
                    } label: {
                        Label("コメントリンクを共有", systemImage: "link")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Divider()

                    Text("リアクション")
                        .font(.headline)

                    FlowRow(spacing: 10) {
                        ForEach(emojis, id: \.self) { e in
                            Button(e) {
                                shareReaction(emoji: e)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let activityMessage {
                        Text(activityMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func threadSection(items: [CommunityViewModel.ThreadItem]) -> some View {
        Section("Thread") {
            if items.isEmpty {
                Card {
                    Text("まだコメント/リアクションがありません")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(items) { it in
                    switch it {
                    case .comment(let ev, let isMine):
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if isMine {
                                        Text("📝 あなた")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        NavigationLink {
                                            UserProfileView(userId: ev.link.fromId, name: ev.link.fromName)
                                        } label: {
                                            Text("📝 \(ev.link.fromName)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(ev.createdAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(ev.link.text)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .contextMenu {
                            if !isMine {
                                moderationContextMenu(
                                    userId: ev.link.fromId,
                                    name: ev.link.fromName,
                                    source: "thread_comment"
                                )
                            }
                        }

                    case .reaction(let ev, let isMine):
                        Card {
                            HStack {
                                Text(ev.link.emoji).font(.title3)
                                if isMine {
                                    Text("あなた")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    NavigationLink {
                                        UserProfileView(userId: ev.link.fromId, name: ev.link.fromName)
                                    } label: {
                                        Text(ev.link.fromName)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(ev.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            if !isMine {
                                moderationContextMenu(
                                    userId: ev.link.fromId,
                                    name: ev.link.fromName,
                                    source: "thread_reaction"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Share helpers (SharePayload統一)

    @MainActor
    private func sendShare(text: String, image: UIImage? = nil, url: URL? = nil) {
        shareItems(ShareItemsBuilder.build(text: text, image: image, url: url))
    }

    @MainActor
    private func muteSender(userId: String, name: String) {
        guard vm.canModerateTarget(userId: userId, displayName: name) else {
            activityMessage = "自分自身はミュートできません"
            return
        }
        vm.mute(userId: userId, displayName: name)
        activityMessage = "「\(name)」をミュートしました"
    }

    @MainActor
    private func blockSender(userId: String, name: String) {
        guard vm.canModerateTarget(userId: userId, displayName: name) else {
            activityMessage = "自分自身はブロックできません"
            return
        }
        vm.block(userId: userId, displayName: name)
        activityMessage = "「\(name)」をブロックしました"
    }

    @MainActor
    private func reportSender(userId: String, name: String, source: String) {
        guard vm.canModerateTarget(userId: userId, displayName: name) else {
            activityMessage = "自分自身は通報できません"
            return
        }
        guard let report = vm.report(userId: userId, displayName: name, source: source) else {
            activityMessage = "同内容の通報は1分以内に重複登録できません"
            return
        }

        UIPasteboard.general.string = """
        [Safety Report]
        date: \(report.createdAt.ISO8601Format())
        source: \(report.source)
        reason: \(report.reason)
        displayName: \(report.displayName)
        userId: \(report.userId.isEmpty ? "-" : report.userId)
        """
        activityMessage = "「\(name)」を通報記録しました（内容をコピー済み）"
    }

    @ViewBuilder
    private func moderationContextMenu(userId: String, name: String, source: String) -> some View {
        Button(role: .destructive) {
            muteSender(userId: userId, name: name)
        } label: {
            Label("「\(name)」をミュート", systemImage: "speaker.slash")
        }

        Button(role: .destructive) {
            blockSender(userId: userId, name: name)
        } label: {
            Label("「\(name)」をブロック", systemImage: "hand.raised")
        }

        Button {
            reportSender(userId: userId, name: name, source: source)
        } label: {
            Label("通報を記録", systemImage: "exclamationmark.bubble")
        }
    }

    private func shareCommentLink() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url = vm.buildCommentURL(
            text: trimmed,
            toChallengeId: challenge.id,
            room: challenge.link.room,
            chainId: challenge.link.chainId
        )

        let text = "コメント: \(trimmed)\n#MyDailyPhrase"
        Task { @MainActor in
            sendShare(text: text, url: url)
        }

        commentText = ""
        activityMessage = "コメントリンクを共有しました"
        vm.refresh()
    }

    private func shareReaction(emoji: String) {
        let url = vm.buildReactionURL(
            emoji: emoji,
            toChallengeId: challenge.id,
            room: challenge.link.room,
            chainId: challenge.link.chainId
        )

        let text = "リアクション \(emoji)\n#MyDailyPhrase"
        Task { @MainActor in
            sendShare(text: text, url: url)
        }

        activityMessage = "リアクション \(emoji) を共有しました"
        vm.refresh()
    }

    // MARK: - Share Card

    private func shareChallengeAsCard() {
        let c = vm.commentCount(for: challenge.id)
        let r = vm.reactionCount(for: challenge.id)

        let metaParts: [String] = [
            challenge.link.room.map { "room: \($0)" },
            challenge.link.chainId.map { "chain: \($0)" }
        ].compactMap { $0 }
        let metaLine = metaParts.isEmpty ? nil : metaParts.joined(separator: " / ")

        let statsLine = "💬 \(c)   👍 \(r)"

        let url = DeepLinkCodec.makeURL(challenge.link)

        let model = ShareCardModel(
            appName: "MyDailyPhrase",
            dateText: challenge.link.dateKey,
            streakText: "",
            prompt: challenge.link.prompt,
            answer: "",
            title: "お題を回そう",
            summary: "from: \(challenge.link.fromName)",
            moodTags: [],
            keywords: [],
            metaLine: metaLine,
            statsLine: statsLine,
            decorationId: decorationId,
            shareURL: url
        )

        guard let rendered = ShareCardRenderer.render(model: model) else { return }

        let text = "お題を回そう\n#MyDailyPhrase"
        Task { @MainActor in
            sendShare(text: text, image: rendered.image, url: url)
        }
    }
}

// MARK: - Background

private struct ThreadGradientBackground: View {
    @Environment(\.currentDecorationId) private var decorationId
    private var style: DecorationStyle { DecorationStyle.from(decorationId) }

    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.90),
                Color(.secondarySystemBackground).opacity(0.70)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                colors: style.tintColors,
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        )
    }

    private enum DecorationStyle: String, CaseIterable {
        case classic, sakura, aurora, neon, gold
        static func from(_ raw: String) -> DecorationStyle {
            let resolved = DecorationThemeResolver.resolveStyleID(
                from: raw,
                supportedStyleIDs: Set(Self.allCases.map(\.rawValue))
            )
            return DecorationStyle(rawValue: resolved) ?? .classic
        }

        var tintColors: [Color] {
            switch self {
            case .classic: return [Color.purple.opacity(0.08), Color.blue.opacity(0.06), Color.clear]
            case .sakura:  return [Color.pink.opacity(0.10),   Color.purple.opacity(0.05), Color.clear]
            case .aurora:  return [Color.green.opacity(0.08),  Color.blue.opacity(0.08),   Color.clear]
            case .neon:    return [Color.cyan.opacity(0.08),   Color.purple.opacity(0.06), Color.clear]
            case .gold:    return [Color.yellow.opacity(0.08), Color.orange.opacity(0.06), Color.clear]
            }
        }
    }
}

// MARK: - FlowRow (iOS16+ Layout)

private struct FlowRow<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        FlowLayout(spacing: spacing) {
            content
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    init(spacing: CGFloat = 10) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += (x > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            s.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
