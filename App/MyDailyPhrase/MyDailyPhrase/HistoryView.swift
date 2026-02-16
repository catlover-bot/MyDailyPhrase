import SwiftUI
import Presentation
import Domain

public struct HistoryView: View {
    @StateObject private var vm: HistoryViewModel

    @Environment(\.currentDecorationId) private var decorationId

    // ✅ 統合共有（SharePayload）
    @State private var isPresentingShareSheet: Bool = false
    @State private var shareSheetItems: [Any] = []
    @State private var isPreparingShare: Bool = false

    public init(viewModel: HistoryViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                HistoryGradientBackground()
                    .ignoresSafeArea()

                List(vm.entries, id: \.dateKey) { entry in
                    NavigationLink {
                        EntryDetailView(entry: entry)
                    } label: {
                        // ✅ Row を Card で包む（装飾反映）
                        Card {
                            rowContent(entry)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                    // ✅ 投稿（SharePayloadで安定化）
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            presentUnifiedShare(for: entry)
                        } label: {
                            Label(isPreparingShare ? "準備中" : "投稿", systemImage: "paperplane.fill")
                        }
                        .tint(.blue)
                        .disabled(isPreparingShare)
                    }

                    // ✅ お気に入り
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
        .task { vm.load() } // onAppearより安全（画面復帰時の多重ロード抑制）
    }

    // MARK: - Row

    @ViewBuilder
    private func rowContent(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

        // ✅ Homeと同じ方式：SharePayload（テキストが落ちにくい）
        let payload = SharePayload(text: text, image: image, url: nil)
        shareSheetItems = [payload]
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
            keywords: [],
            decorationId: decorationId
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

// MARK: - Background

private struct HistoryGradientBackground: View {
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
