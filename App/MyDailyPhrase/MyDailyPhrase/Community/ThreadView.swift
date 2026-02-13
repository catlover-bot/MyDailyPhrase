import SwiftUI
import Domain
import Presentation

struct ThreadView: View {
    let challenge: ChallengeEvent
    @ObservedObject var vm: CommunityViewModel

    /// 親側の ShareSheet を使うためのコールバック（items をそのまま渡す）
    let shareItems: ([Any]) -> Void

    @Environment(\.currentDecorationId) private var decorationId

    @State private var commentText: String = ""

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

                    Text("from: \(challenge.link.fromName) / dateKey: \(challenge.link.dateKey)")
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
                                    Text(isMine ? "📝 あなた" : "📝 \(ev.link.fromName)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
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

                    case .reaction(let ev, let isMine):
                        Card {
                            HStack {
                                Text(ev.link.emoji).font(.title3)
                                Text(isMine ? "あなた" : ev.link.fromName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(ev.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
        let payload = SharePayload(text: text, image: image, url: url)
        shareItems([payload])
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

    private enum DecorationStyle: String {
        case classic, sakura, aurora, neon, gold
        static func from(_ raw: String) -> DecorationStyle {
            let norm = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return DecorationStyle(rawValue: norm) ?? .classic
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
