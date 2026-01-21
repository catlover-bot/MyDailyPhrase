import SwiftUI
import UIKit
import Presentation
import Domain

public struct HistoryView: View {
    @StateObject private var vm: HistoryViewModel

    // ✅ 追加：統合共有（テキスト + 画像）
    @State private var isPresentingShareSheet: Bool = false
    @State private var shareSheetItems: [Any] = []
    @State private var isPreparingShare: Bool = false

    public init(viewModel: HistoryViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            List(vm.entries, id: \.dateKey) { entry in
                NavigationLink {
                    EntryDetailView(entry: entry)
                } label: {
                    row(entry)
                }
                // ✅ 追加：投稿（テキスト+画像）
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        presentUnifiedShare(for: entry)
                    } label: {
                        Label(isPreparingShare ? "準備中" : "投稿", systemImage: "paperplane.fill")
                    }
                    .tint(.blue)
                    .disabled(isPreparingShare)
                }
                // 既存：お気に入り
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        vm.toggleFavorite(dateKey: entry.dateKey)
                    } label: {
                        Label(entry.isFavorite ? "解除" : "お気に入り",
                              systemImage: entry.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
            }
            .navigationTitle("履歴")
            .searchable(text: $vm.query, prompt: "検索（お題 / 回答）")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("★だけ", isOn: $vm.onlyFavorites)
                        Toggle("未回答だけ", isOn: $vm.onlyUnanswered)

                        Picker("期間", selection: $vm.period) {
                            ForEach(HistoryPeriod.allCases) { p in
                                Text(p.title).tag(p)
                            }
                        }

                        Divider()

                        Button("リセット") { vm.resetFilters() }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ShareSheet(activityItems: shareSheetItems)
        }
        .onAppear { vm.load() }
    }

    @ViewBuilder
    private func row(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(formatDateKey(entry.dateKey))
                    .font(.headline)

                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .imageScale(.small)
                        .accessibilityLabel("お気に入り")
                }

                Spacer()
            }

            Text(entry.prompt.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let a = (entry.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty {
                Text(a).lineLimit(1)
            } else {
                Text("未回答")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Share (Text + Image)

    @MainActor
    private func presentUnifiedShare(for entry: Entry) {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        let text = shareText(for: entry)
        let model = shareCardModel(for: entry)
        let image = ShareCardRenderer.render(model: model)?.image

        var items: [Any] = [text]
        if let image { items.append(image) }

        shareSheetItems = items
        isPresentingShareSheet = true
    }

    private func shareText(for entry: Entry) -> String {
        let a = (entry.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        【MyDailyPhrase】
        日付: \(formatDateKey(entry.dateKey))
        お題: \(entry.prompt.text)
        回答: \(a.isEmpty ? "（未回答）" : a)
        #MyDailyPhrase
        """
    }

    private func shareCardModel(for entry: Entry) -> ShareCardModel {
        let a = (entry.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ShareCardModel(
            appName: "MyDailyPhrase",
            dateText: formatDateKey(entry.dateKey),
            streakText: "—",
            prompt: entry.prompt.text,
            answer: a.isEmpty ? "（未回答）" : a,
            title: nil,
            summary: nil,
            moodTags: [],
            keywords: []
        )
    }

    // MARK: - Date

    private func formatDateKey(_ key: String) -> String {
        guard key.count == 8 else { return key }
        let y = key.prefix(4)
        let m = key.dropFirst(4).prefix(2)
        let d = key.suffix(2)
        return "\(y)-\(m)-\(d)"
    }
}
