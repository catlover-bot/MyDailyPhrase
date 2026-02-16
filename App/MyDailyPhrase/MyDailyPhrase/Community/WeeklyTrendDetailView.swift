import SwiftUI
import StoreKit

struct WeeklyTrendDetailView: View {
    @ObservedObject var vm: CommunityViewModel
    let trend: CommunityViewModel.WeeklyTrend

    @EnvironmentObject private var store: IAPStore

    private let freePreviewLimit = 3

    private var allItems: [CommunityViewModel.TrendChallengeItem] {
        vm.trendChallenges(for: trend)
    }

    private var visibleItems: [CommunityViewModel.TrendChallengeItem] {
        if store.isCreatorPassActive {
            return allItems
        }
        return Array(allItems.prefix(freePreviewLimit))
    }

    private var hiddenCount: Int {
        max(0, allItems.count - visibleItems.count)
    }

    var body: some View {
        List {
            summarySection
            postsSection
            if hiddenCount > 0, !store.isCreatorPassActive {
                creatorPassSection
            }
        }
        .navigationTitle("バズお題詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summarySection: some View {
        Section("Summary") {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(trend.prompt)
                        .font(.headline)

                    HStack(spacing: 10) {
                        statChip(title: "投稿", value: "\(trend.postCount)")
                        statChip(title: "参加", value: "\(trend.participantCount)")
                        statChip(title: "💬", value: "\(trend.commentCount)")
                        statChip(title: "👍", value: "\(trend.reactionCount)")
                    }

                    if let room = trend.roomSample {
                        Text("room: \(room)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var postsSection: some View {
        Section("Posts") {
            if visibleItems.isEmpty {
                Card {
                    Text("このトレンドに紐づく投稿データはまだありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(visibleItems) { item in
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.isMine ? "あなた" : item.fromName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(Self.timeFormatter.string(from: item.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Text("💬 \(item.commentCount)")
                                Text("👍 \(item.reactionCount)")
                                Text("dateKey \(item.dateKey)")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            if let room = item.room {
                                Text("room: \(room)")
                                    .font(.caption2)
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

    private var creatorPassSection: some View {
        Section("Creator Pass") {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("残り\(hiddenCount)件の投稿は Creator Pass で表示できます。")
                        .font(.subheadline.weight(.semibold))

                    Text(store.creatorPassStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(store.creatorPassBenefitLines, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if store.creatorPassProducts.isEmpty {
                        Text("Creator Pass商品が未設定です（App Store Connect）")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.creatorPassProducts, id: \.id) { product in
                            Button {
                                Task { await store.purchase(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.displayName)
                                            .font(.subheadline.weight(.semibold))
                                        Text(product.description)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .fontWeight(.semibold)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}
