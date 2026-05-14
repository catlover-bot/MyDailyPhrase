import SwiftUI
import UIKit
import Domain
import Presentation

struct ProfileView: View {
    @ObservedObject var vm: ProfileViewModel
    @ObservedObject var gachaVM: GachaViewModel

    @Environment(\.currentDecorationId) private var decorationId

    init(vm: ProfileViewModel, gachaVM: GachaViewModel) {
        self.vm = vm
        self.gachaVM = gachaVM
    }

    private var equippedName: String {
        CardDecorationCatalog.byId(decorationId)?.name ?? decorationId
    }

    private var profileMonogram: String {
        let trimmed = vm.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "M" : trimmed).prefix(1)).uppercased()
    }

    var body: some View {
        Form {
            Section("デコ / ガチャ") {
                Card("現在選択中：\(equippedName)", decorationId: decorationId) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.16))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(profileMonogram)
                                        .font(.headline.weight(.bold))
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(vm.displayName.isEmpty ? "Me" : vm.displayName)
                                    .font(.headline)
                                Text(GachaThemePresentation.sampleProfileLine(
                                    for: CardDecorationCatalog.byId(decorationId) ?? CardDecoration(id: decorationId, name: equippedName, rarity: .common, weight: 0),
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

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("チケット \(gachaVM.tickets)", systemImage: "ticket")
                        Spacer()
                        Label("欠片 \(gachaVM.shards)", systemImage: "seal")
                    }
                    .font(.subheadline)

                    HStack {
                        Text("天井 \(gachaVM.pity)/\(gachaVM.pityMax)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("バナー：\(gachaVM.currentBanner.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        gachaVM.grantDailyTicketIfNeeded()
                    } label: {
                        Label("無料券を受け取る", systemImage: "calendar.badge.plus")
                            .compactActionLabel()
                    }
                        .buttonStyle(.bordered)
                }

                NavigationLink {
                    GachaView(vm: gachaVM)
                } label: {
                    Label("ガチャを開く", systemImage: "sparkles")
                        .compactActionLabel()
                }
            }

            Section("ユーザーID") {
                Text(vm.userId)
                    .font(.footnote)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = vm.userId
                        vm.lastMessage = "User IDをコピーしました"
                    } label: {
                        Label("IDをコピー", systemImage: "doc.on.doc")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: vm.shareProfileText) {
                        Label("プロフィールを共有", systemImage: "square.and.arrow.up")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("利用規約 / プライバシー") {
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

            Section("表示名") {
                TextField("表示名", text: $vm.displayName)
                    .textInputAutocapitalization(.words)

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
                    .disabled(!vm.isDisplayNameChanged)
            }

            Section("アカウント") {
                Card("アカウント情報") {
                    Text(vm.profileSummaryText)
                        .font(.subheadline.weight(.semibold))
                    Text("表示名や装飾は、このデバイス内のプロフィール表示に反映されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let msg = vm.lastMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("プロフィール")
        .onAppear {
            vm.load()
            gachaVM.load()
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
