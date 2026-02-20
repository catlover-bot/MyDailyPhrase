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
    @State private var viralTone: ViralTone = .challenge

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
        buildShareText(format: shareFormat, url: fallbackChallengeURL)
    }

    // 共有文言のデフォルトURL（コピー時など副作用を起こさない用途）
    private var fallbackChallengeURL: URL? {
        let dateKey = vm.todayDateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dateKey.isEmpty else { return nil }
        return URL(string: "mydailyphrase://challenge?dateKey=\(dateKey)")
    }

    private func shareCardModel(shareURL: URL?) -> ShareCardModel {
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
                shareURL: shareURL
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
                shareURL: shareURL
            )
        }
    }

    private func colorForMood(_ mood: String) -> Color {
        switch mood {
        case "喜び": return .yellow
        case "哀しみ": return .blue
        case "怒り": return .red
        case "不安": return .purple
        case "疲れ": return .gray
        case "挑戦": return .orange
        case "日常": return .green
        default: return .clear
        }
    }

    private var auraColors: [Color] {
        let colors = vm.todayArtifact?.moodTags.map { colorForMood($0) }.filter { $0 != .clear } ?? []
        if colors.isEmpty {
            return [Color.gray.opacity(0.3)]
        }
        return colors
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

        let challengeURL = vm.buildChallengeShareURLForCurrentPrompt() ?? fallbackChallengeURL
        let model = shareCardModel(shareURL: challengeURL)
        shareImage = ShareCardRenderer.render(model: model)

        let uiImage = shareImage?.image
        let shareText = buildShareText(format: shareFormat, url: challengeURL)
        shareSheetItems = ShareItemsBuilder.build(text: shareText, image: uiImage, url: challengeURL)
        isPresentingShareSheet = true
        vm.registerShareAction()
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

    @MainActor
    private func presentTextShare(text: String, url: URL? = nil) {
        shareSheetItems = ShareItemsBuilder.build(text: text, image: nil, url: url)
        isPresentingShareSheet = true
        vm.registerShareAction()
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
            .navigationTitle("チャレンジ回答")
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

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Button { presentUnifiedShare() } label: {
                                    AdaptiveActionButtonLabel(text: isPreparingShareImage ? "準備中" : "投稿", systemImage: "paperplane.fill")
                                        .fontWeight(.semibold)
                                        .compactActionLabel()
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
                                    AdaptiveActionButtonLabel(text: shareFormat.shortTitle, systemImage: "slider.horizontal.3")
                                        .fontWeight(.semibold)
                                        .compactActionLabel()
                                }
                                .buttonStyle(.bordered)

                                Button { copyCaption() } label: {
                                    AdaptiveActionButtonLabel(text: "コピー", systemImage: "doc.on.doc")
                                        .fontWeight(.semibold)
                                        .compactActionLabel()
                                }
                                .buttonStyle(.bordered)

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
                            .padding(.vertical, 1)
                        }
                        .accessibilityIdentifier("home.actionRow")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    SectionHeader(title: "シェアミッション", systemImage: "megaphone.fill")
                                    Spacer()
                                    Text("累計 \(vm.shareMissionLifetimeCount)投稿")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                ProgressView(
                                    value: Double(min(vm.shareMissionDailyCount, vm.shareMissionDailyTarget)),
                                    total: Double(vm.shareMissionDailyTarget)
                                )

                                HStack {
                                    Text("今日の進捗 \(vm.shareMissionDailyCount)/\(vm.shareMissionDailyTarget)")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(vm.shareMissionClaimedToday ? "受取済み" : "未受取")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Text("連続シェア \(vm.shareMissionStreakDays)日")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("ベスト \(vm.shareMissionBestStreakDays)日")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text("連続\(vm.shareMissionStreakBonusEveryDays)日ごとにボーナス（チケット+\(vm.shareMissionStreakRewardTickets)） / 次まであと\(vm.shareMissionDaysUntilStreakBonus)日")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if !vm.canClaimShareMissionReward {
                                    Text("あと\(vm.shareMissionRemainingCount)回シェアで報酬解放（チケット+\(vm.shareMissionRewardTickets)）")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    vm.claimShareMissionReward()
                                } label: {
                                    AdaptiveActionButtonLabel(text: "報酬を受け取る +\(vm.shareMissionRewardTickets)", systemImage: "gift.fill")
                                        .fontWeight(.semibold)
                                        .compactActionLabel()
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!vm.canClaimShareMissionReward)
                            }
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
                                SectionHeader(title: "今日のオーラ", systemImage: "sparkles")
                                if vm.todayArtifact == nil {
                                    Text("回答を保存すると、今日のオーラが生成されます。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(height: 120, alignment: .center)
                                } else {
                                    AuraView(colors: auraColors)
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    SectionHeader(title: "書きやすくするヒント", systemImage: "sparkle.magnifyingglass")
                                    Spacer()
                                    Text("回答のヒント")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                ForEach(Array(vm.promptBoosters.enumerated()), id: \.offset) { _, booster in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 3)
                                        Text(booster)
                                            .font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 10)
                                        Button("使う") {
                                            vm.applyPromptBooster(booster)
                                            isAnswerFocused = true
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .padding(10)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
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
                                        Text("保存後に自動生成")
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
                                    Text("まだプレビューがありません。回答を保存すると、タイトル・要約・キーワードが自動で表示されます。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    SectionHeader(title: "シェア文テンプレート", systemImage: "megaphone.fill")
                                    Spacer()
                                    Text("そのまま共有できます")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Picker("トーン", selection: $viralTone) {
                                    ForEach(ViralTone.allCases, id: \.self) { tone in
                                        Text(tone.title).tag(tone)
                                    }
                                }
                                .pickerStyle(.segmented)

                                ForEach(Array(viralCaptionPack.enumerated()), id: \.offset) { index, caption in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(caption)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)

                                        HStack(spacing: 8) {
                                            Button {
                                                UIPasteboard.general.string = caption
                                                toast("テンプレ\(index + 1)をコピーしました")
                                            } label: {
                                                AdaptiveActionButtonLabel(text: "コピー", systemImage: "doc.on.doc")
                                                    .compactActionLabel()
                                            }
                                            .buttonStyle(.bordered)

                                            Button {
                                                Task { @MainActor in
                                                    let url = vm.buildChallengeShareURLForCurrentPrompt() ?? fallbackChallengeURL
                                                    presentTextShare(text: caption, url: url)
                                                }
                                            } label: {
                                                AdaptiveActionButtonLabel(text: "共有", systemImage: "square.and.arrow.up")
                                                    .compactActionLabel()
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                    }
                                    .padding(10)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }

                        Button { vm.submit() } label: {
                            AdaptiveActionButtonLabel(text: vm.isAnsweredToday ? "更新して保存" : "保存する", systemImage: "tray.and.arrow.down.fill")
                                .fontWeight(.heavy)
                                .compactActionLabel()
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
        case buzz, x, instagram, line

        var title: String {
            switch self {
            case .buzz: return "バズ向け（参加を促す）"
            case .x: return "X（短め）"
            case .instagram: return "Instagram（しっかり）"
            case .line: return "LINE（シンプル）"
            }
        }
        var shortTitle: String {
            switch self {
            case .buzz: return "バズ"
            case .x: return "X"
            case .instagram: return "IG"
            case .line: return "LINE"
            }
        }
        var systemImage: String {
            switch self {
            case .buzz: return "megaphone"
            case .x: return "text.bubble"
            case .instagram: return "photo.on.rectangle"
            case .line: return "message"
            }
        }
    }

    private enum ViralTone: CaseIterable {
        case challenge
        case honest
        case concise

        var title: String {
            switch self {
            case .challenge: return "挑戦を促す"
            case .honest: return "共感寄り"
            case .concise: return "短く伝える"
            }
        }
    }

    private var viralCaptionPack: [String] {
        let prompt = vm.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = vm.answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAnswer = answer.isEmpty ? "（未回答）" : answer
        let link = (vm.buildChallengeShareURLForCurrentPrompt() ?? fallbackChallengeURL)?.absoluteString ?? ""
        let tagLine = viralTagLine
        let baseHashTags = contextualHashTags

        let candidates: [String]
        switch viralTone {
        case .challenge:
            candidates = [
                """
                【1分内省チャレンジ】
                お題: \(prompt)
                私の答え: \(normalizedAnswer)
                あなたの答えも聞かせてください
                \(baseHashTags)
                \(link)
                """,
                buildShareText(format: .buzz, url: URL(string: link)),
                "今日の問い: \(prompt)\n答え: \(normalizedAnswer)\n\(tagLine)\n\(baseHashTags)\n\(link)"
            ]
        case .honest:
            candidates = [
                """
                今日の内省メモ
                お題: \(prompt)
                率直な答え: \(normalizedAnswer)
                \(tagLine)
                \(baseHashTags)
                \(link)
                """,
                buildShareText(format: .instagram, url: URL(string: link)),
                "少しずつ言葉にするだけで、気持ちが整う。\nお題: \(prompt)\n答え: \(normalizedAnswer)\n\(baseHashTags)\n\(link)"
            ]
        case .concise:
            candidates = [
                buildShareText(format: .x, url: URL(string: link)),
                "お題: \(prompt)\n答え: \(normalizedAnswer)\n\(baseHashTags)\n\(link)",
                "1日1問のセルフチェック\n\(prompt)\n\(normalizedAnswer)\n\(baseHashTags) \(link)"
            ]
        }

        var seen: Set<String> = []
        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    private var viralTagLine: String {
        guard let art = vm.todayArtifact else {
            return "今日も1分、自分の気持ちを言葉にする。"
        }
        let tags = Array(art.moodTags.prefix(2))
        guard !tags.isEmpty else {
            return art.summary
        }
        return "気分メモ: " + tags.joined(separator: "・")
    }

    private var contextualHashTags: String {
        var tags: [String] = ["#MyDailyPhrase"]

        if let art = vm.todayArtifact {
            let moodToTag: [String: String] = [
                "喜び": "#うれしかったこと",
                "哀しみ": "#気持ちの整理",
                "怒り": "#感情メモ",
                "不安": "#不安との向き合い方",
                "疲れ": "#休息メモ",
                "挑戦": "#今日の挑戦",
                "日常": "#日常ログ"
            ]
            for mood in art.moodTags.prefix(2) {
                if let mapped = moodToTag[mood], !tags.contains(mapped) {
                    tags.append(mapped)
                }
            }

            for keyword in art.keywords.prefix(2) {
                guard let keywordTag = makeKeywordHashTag(keyword),
                      !tags.contains(keywordTag) else { continue }
                tags.append(keywordTag)
            }
        }

        let fallback = ["#振り返り", "#自己理解", "#習慣化"]
        for tag in fallback where tags.count < 5 {
            if !tags.contains(tag) {
                tags.append(tag)
            }
        }
        return tags.joined(separator: " ")
    }

    private func makeKeywordHashTag(_ keyword: String) -> String? {
        let compact = keyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
        guard compact.count >= 2, compact.count <= 12 else { return nil }
        if compact.contains("#") { return nil }
        let isOnlyNumber = compact.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        if isOnlyNumber { return nil }
        return "#\(compact)"
    }

    private func buildShareText(format: ShareFormat, url: URL?) -> String {
        let prompt = vm.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = vm.answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = url?.absoluteString ?? ""
        let hashTags = contextualHashTags
        let streakLine = vm.streak >= 7 ? "連続\(vm.streak)日、続けられています。" : "1日1分の振り返りを継続中。"

        if let art = vm.todayArtifact {
            let tags = art.moodTags.isEmpty ? "" : " / " + art.moodTags.joined(separator: "・")
            switch format {
            case .buzz:
                return """
                【3行内省チャレンジ】
                \(streakLine)
                お題: \(prompt)
                私の答え: \(answer.isEmpty ? "（未回答）" : answer)
                あなたならどう答える？
                \(hashTags)
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            case .x:
                return """
                【MyDailyPhrase】\(art.title)\(tags)
                お題: \(prompt)
                回答: \(answer.isEmpty ? "（未回答）" : answer)
                \(hashTags)
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

                \(hashTags)
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
            case .buzz:
                return """
                【3行内省チャレンジ】
                \(streakLine)
                お題: \(prompt)
                私の答え: \(answer.isEmpty ? "（未回答）" : answer)
                あなたも参加してみて👇
                \(hashTags)
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            case .x:
                return """
                【MyDailyPhrase】
                お題: \(prompt)
                回答: \(answer.isEmpty ? "（未回答）" : answer)
                \(hashTags)
                \(link)
                """.trimmingCharacters(in: .whitespacesAndNewlines)

            case .instagram:
                return """
                【MyDailyPhrase】

                お題
                \(prompt)

                回答
                \(answer.isEmpty ? "（未回答）" : answer)

                \(hashTags)
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

private extension View {
    func compactActionLabel() -> some View {
        labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .truncationMode(.tail)
    }
}

// MARK: - Private UI Parts

private struct AuraView: View {
    let colors: [Color]

    var body: some View {
        let gradientColors = colors.count > 1 ? colors : colors + [colors.first?.opacity(0.5) ?? .clear, .clear]
        return AngularGradient(
            gradient: Gradient(colors: gradientColors),
            center: .center
        )
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AdaptiveActionButtonLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label(text, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .fixedSize(horizontal: true, vertical: false)
            Text(text)
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: systemImage)
        }
    }
}

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
            case .classic: return [Color.indigo.opacity(0.25), Color.purple.opacity(0.2), .clear]
            case .sakura:  return [Color(red: 1.0, green: 0.7, blue: 0.8).opacity(0.25), Color.pink.opacity(0.2), .clear]
            case .aurora:  return [Color.mint.opacity(0.25),  Color.cyan.opacity(0.2),   .clear]
            case .neon:    return [Color.pink.opacity(0.25),   Color.purple.opacity(0.2), Color.cyan.opacity(0.15), .clear]
            case .gold:    return [Color.yellow.opacity(0.25), Color.orange.opacity(0.2), .clear]
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
