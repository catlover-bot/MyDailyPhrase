import SwiftUI
import Domain

struct CommunityView: View {
    @StateObject private var vm: CommunityViewModel

    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []

    @State private var isCommentComposerPresented = false
    @State private var commentText: String = ""
    @State private var commentTarget: ChallengeEvent? = nil

    init(vm: CommunityViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Room Filter") {
                    TextField("room を入力（空で全件）", text: $vm.roomFilter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("更新") { vm.refresh() }
                }

                // ✅ Room Timeline（roomFilter が入ってる時だけ）
                if !vm.roomFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Room Timeline") {
                        if vm.roomTimeline.isEmpty {
                            Text("このroomのイベントがありません（リンクで受信した分だけ溜まります）")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.roomTimeline) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.title).font(.headline)
                                        Spacer()
                                        Text(item.createdAt, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(item.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Rooms") {
                    if vm.rooms.isEmpty {
                        Text("参加中の room はありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.rooms) { r in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.roomName ?? r.roomId).font(.headline)
                                    if let name = r.roomName {
                                        Text(r.roomId).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button("退出") { vm.leave(roomId: r.roomId) }
                                    .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Divider()

                    TextField("招待する roomId（例: tennis）", text: $vm.inviteRoomId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("roomName（任意）", text: $vm.inviteRoomName)

                    Button("招待リンクを共有") {
                        guard let url = vm.buildInviteURL() else { return }
                        let title = vm.inviteRoomName.isEmpty ? vm.inviteRoomId : vm.inviteRoomName
                        let text = "Room招待: \(title)\n\(url.absoluteString)"
                        shareItems = [SharePayload(text: text, image: nil, url: url)]
                        isSharePresented = true
                        vm.refresh()
                    }
                }

                Section("Invites - Inbox") {
                    if vm.inboxRoomInvites.isEmpty {
                        Text("受信した room 招待はありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.inboxRoomInvites, id: \.id) { inv in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(inv.link.roomName ?? inv.link.roomId).font(.headline)
                                Text("from: \(inv.link.fromName)").font(.subheadline).foregroundStyle(.secondary)

                                HStack {
                                    Button("参加") { vm.joinFromInvite(inv) }
                                    Spacer()
                                    Button("参加を共有") {
                                        guard let url = vm.buildJoinURL(roomId: inv.link.roomId, roomName: inv.link.roomName) else { return }
                                        let text = "Room参加: \(inv.link.roomName ?? inv.link.roomId)\n\(url.absoluteString)"
                                        shareItems = [SharePayload(text: text, image: nil, url: url)]
                                        isSharePresented = true
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Inbox - Challenges") {
                    if vm.inboxChallenges.isEmpty {
                        Text("受信したチャレンジはありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.inboxChallenges, id: \.id) { ev in
                            NavigationLink {
                                ThreadView(
                                    challenge: ev,
                                    vm: vm,
                                    share: { text, url in
                                        shareItems = [SharePayload(text: text, image: nil, url: url)]
                                        isSharePresented = true
                                    }
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(ev.link.prompt).font(.headline)
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
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Inbox - Comments") {
                    if vm.inboxComments.isEmpty {
                        Text("受信したコメントはありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.inboxComments, id: \.id) { ev in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(ev.link.text).font(.headline)
                                Text("from: \(ev.link.fromName)").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Inbox - Reactions") {
                    if vm.inboxReactions.isEmpty {
                        Text("受信したリアクションはありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.inboxReactions, id: \.id) { ev in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(ev.link.emoji)   from: \(ev.link.fromName)").font(.headline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // ✅ NEW: Outbox - Reactions
                Section("Outbox - Reactions") {
                    if vm.outboxReactions.isEmpty {
                        Text("送信したリアクションはありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.outboxReactions, id: \.id) { ev in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(ev.link.emoji)   sent").font(.headline)
                                if let to = ev.link.toChallengeId {
                                    Text("toChallengeId: \(to)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Community")
            .onAppear { vm.refresh() }
            .sheet(isPresented: $isSharePresented) {
                ShareSheet(activityItems: shareItems)
            }
        }
    }
}
