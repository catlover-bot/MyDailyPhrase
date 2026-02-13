import SwiftUI
import UIKit
import Presentation
import Domain

public struct HomeView: View {
    @StateObject private var vm: HomeViewModel

    // ✅ 現在の装飾ID（RootViewから配布される）
    @Environment(\.currentDecorationId) private var decorationId

    // 画像生成・入力フォーカス
    @State private var shareImage: ShareImage?
    @State private var isPreparingShareImage: Bool = false
    @FocusState private var isAnswerFocused: Bool

    // トースト
    @State private var toastText: String = ""
    @State private var showToast: Bool = false

    // 統合共有（テキスト + 画像）
    @State private var isPresentingShareSheet: Bool = false
    @State private var shareSheetItems: [Any] = []
    @State private var tempShareFileURL: URL? = nil

    // ✅ チャレンジ表示用 sheet
    @State private var isPresentingChallenge: Bool = false

    // 共有テキスト形式
    @State private var shareFormat: ShareFormat = .x

    public init(viewModel: HomeViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    private var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var answerBinding: Binding<String> {
        Binding(get: { vm.answerText }, set: { vm.answerText = $0 })
    }

    private var shareText: String {
        buildShareText(format: shareFormat)
    }

    // ✅ 共有に載せるチャレンジURL（QR/URL）
    private var challengeURL: URL? {
        let tz = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let todayKey = DateKey.todayKey(timeZone: tz)
        return URL(string: "mydailyphrase://challenge?dateKey=\(todayKey)")
    }

    private var shareCardModel: ShareCardModel {
        let prompt = vm.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = vm.answerText.trimmingCharacters(in: .whitespacesAndNewlines)

        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = .current
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        let dateText = df.string(from: Date())

        // ✅ decorationId は Environment を採用（UIと共有カードが一致する）
        if let art = vm.todayArtifact {
            return ShareCardModel(
                appName: "MyDailyPhrase",
                dateText: dateText,
                streakText: "\(vm.streak)日",
                prompt: prompt,
                answer: answer.isEmpty ? "（未回答）" : answer,
                title: art.title,
                summary: art.summary,
                moodTags: art.moodTags,
                keywords: art.keywords,
                decorationId: decorationId,
                shareURL: challengeURL
            )
        } else {
            return ShareCardModel(
                appName: "MyDailyPhrase",
                dateText: dateText,
                streakText: "\(vm.streak)日",
                prompt: prompt,
                answer: answer.isEmpty ? "（未回答）" : answer,
                title: nil,
                summary: nil,
                moodTags: [],
                keywords: [],
                decorationId: decorationId,
                shareURL: challengeURL
            )
        }
    }

    @MainActor
    private func presentUnifiedShare() {
        guard !isRunningForPreviews else {
            toast("Previewでは共有シートを開けません（実機/Simulator実行で確認してください）")
            return
        }
        guard !isPreparingShareImage else { return }

        isPreparingShareImage = true
        defer { isPreparingShareImage = false }

        shareImage = ShareCardRenderer.render(model: shareCardModel)

        let uiImage = shareImage?.image
        let linkURL = shareCardModel.shareURL

        let payload = SharePayload(text: shareText, image: uiImage, url: linkURL)

        var items: [Any] = [payload]
        if let uiImage { items.append(uiImage) }
        if let linkURL { items.append(linkURL) }

        shareSheetItems = items
        isPresentingShareSheet = true
    }

    private func cleanupTempShareFile() {
        guard let url = tempShareFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        tempShareFileURL = nil
    }

    private func toast(_ message: String) {
        toastText = message
        withAnimation(.easeInOut(duration: 0.18)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.18)) { showToast = false }
        }
    }

    private func copyCaption() {
        UIPasteboard.general.string = shareText
        toast("キャプションをコピーしました")
    }

    // ✅ Challenge sheet 本体
    @ViewBuilder
    private var challengeSheetView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("チャレンジが届きました")
                    .font(.title2).bold()

                Text("お題").font(.headline)

                Text(vm.incomingChallenge?.prompt.text ?? "（読み込み失敗）")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("回答")
                    .font(.headline)
                    .padding(.top, 6)

                TextEditor(text: Binding(
                    get: { vm.challengeAnswerText },
                    set: { vm.challengeAnswerText = $0 }
                ))
                .frame(minHeight: 240)
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.secondary.opacity(0.18))
                )

                Spacer()

                HStack(spacing: 12) {
                    Button("閉じる") { isPresentingChallenge = false }
                        .buttonStyle(.bordered)

                    Spacer()

                    Button("保存") { vm.saveIncomingChallengeAnswer() }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.challengeAnswerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Challenge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { isPresentingChallenge = false }
                }
            }
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                HomeGradientBackground()
                    .ignoresSafeArea(.keyboard, edges: .bottom)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        HStack(spacing: 10) {
                            Button { presentUnifiedShare() } label: {
                                Label(isPreparingShareImage ? "準備中" : "投稿", systemImage: "paperplane.fill")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isPreparingShareImage)

                            Menu {
                                Picker("共有形式", selection: $shareFormat) {
                                    ForEach(ShareFormat.allCases, id: \.self) { f in
                                        Label(f.title, systemImage: f.systemImage).tag(f)
                                    }
                                }
                            } label: {
                                Label(shareFormat.shortTitle, systemImage: "slider.horizontal.3")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.bordered)

                            Button { copyCaption() } label: {
                                Label("コピー", systemImage: "doc.on.doc")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                Text("\(vm.streak)日").fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "今日のお題", systemImage: "quote.opening")
                                Text(vm.promptText)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "回答", systemImage: "square.and.pencil")

                                TextEditor(text: answerBinding)
                                    .focused($isAnswerFocused)
                                    .frame(minHeight: 140)
                                    .padding(10)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(.secondary.opacity(0.18))
                                    )

                                HStack {
                                    Text("文字数").foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(vm.answerText.trimmingCharacters(in: .whitespacesAndNewlines).count)")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    SectionHeader(title: "作品プレビュー", systemImage: "sparkles")
                                    Spacer()
                                    if vm.todayArtifact == nil {
                                        Text("保存すると生成")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let art = vm.todayArtifact {
                                    Text(art.title)
                                        .font(.title2)
                                        .fontWeight(.heavy)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(art.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if !art.moodTags.isEmpty {
                                        TagGrid(tags: art.moodTags, accentSymbol: "tag.fill")
                                    }
                                    if !art.keywords.isEmpty {
                                        TagGrid(tags: art.keywords, accentSymbol: "number")
                                    }
                                } else {
                                    Text("まだ作品がありません。回答を書いて保存すると、題名・要約・タグが自動生成されます。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        Button { vm.submit() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "tray.and.arrow.down.fill")
                                Text(vm.isAnsweredToday ? "更新して保存" : "保存する")
                                    .fontWeight(.heavy)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(vm.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if vm.hasOneYearAgo {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionHeader(title: "1年前の今日", systemImage: "clock.arrow.circlepath")

                                    Text(vm.oneYearAgoPrompt)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if let art = vm.oneYearAgoArtifact {
                                        Text(art.title)
                                            .font(.title3)
                                            .fontWeight(.bold)

                                        Text(art.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        if !art.moodTags.isEmpty {
                                            TagGrid(tags: art.moodTags, accentSymbol: "tag.fill")
                                        }
                                    }

                                    Text(vm.oneYearAgoAnswer)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.thinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)

                if showToast {
                    Text(toastText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .navigationTitle("MyDailyPhrase")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { isAnswerFocused = false }
                }
            }
        }
        .sheet(isPresented: $isPresentingShareSheet, onDismiss: {
            cleanupTempShareFile()
        }) {
            ShareSheet(activityItems: shareSheetItems)
        }
        .sheet(isPresented: $isPresentingChallenge, onDismiss: {
            vm.clearIncomingChallenge()
        }) {
            challengeSheetView
        }
        .onAppear {
            vm.load()
            shareImage = nil
        }
        .onChange(of: vm.saveMessage) { _, newValue in
            guard let msg = newValue else { return }
            toast(msg)
            vm.clearSaveMessage()
            shareImage = nil
        }
        .onChange(of: vm.incomingChallenge?.dateKey ?? "") { _, _ in
            if vm.incomingChallenge != nil { isPresentingChallenge = true }
        }
    }

    // MARK: - Share text builder

    private enum ShareFormat: CaseIterable {
        case x, instagram, line

        var title: String {
            switch self {
            case .x: return "X（短文）"
            case .instagram: return "Instagram（長文）"
            case .line: return "LINE（シンプル）"
            }
        }
        var shortTitle: String {
            switch self {
            case .x: return "X"
            case .instagram: return "IG"
            case .line: return "LINE"
            }
        }
        var systemImage: String {
            switch self {
            case .x: return "text.bubble"
            case .instagram: return "photo.on.rectangle"
            case .line: return "message"
            }
        }
    }

    private func buildShareText(format: ShareFormat) -> String {
        let prompt = vm.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = vm.answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = challengeURL?.absoluteString ?? ""

        if let art = vm.todayArtifact {
            let tags = art.moodTags.isEmpty ? "" : " / " + art.moodTags.joined(separator: "・")
            switch format {
            case .x:
                return """
                【MyDailyPhrase】\(art.title)\(tags)
                お題: \(prompt)
                回答: \(answer.isEmpty ? "（未回答）" : answer)
                #MyDailyPhrase
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)

            case .instagram:
                return """
                【MyDailyPhrase】\(art.title)\(tags)

                お題
                \(prompt)

                要約
                \(art.summary)

                回答
                \(answer.isEmpty ? "（未回答）" : answer)

                #MyDailyPhrase #日記 #自己分析 #習慣化
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)

            case .line:
                return """
                【MyDailyPhrase】\(art.title)
                お題: \(prompt)
                回答: \(answer.isEmpty ? "（未回答）" : answer)
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            switch format {
            case .x:
                return """
                【MyDailyPhrase】
                お題: \(prompt)
                回答: \(answer.isEmpty ? "（未回答）" : answer)
                #MyDailyPhrase
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)

            case .instagram:
                return """
                【MyDailyPhrase】

                お題
                \(prompt)

                回答
                \(answer.isEmpty ? "（未回答）" : answer)

                #MyDailyPhrase #日記 #習慣化
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)

            case .line:
                return """
                【MyDailyPhrase】
                お題: \(prompt)
                回答: \(answer.isEmpty ? "（未回答）" : answer)
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}

// MARK: - Private UI Parts

private struct HomeGradientBackground: View {
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
        .ignoresSafeArea()
        .overlay(
            LinearGradient(
                colors: style.tintColors,
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()
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
            case .classic: return [Color.purple.opacity(0.10), Color.blue.opacity(0.08), Color.clear]
            case .sakura:  return [Color.pink.opacity(0.12),   Color.purple.opacity(0.06), Color.clear]
            case .aurora:  return [Color.green.opacity(0.10),  Color.blue.opacity(0.10),   Color.clear]
            case .neon:    return [Color.cyan.opacity(0.10),   Color.purple.opacity(0.08), Color.clear]
            case .gold:    return [Color.yellow.opacity(0.10), Color.orange.opacity(0.08), Color.clear]
            }
        }
    }
}

private struct GlassCard<Content: View>: View {
    @Environment(\.currentDecorationId) private var decorationId
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        Card(nil, decorationId: decorationId) { content }
    }
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
        }
    }
}

private struct TagGrid: View {
    let tags: [String]
    let accentSymbol: String

    private let cols: [GridItem] = [
        GridItem(.adaptive(minimum: 70), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { t in
                TagChip(text: t, accentSymbol: accentSymbol)
            }
        }
    }
}

private struct TagChip: View {
    let text: String
    let accentSymbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: accentSymbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
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
