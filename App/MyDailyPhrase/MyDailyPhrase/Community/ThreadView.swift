import SwiftUI
import Domain

struct ThreadView: View {
    let challenge: ChallengeEvent
    @ObservedObject var vm: CommunityViewModel

    /// 親側の ShareSheet を使うためのコールバック
    let share: (String, URL?) -> Void

    @State private var commentText: String = ""

    private let emojis: [String] = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    var body: some View {
        let items = vm.threadItems(for: challenge)

        List {
            challengeSection
            replySection
            threadSection(items: items)
        }
        .navigationTitle("Thread")
        .onAppear { vm.refresh() }
    }

    // MARK: - Sections

    private var challengeSection: some View {
        Section("Challenge") {
            VStack(alignment: .leading, spacing: 8) {
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

                Button("このチャレンジを日記に取り込む") {
                    vm.importToDiary(challenge)
                    vm.refresh()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 6)
        }
    }

    private var replySection: some View {
        Section("Reply") {
            VStack(alignment: .leading, spacing: 10) {
                Text("コメント（200文字まで）").font(.headline)

                TextEditor(text: $commentText)
                    .frame(minHeight: 110)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                Button("コメントリンクを共有") {
                    let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    let url = vm.buildCommentURL(
                        text: trimmed,
                        toChallengeId: challenge.id,
                        room: challenge.link.room,
                        chainId: challenge.link.chainId
                    )

                    let text = "コメント: \(trimmed)\n\(url?.absoluteString ?? "")"
                    share(text, url)
                    commentText = ""
                    vm.refresh()
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Text("リアクション").font(.headline)

                HStack(spacing: 10) {
                    ForEach(emojis, id: \.self) { e in
                        Button(e) {
                            let url = vm.buildReactionURL(
                                emoji: e,
                                toChallengeId: challenge.id,
                                room: challenge.link.room,
                                chainId: challenge.link.chainId
                            )
                            let text = "リアクション \(e)\n\(url?.absoluteString ?? "")"
                            share(text, url)
                            vm.refresh()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func threadSection(items: [CommunityViewModel.ThreadItem]) -> some View {
        Section("Thread") {
            if items.isEmpty {
                Text("まだコメント/リアクションがありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { it in
                    switch it {
                    case .comment(let ev, let isMine):
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(isMine ? "📝 あなた" : "📝 \(ev.link.fromName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(ev.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(ev.link.text).font(.body)
                        }
                        .padding(.vertical, 4)

                    case .reaction(let ev, let isMine):
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
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
