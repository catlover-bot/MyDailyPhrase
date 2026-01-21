import SwiftUI
import UIKit
import Presentation
import Domain

public struct ReviewView: View {
    @StateObject private var vm: ReviewViewModel

    // ✅ 追加：統合共有（テキスト + 画像）
    @State private var isPresentingShareSheet: Bool = false
    @State private var shareSheetItems: [Any] = []
    @State private var isPreparingShare: Bool = false

    public init(viewModel: ReviewViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ReviewGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // 操作（シャッフル / 投稿）
                        HStack {
                            Button {
                                vm.shuffle()
                            } label: {
                                Label("シャッフル", systemImage: "shuffle")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()

                            Button {
                                if let w = currentWork { presentUnifiedShare(for: w) }
                            } label: {
                                Label(isPreparingShare ? "準備中" : "投稿", systemImage: "paperplane.fill")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isPreparingShare || currentWork == nil)
                        }

                        // ランダム（作品）
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "ピックアップ作品", systemImage: "sparkles")
                                if let w = vm.randomWork {
                                    WorkCard(work: w, onPost: { presentUnifiedShare(for: $0) })
                                } else {
                                    EmptyWork(text: "記録がありません")
                                }
                            }
                        }

                        // 過去カード（1年/1週/1ヶ月）
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "過去の自分", systemImage: "clock.arrow.circlepath")

                                WorkSlot(title: "1年前の今日", work: vm.oneYearAgoWork, onPost: { presentUnifiedShare(for: $0) })
                                WorkSlot(title: "1週間前", work: vm.oneWeekAgoWork, onPost: { presentUnifiedShare(for: $0) })
                                WorkSlot(title: "1ヶ月前", work: vm.oneMonthAgoWork, onPost: { presentUnifiedShare(for: $0) })
                            }
                        }

                        // 統計（直近7日 / 30日）
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "統計", systemImage: "chart.bar.fill")

                                SummaryCard(title: vm.weekSummaryTitle, summary: vm.weekSummary)
                                SummaryCard(title: vm.monthSummaryTitle, summary: vm.monthSummary)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("振り返り")
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ShareSheet(activityItems: shareSheetItems)
        }
        .onAppear { vm.load() }
    }

    // 投稿対象（優先順位）
    private var currentWork: EntryWork? {
        vm.randomWork ?? vm.oneYearAgoWork ?? vm.oneWeekAgoWork ?? vm.oneMonthAgoWork
    }

    // MARK: - Unified Share (Text + Image)

    @MainActor
    private func presentUnifiedShare(for work: EntryWork) {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        let text = shareText(for: work)
        let model = shareCardModel(for: work)
        let image = ShareCardRenderer.render(model: model)?.image

        var items: [Any] = [text]
        if let image { items.append(image) }

        shareSheetItems = items
        isPresentingShareSheet = true
    }

    private func shareText(for work: EntryWork) -> String {
        let tags = work.artifact.moodTags.isEmpty ? "" : " / " + work.artifact.moodTags.joined(separator: "・")
        return """
        【MyDailyPhrase】\(work.artifact.title)\(tags)
        日付: \(formatDateKey(work.dateKey))
        お題: \(work.promptText)
        要約: \(work.artifact.summary)
        回答: \(work.answerText.isEmpty ? "（未回答）" : work.answerText)
        #MyDailyPhrase
        """
    }

    private func shareCardModel(for work: EntryWork) -> ShareCardModel {
        ShareCardModel(
            appName: "MyDailyPhrase",
            dateText: formatDateKey(work.dateKey),
            streakText: "—",
            prompt: work.promptText,
            answer: work.answerText.isEmpty ? "（未回答）" : work.answerText,
            title: work.artifact.title,
            summary: work.artifact.summary,
            moodTags: work.artifact.moodTags,
            keywords: work.artifact.keywords
        )
    }

    private func formatDateKey(_ key: String) -> String {
        guard key.count == 8 else { return key }
        let y = key.prefix(4)
        let m = key.dropFirst(4).prefix(2)
        let d = key.suffix(2)
        return "\(y)-\(m)-\(d)"
    }
}

// MARK: - Private UI Parts

private struct ReviewGradientBackground: View {
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
        .ignoresSafeArea()
        .overlay(
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.10),
                    Color.pink.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()
        )
    }
}

private struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.10))
            )
    }
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
        }
    }
}

private struct WorkSlot: View {
    let title: String
    let work: EntryWork?
    let onPost: (EntryWork) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let w = work {
                WorkCard(work: w, onPost: onPost)
            } else {
                EmptyWork(text: "該当日の記録はありません")
            }
        }
    }
}

private struct WorkCard: View {
    let work: EntryWork
    let onPost: (EntryWork) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDateKey(work.dateKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(work.artifact.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Text(work.artifact.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !work.artifact.moodTags.isEmpty {
                ChipRow(tags: work.artifact.moodTags, symbol: "tag.fill")
            }
            if !work.artifact.keywords.isEmpty {
                ChipRow(tags: Array(work.artifact.keywords.prefix(6)), symbol: "number")
            }

            if !work.answerText.isEmpty {
                Text(work.answerText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text("未回答")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            HStack {
                Spacer()
                Button {
                    onPost(work)
                } label: {
                    Label("投稿", systemImage: "paperplane.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.10))
        )
    }

    private func formatDateKey(_ key: String) -> String {
        guard key.count == 8 else { return key }
        let y = key.prefix(4)
        let m = key.dropFirst(4).prefix(2)
        let d = key.suffix(2)
        return "\(y)-\(m)-\(d)"
    }
}

private struct EmptyWork: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ChipRow: View {
    let tags: [String]
    let symbol: String

    private let cols: [GridItem] = [GridItem(.adaptive(minimum: 70), spacing: 8, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { t in
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(t)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.10)))
            }
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let summary: ReviewSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let s = summary ?? ReviewSummary(answeredCount: 0, avgChars: nil, topWeekday: nil)

            HStack {
                Metric(title: "回答数", value: "\(s.answeredCount)")
                Spacer()
                Metric(title: "平均文字数", value: s.avgCharsText)
                Spacer()
                Metric(title: "最多曜日", value: s.topWeekdayText)
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct Metric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
