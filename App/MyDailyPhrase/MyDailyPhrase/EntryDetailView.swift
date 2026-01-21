import SwiftUI
import UIKit
import Domain

struct EntryDetailView: View {
    let entry: Entry
    @State private var copied = false

    // ✅ 追加：統合共有
    @State private var isPresentingShareSheet: Bool = false
    @State private var shareSheetItems: [Any] = []
    @State private var isPreparingShare: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(formatDateKey(entry.dateKey))
                    .font(.headline)

                Group {
                    Text("お題")
                        .font(.headline)
                    Text(entry.prompt.text)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Group {
                    Text("回答")
                        .font(.headline)

                    let a = (entry.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if a.isEmpty {
                        Text("未回答")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(a)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                HStack {
                    Button("コピー") {
                        UIPasteboard.general.string = shareText
                        copied = true
                    }
                    .buttonStyle(.bordered)

                    Button {
                        presentUnifiedShare()
                    } label: {
                        Label(isPreparingShare ? "準備中" : "投稿", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPreparingShare)
                }
            }
            .padding()
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .alert("コピーしました", isPresented: $copied) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ShareSheet(activityItems: shareSheetItems)
        }
    }

    // MARK: - Share

    private var shareText: String {
        let a = (entry.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        【MyDailyPhrase】
        日付: \(formatDateKey(entry.dateKey))
        お題: \(entry.prompt.text)
        回答: \(a.isEmpty ? "（未回答）" : a)
        #MyDailyPhrase
        """
    }

    private func shareCardModel() -> ShareCardModel {
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

    @MainActor
    private func presentUnifiedShare() {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        let image = ShareCardRenderer.render(model: shareCardModel())?.image

        var items: [Any] = [shareText]
        if let image { items.append(image) }

        shareSheetItems = items
        isPresentingShareSheet = true
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
