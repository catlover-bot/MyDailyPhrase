import SwiftUI
import Domain
import Presentation

struct CommunityView: View {
    @StateObject private var vm: CommunityViewModel

    @Environment(\.currentDecorationId) private var decorationId

    // ✅ SharePayload で統一
    @State private var isPresentingShareSheet = false
    @State private var shareSheetItems: [Any] = []

    init(vm: CommunityViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CommunityGradientBackground()
                    .ignoresSafeArea()

                List {
                    roomFilterSection

                    if showRoomTimeline {
                        roomTimelineSection
                    }

                    roomsSection
                    invitesInboxSection
                    challengesInboxSection
                    commentsInboxSection
                    reactionsInboxSection
                    reactionsOutboxSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .refreshable { vm.refresh() } // ✅ Pull-to-refresh
            }
            .navigationTitle("Community")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.refresh() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("更新")
                }
            }
            .task { vm.refresh() } // ✅ onAppear より多重実行しにくい
            .sheet(isPresented: $isPresentingShareSheet) {
                ShareSheet(activityItems: shareSheetItems)
            }
        }
    }

    // MARK: - Share Helper

    @MainActor
    private func presentShare(text: String, image: UIImage? = nil, url: URL? = nil) {
        let payload = SharePayload(text: text, image: image, url: url)
        shareSheetItems = [payload]
        isPresentingShareSheet = true
    }

    // MARK: - Sections

    private var roomFilterSection: some View {
        Section("Room Filter") {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("room を入力（空で全件）", text: $vm.roomFilter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { vm.refresh() } // ✅ Enterで更新

                    HStack(spacing: 10) {
                        Button {
                            vm.refresh()
                        } label: {
                            Label("更新", systemImage: "arrow.clockwise")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        if !vm.roomFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                vm.roomFilter = ""
                                vm.refresh()
                            } label: {
                                Label("解除", systemImage: "xmark.circle")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var showRoomTimeline: Bool {
        !vm.roomFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var roomTimelineSection: some View {
        Section("Room Timeline") {
            if vm.roomTimeline.isEmpty {
                Card {
                    Text("このroomのイベントがありません（リンクで受信した分だけ溜まります）")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.roomTimeline) { item in
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.title)
                                    .font(.headline)
                                Spacer()
                                Text(item.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var roomsSection: some View {
        Section("Rooms") {
            if vm.rooms.isEmpty {
                Card {
                    Text("参加中の room はありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.rooms) { r in
                    Card {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.roomName ?? r.roomId)
                                    .font(.headline)
                                if r.roomName != nil {
                                    Text(r.roomId)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                vm.leave(roomId: r.roomId)
                            } label: {
                                Label("退出", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            Card("招待リンクを作る") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("招待する roomId（例: tennis）", text: $vm.inviteRoomId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    TextField("roomName（任意）", text: $vm.inviteRoomName)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        guard let url = vm.buildInviteURL() else { return }
                        let title = vm.inviteRoomName.isEmpty ? vm.inviteRoomId : vm.inviteRoomName
                        let text = "Room招待: \(title)\n#MyDailyPhrase"
                        presentShare(text: text, url: url)
                        vm.refresh()
                    } label: {
                        Label("招待リンクを共有", systemImage: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.inviteRoomId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var invitesInboxSection: some View {
        Section("Invites - Inbox") {
            if vm.inboxRoomInvites.isEmpty {
                Card {
                    Text("受信した room 招待はありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.inboxRoomInvites, id: \.id) { inv in
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(inv.link.roomName ?? inv.link.roomId)
                                    .font(.headline)
                                Text("from: \(inv.link.fromName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    vm.joinFromInvite(inv)
                                } label: {
                                    Label("参加", systemImage: "person.badge.plus")
                                        .fontWeight(.semibold)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Spacer()

                                Button {
                                    guard let url = vm.buildJoinURL(roomId: inv.link.roomId, roomName: inv.link.roomName) else { return }
                                    let text = "Room参加: \(inv.link.roomName ?? inv.link.roomId)\n#MyDailyPhrase"
                                    presentShare(text: text, url: url)
                                } label: {
                                    Label("参加を共有", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var challengesInboxSection: some View {
        Section("Inbox - Challenges") {
            if vm.inboxChallenges.isEmpty {
                Card {
                    Text("受信したチャレンジはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.inboxChallenges, id: \.id) { ev in
                    NavigationLink {
                        ThreadView(
                            challenge: ev,
                            vm: vm,
                            shareItems: { items in
                                shareSheetItems = items
                                isPresentingShareSheet = true
                            }
                        )
                    } label: {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(ev.link.prompt)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Spacer()
                                    let c = vm.commentCount(for: ev.id)
                                    let r = vm.reactionCount(for: ev.id)
                                    if c > 0 { Text("💬 \(c)").font(.caption).foregroundStyle(.secondary) }
                                    if r > 0 { Text("👍 \(r)").font(.caption).foregroundStyle(.secondary) }
                                }

                                Text("from: \(ev.link.fromName)   dateKey: \(ev.link.dateKey)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 12) {
                                    if let room = ev.link.room { Text("room: \(room)") }
                                    if let chain = ev.link.chainId { Text("chain: \(chain)") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var commentsInboxSection: some View {
        Section("Inbox - Comments") {
            if vm.inboxComments.isEmpty {
                Card {
                    Text("受信したコメントはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.inboxComments, id: \.id) { ev in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ev.link.text)
                                .font(.headline)
                                .lineLimit(3)
                            Text("from: \(ev.link.fromName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var reactionsInboxSection: some View {
        Section("Inbox - Reactions") {
            if vm.inboxReactions.isEmpty {
                Card {
                    Text("受信したリアクションはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.inboxReactions, id: \.id) { ev in
                    Card {
                        Text("\(ev.link.emoji)   from: \(ev.link.fromName)")
                            .font(.headline)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var reactionsOutboxSection: some View {
        Section("Outbox - Reactions") {
            if vm.outboxReactions.isEmpty {
                Card {
                    Text("送信したリアクションはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.outboxReactions, id: \.id) { ev in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(ev.link.emoji)   sent")
                                .font(.headline)
                            if let to = ev.link.toChallengeId {
                                Text("toChallengeId: \(to)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }
}

// MARK: - Background

private struct CommunityGradientBackground: View {
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
