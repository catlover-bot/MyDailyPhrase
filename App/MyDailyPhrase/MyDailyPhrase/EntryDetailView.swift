import SwiftUI
import UIKit
import Domain
import Presentation

struct EntryDetailView: View {
    let entry: Entry

    @Environment(\.currentDecorationId) private var decorationId
    @State private var copied = false

    // ✅ 統合共有
    @State private var isPresentingShareSheet: Bool = false
    @State private var shareSheetItems: [Any] = []
    @State private var isPreparingShare: Bool = false

    var body: some View {
        ZStack {
            DetailGradientBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Card {
                        HStack {
                            Text(formatDateKey(entry.dateKey))
                                .font(.headline)
                            Spacer()
                        }
                    }

                    Card("お題") {
                        Text(entry.prompt.text)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Card("回答") {
                        let a = (entry.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if a.isEmpty {
                            Text("未回答")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(a)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.white.opacity(0.10))
                                )
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = shareText
                            copied = true
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            presentUnifiedShare()
                        } label: {
                            Label(isPreparingShare ? "準備中" : "投稿", systemImage: "paperplane.fill")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPreparingShare)

                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .padding()
            }
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
            keywords: [],
            decorationId: decorationId
        )
    }

    @MainActor
    private func presentUnifiedShare() {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        let image = ShareCardRenderer.render(model: shareCardModel())?.image

        // ✅ SharePayloadで安定化
        let payload = SharePayload(text: shareText, image: image, url: nil)
        shareSheetItems = [payload]
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

// MARK: - Background

private struct DetailGradientBackground: View {
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
