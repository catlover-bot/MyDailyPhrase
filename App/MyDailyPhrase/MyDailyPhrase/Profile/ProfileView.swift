import SwiftUI
import UIKit
import Domain
import Presentation

struct ProfileView: View {
    @ObservedObject var vm: ProfileViewModel
    @ObservedObject var gachaVM: GachaViewModel
    @ObservedObject var communityLiteVM: CommunityLiteViewModel

    @Environment(\.currentDecorationId) private var decorationId
    @EnvironmentObject private var iap: IAPStore

    init(vm: ProfileViewModel, gachaVM: GachaViewModel, communityLiteVM: CommunityLiteViewModel) {
        self.vm = vm
        self.gachaVM = gachaVM
        self.communityLiteVM = communityLiteVM
    }

    private var equippedName: String {
        CardDecorationCatalog.byId(decorationId)?.name ?? decorationId
    }

    private var equippedItem: CardDecoration {
        CardDecorationCatalog.byId(decorationId)
            ?? CardDecoration(id: CardDecorationCatalog.classicId, name: equippedName, rarity: .common, weight: 0)
    }

    private var equippedTitle: String? {
        GachaThemePresentation.profileTitle(for: equippedItem)
    }

    private var profileMonogram: String {
        let trimmed = vm.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "M" : trimmed).prefix(1)).uppercased()
    }

    private var joinedCommunitySummary: String {
        let names = communityLiteVM.joinedCommunities.prefix(3).map(\.name)
        guard !names.isEmpty else {
            return "まだ参加中の部屋はありません"
        }
        let suffix = communityLiteVM.joinedCommunities.count > 3 ? " ほか" : ""
        return names.joined(separator: " / ") + suffix
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeroCard(
                    eyebrow: "あなたの見た目と肩書き",
                    title: vm.displayName.isEmpty ? "Me" : vm.displayName,
                    subtitle: "集めたテーマや称号は、プロフィールカード・共有カード・コミュニティカードの見た目に反映されます。",
                    accent: .purple
                ) {
                    Card("現在選択中：\(equippedName)", decorationId: decorationId) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.16))
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Text(profileMonogram)
                                            .font(.headline.weight(.bold))
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vm.displayName.isEmpty ? "Me" : vm.displayName)
                                        .font(.headline)
                                    if let equippedTitle {
                                        Text(equippedTitle)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.thinMaterial)
                                            .clipShape(Capsule())
                                    }
                                    Text(GachaThemePresentation.sampleProfileLine(
                                        for: equippedItem,
                                        isEquipped: true
                                    ))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Text("この見た目がプロフィールカード、ガチャ結果プレビュー、共有カードに反映されます。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            if let equippedTitle {
                                InfoBadge(title: equippedTitle, systemImage: "sparkles", tint: .purple)
                            }
                            InfoBadge(title: "参加中 \(communityLiteVM.joinedCommunities.count) 部屋", systemImage: "person.2", tint: .green)
                            InfoBadge(title: "装備中 \(equippedName)", systemImage: "paintbrush.pointed", tint: .blue)
                            if iap.isCreatorPassActive {
                                PremiumBadge(title: "Creator Pass")
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            if let equippedTitle {
                                InfoBadge(title: equippedTitle, systemImage: "sparkles", tint: .purple)
                            }
                            InfoBadge(title: "参加中 \(communityLiteVM.joinedCommunities.count) 部屋", systemImage: "person.2", tint: .green)
                            InfoBadge(title: "装備中 \(equippedName)", systemImage: "paintbrush.pointed", tint: .blue)
                            if iap.isCreatorPassActive {
                                PremiumBadge(title: "Creator Pass")
                            }
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            ShareLink(item: vm.shareProfileText) {
                                Label("プロフィールカードを共有", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            NavigationLink {
                                GachaView(vm: gachaVM)
                            } label: {
                                Label("コレクションを見る", systemImage: "square.grid.2x2")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        VStack(spacing: 10) {
                            ShareLink(item: vm.shareProfileText) {
                                Label("プロフィールカードを共有", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            NavigationLink {
                                GachaView(vm: gachaVM)
                            } label: {
                                Label("コレクションを見る", systemImage: "square.grid.2x2")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                AppSectionCard(
                    title: "ガチャと装備",
                    subtitle: "集めたアイテムはプロフィール、共有カード、コミュニティカードの見た目に使えます。"
                ) {
                    LazyVGrid(columns: [.init(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                        SummaryMetricTile(
                            title: "チケット",
                            value: "\(gachaVM.tickets)",
                            detail: "単発や10連に使えます",
                            systemImage: "ticket.fill",
                            tint: .blue
                        )
                        SummaryMetricTile(
                            title: "欠片",
                            value: "\(gachaVM.shards)",
                            detail: "重複アイテムで増えます",
                            systemImage: "seal.fill",
                            tint: .orange
                        )
                        SummaryMetricTile(
                            title: "レア保証",
                            value: "\(gachaVM.pity)/\(gachaVM.pityMax)",
                            detail: "天井までの進み具合",
                            systemImage: "sparkles",
                            tint: .purple
                        )
                        SummaryMetricTile(
                            title: "参加中の部屋",
                            value: "\(communityLiteVM.joinedCommunities.count)部屋",
                            detail: joinedCommunitySummary,
                            systemImage: "person.2.fill",
                            tint: .green
                        )
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            Button {
                                gachaVM.grantDailyTicketIfNeeded()
                            } label: {
                                Label("無料券を受け取る", systemImage: "calendar.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            NavigationLink {
                                GachaView(vm: gachaVM)
                            } label: {
                                Label("ガチャを開く", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        VStack(spacing: 10) {
                            Button {
                                gachaVM.grantDailyTicketIfNeeded()
                            } label: {
                                Label("無料券を受け取る", systemImage: "calendar.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            NavigationLink {
                                GachaView(vm: gachaVM)
                            } label: {
                                Label("ガチャを開く", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                AppSectionCard(
                    title: "コミュニティとCreator Pass",
                    subtitle: "参加者は無料のまま、Creator Pass でコミュニティ作成とお題カスタマイズを解放できます。"
                ) {
                    if iap.isCreatorPassActive {
                        Label("コミュニティ作成が有効です", systemImage: "crown.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else {
                        Text("コミュニティへの参加は無料です。Creator Pass はコミュニティ作成とカスタマイズだけを解放します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(joinedCommunitySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                AppSectionCard(
                    title: "表示名",
                    subtitle: "プロフィールカードや共有カードに表示される名前です。"
                ) {
                    TextField("表示名", text: $vm.displayName)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)

                    Text(vm.displayNameHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if vm.normalizedDisplayNamePreview != vm.displayName.trimmingCharacters(in: .whitespacesAndNewlines) {
                        HStack {
                            Text("保存後")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(vm.normalizedDisplayNamePreview)
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    Button("保存") { vm.save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vm.isDisplayNameChanged)
                }

                AppSectionCard(
                    title: "ユーザーIDと共有",
                    subtitle: "プロフィール交換や問い合わせ時に使える、この端末の識別用 ID です。"
                ) {
                    Text(vm.userId)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            Button {
                                UIPasteboard.general.string = vm.userId
                                vm.lastMessage = "User IDをコピーしました"
                            } label: {
                                Label("IDをコピー", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            ShareLink(item: vm.shareProfileText) {
                                Label("プロフィールを共有", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        VStack(spacing: 10) {
                            Button {
                                UIPasteboard.general.string = vm.userId
                                vm.lastMessage = "User IDをコピーしました"
                            } label: {
                                Label("IDをコピー", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            ShareLink(item: vm.shareProfileText) {
                                Label("プロフィールを共有", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                AppSectionCard(
                    title: "利用規約 / プライバシー",
                    subtitle: "公開前に確認しておきたいルールとサポート情報です。"
                ) {
                    if let termsURL = vm.termsOfServiceURL {
                        Link(destination: termsURL) {
                            Label("利用規約", systemImage: "doc.text")
                        }
                    }

                    if let privacyURL = vm.privacyPolicyURL {
                        Link(destination: privacyURL) {
                            Label("プライバシーポリシー", systemImage: "hand.raised")
                        }
                    }

                    ForEach(vm.legalReadinessNotes, id: \.self) { note in
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let msg = vm.lastMessage {
                    AppSectionCard(title: "お知らせ") {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(AppScreenBackground())
        .navigationTitle("プロフィール")
        .onAppear {
            vm.load()
            gachaVM.load()
            communityLiteVM.load()
        }
    }

    private func notificationABDashboardCard(
        _ row: ProfileViewModel.NotificationABDashboardRow
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(row.optimizationLabel)
                    .font(.caption.weight(.semibold))
            }

            Text("\(row.confidenceLabel) / 送信 \(row.totalSent)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("文言別実測")
                .accessibilityIdentifier("profile.notifications.ab.variantHeader.\(row.id)")
                .font(.caption.weight(.semibold))
            ForEach(row.variants) { variant in
                notificationABVariantRowView(variant, compact: false)
            }

            if !row.weekdayRows.isEmpty {
                Divider()
                Text("曜日別実測")
                    .accessibilityIdentifier("profile.notifications.ab.weekdayHeader.\(row.id)")
                    .font(.caption.weight(.semibold))
                ForEach(row.weekdayRows) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(day.weekdayLabel)曜日")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(day.winnerLabel)
                                .font(.caption2.weight(.semibold))
                        }
                        Text("\(day.confidenceLabel) / 送信 \(day.totalSent)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(day.variants) { variant in
                            notificationABVariantRowView(variant, compact: true)
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            if !row.timingSlots.isEmpty {
                Divider()
                Text("時間帯別実測（リマインド通知）")
                    .accessibilityIdentifier("profile.notifications.ab.timingHeader.\(row.id)")
                    .font(.caption.weight(.semibold))
                ForEach(row.timingSlots) { slot in
                    notificationTimingRowView(slot, compact: false)
                }

                if !row.timingWeekdayRows.isEmpty {
                    Text("曜日 × 時間帯")
                        .accessibilityIdentifier("profile.notifications.ab.weekdayTimingHeader.\(row.id)")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 2)
                    ForEach(row.timingWeekdayRows) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(day.weekdayLabel)曜日")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text(day.optimizationLabel)
                                    .font(.caption2.weight(.semibold))
                            }
                            Text("\(day.confidenceLabel) / 送信 \(day.totalSent)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ForEach(day.slots) { slot in
                                notificationTimingRowView(slot, compact: true)
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func notificationABVariantRowView(
        _ variant: ProfileViewModel.NotificationABVariantRow,
        compact: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Text(variant.label)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .frame(width: compact ? 38 : 48, alignment: .leading)
            Text("送信 \(variant.sent)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("開封 \(variant.openRateText)")
                .font(.caption2)
            Text("復帰 \(variant.returnRateText)")
                .font(.caption2)
            Text("総合 \(variant.weightedScoreText)")
                .font(.caption2)
        }
    }

    private func notificationTimingRowView(
        _ slot: ProfileViewModel.NotificationTimingSlotRow,
        compact: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Text(slot.label)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .frame(width: compact ? 42 : 48, alignment: .leading)
            Text("送信 \(slot.sent)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("開封 \(slot.openRateText)")
                .font(.caption2)
            Text("復帰 \(slot.returnRateText)")
                .font(.caption2)
            Text("総合 \(slot.weightedScoreText)")
                .font(.caption2)
        }
    }
}

private extension View {
    func compactActionLabel() -> some View {
        labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .truncationMode(.tail)
    }
}
