import SwiftUI
import Domain
import Presentation

struct HomeView: View {
    @StateObject private var vm: HomeViewModel
    private let historyViewModel: HistoryViewModel
    @AppStorage("home.didDismissFirstUseGuide.v1") private var didDismissFirstUseGuide = false
    @State private var isShowingGuide = false

    init(viewModel: HomeViewModel, historyViewModel: HistoryViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
        self.historyViewModel = historyViewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppChrome.pageSectionSpacing) {
                headerSection

                if !didDismissFirstUseGuide {
                    firstUseGuideCard
                }

                if vm.isLoading && vm.promptText.isEmpty {
                    loadingCard
                } else {
                    promptCard
                    answerCard
                    answerStateCard
                    historyCard
                    rewardLoopCard
                    progressSection
                }
            }
            .frame(maxWidth: AppChrome.standardPageMaxWidth)
            .padding(.horizontal, AppChrome.screenHorizontalPadding)
            .padding(.top, AppChrome.standardPageTopPadding)
            .padding(.bottom, AppChrome.standardPageBottomPadding)
        }
        .background(AppScreenBackground())
        .navigationTitle("今日")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingGuide = true
                } label: {
                    Label("使い方", systemImage: "questionmark.circle")
                }
            }
        }
        .task {
            vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            vm.load()
        }
        .sheet(isPresented: $isShowingGuide) {
            NavigationStack {
                QuickStartGuideSheet()
            }
        }
    }

    private var headerSection: some View {
        PageHeroCard(
            eyebrow: formattedDateText,
            title: "今日のひとこと",
            subtitle: "まずは今日のお題にひとこと答えるだけで大丈夫です。保存するまで外には出ず、あとから静かに読み返せます。",
            accent: .blue
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    InfoBadge(title: "1日1つ", systemImage: "sun.max.fill", tint: .orange)
                    InfoBadge(title: "回答は非公開", systemImage: "lock.fill", tint: .blue)
                    InfoBadge(title: "参加は無料", systemImage: "person.2.wave.2", tint: .green)
                    PremiumBadge(title: "作成はCreator Pass")
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoBadge(title: "1日1つ", systemImage: "sun.max.fill", tint: .orange)
                    InfoBadge(title: "回答は非公開", systemImage: "lock.fill", tint: .blue)
                    InfoBadge(title: "参加は無料", systemImage: "person.2.wave.2", tint: .green)
                    PremiumBadge(title: "作成はCreator Pass")
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    NavigationLink {
                        HistoryView(viewModel: historyViewModel)
                    } label: {
                        Label("履歴を見る", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isShowingGuide = true
                    } label: {
                        Label("使い方を見る", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                VStack(spacing: 10) {
                    NavigationLink {
                        HistoryView(viewModel: historyViewModel)
                    } label: {
                        Label("履歴を見る", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isShowingGuide = true
                    } label: {
                        Label("使い方を見る", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let feedback = vm.feedbackMessage {
                Label(feedback, systemImage: vm.feedbackIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(vm.feedbackIsError ? .orange : .green)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background((vm.feedbackIsError ? Color.orange : Color.green).opacity(0.12), in: Capsule())
                    .accessibilityLabel(feedback)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var firstUseGuideCard: some View {
        AppSectionCard(
            title: "はじめての方へ",
            subtitle: "アプリの流れを30秒でつかめる短い案内です。"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                guideRow(
                    title: "今日できること",
                    detail: "1日1つのお題に答えると、その日の記録がこの端末に残ります。",
                    systemImage: "square.and.pencil"
                )
                guideRow(
                    title: "ガチャの役割",
                    detail: "テーマや装飾を集めると、プロフィールや共有カード、コミュニティカードの見た目を変えられます。",
                    systemImage: "sparkles"
                )
                guideRow(
                    title: "また明日開く理由",
                    detail: "毎日の無料ガチャや連続記録があるので、短い記録でも続けやすくなっています。",
                    systemImage: "calendar.badge.clock"
                )
                guideRow(
                    title: "みんなの部屋",
                    detail: "部屋への参加は無料です。コミュニティ作成とお題カスタマイズだけ Creator Pass が必要です。",
                    systemImage: "person.2.wave.2"
                )
                guideRow(
                    title: "プライバシー",
                    detail: "日記の回答は自動で公開されません。共有前には内容を確認できます。",
                    systemImage: "hand.raised.fill"
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button {
                            isShowingGuide = true
                        } label: {
                            Label("使い方を見る", systemImage: "book")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("閉じる") {
                            didDismissFirstUseGuide = true
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(spacing: 10) {
                        Button {
                            isShowingGuide = true
                        } label: {
                            Label("使い方を見る", systemImage: "book")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("閉じる") {
                            didDismissFirstUseGuide = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var promptCard: some View {
        JournalCard(backgroundStyle: .accent) {
            VStack(alignment: .leading, spacing: 12) {
                Label("今日のお題", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(vm.promptText)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("今日のお題、\(vm.promptText)")

                Text("気負わず、短い言葉から始めて大丈夫です。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label("保存するまで外には出ません", systemImage: "lock.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var answerCard: some View {
        JournalCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("今日の回答", systemImage: "square.and.pencil")
                    .font(.headline)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))

                    TextEditor(text: $vm.answerText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("今日の回答入力欄")

                    if vm.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("今日の気持ち、学び、感謝したことをひとことで。")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }

                Button(action: vm.submit) {
                    Label(vm.saveButtonTitle, systemImage: vm.isAnsweredToday ? "arrow.clockwise.circle.fill" : "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("今日の回答を保存または更新します")

                Text("回答はこのデバイス内に保存され、共有は明示的な操作をしたときだけ行われます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var answerStateCard: some View {
        JournalCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: vm.isAnsweredToday ? "checkmark.seal.fill" : "moon.zzz.fill")
                        .font(.title2)
                        .foregroundStyle(vm.isAnsweredToday ? .green : .blue)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(vm.isAnsweredToday ? "今日は回答済みです" : "まだ未回答です")
                            .font(.headline)

                        Text(vm.isAnsweredToday
                             ? "あとで読み返したくなったら、今日の回答をそのまま更新できます。"
                             : "1分だけでも残しておくと、あとから見返したときに一日の輪郭が残ります。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        InfoBadge(title: "回答は自動公開されません", systemImage: "lock.fill", tint: .blue)
                        InfoBadge(title: "共有前に確認できます", systemImage: "square.and.arrow.up", tint: .indigo)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoBadge(title: "回答は自動公開されません", systemImage: "lock.fill", tint: .blue)
                        InfoBadge(title: "共有前に確認できます", systemImage: "square.and.arrow.up", tint: .indigo)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var historyCard: some View {
        AppSectionCard(
            title: "履歴を見る",
            subtitle: "過去のひとことを見返したり、必要なら削除できます。"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    InfoBadge(title: "今月 \(vm.answeredThisMonthCount) 件", systemImage: "calendar", tint: .blue)
                    if vm.streak > 0 {
                        InfoBadge(title: "連続 \(vm.streak) 日", systemImage: "flame.fill", tint: .orange)
                    }
                }

                NavigationLink {
                    HistoryView(viewModel: historyViewModel)
                } label: {
                    Label("履歴を見る", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var rewardLoopCard: some View {
        AppSectionCard(
            title: "保存したあとの楽しみ",
            subtitle: "今日の記録を残したあとは、下のタブから見た目集めや無料参加の部屋をゆっくり選べます。"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        InfoBadge(title: "ガチャでテーマを集める", systemImage: "sparkles", tint: .orange)
                        InfoBadge(title: "部屋への参加は無料", systemImage: "person.2.wave.2", tint: .green)
                        InfoBadge(title: "共有は明示操作のみ", systemImage: "square.and.arrow.up", tint: .indigo)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoBadge(title: "ガチャでテーマを集める", systemImage: "sparkles", tint: .orange)
                        InfoBadge(title: "部屋への参加は無料", systemImage: "person.2.wave.2", tint: .green)
                        InfoBadge(title: "共有は明示操作のみ", systemImage: "square.and.arrow.up", tint: .indigo)
                    }
                }

                Text("ガチャで手に入れたアイテムはプロフィールや共有カードに使えます。みんなの部屋では、公開コメントなしでお題に参加できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var progressSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                streakCard
                monthlyCountCard
            }

            VStack(spacing: 16) {
                streakCard
                monthlyCountCard
            }
        }
    }

    private var streakCard: some View {
        MetricCard(
            title: "現在の連続記録",
            value: "\(vm.streak)日",
            detail: vm.streak > 0 ? "今日まで続いています" : "今日の一言から始めましょう",
            systemImage: "flame.fill",
            tint: .orange
        )
        .accessibilityLabel("現在の連続記録、\(vm.streak)日")
    }

    private var monthlyCountCard: some View {
        MetricCard(
            title: "今月の回答数",
            value: "\(vm.answeredThisMonthCount)件",
            detail: "この1か月に残したひとこと",
            systemImage: "calendar",
            tint: .blue
        )
        .accessibilityLabel("今月の回答数、\(vm.answeredThisMonthCount)件")
    }

    private var loadingCard: some View {
        JournalCard {
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日のお題を準備しています")
                        .font(.headline)
                    Text("ローカルデータを読み込んでいます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var formattedDateText: String {
        let calendar = Calendar.autoupdatingCurrent
        guard let date = DateKey.date(from: vm.todayDateKey, calendar: calendar) else {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.dateStyle = .full
            return formatter.string(from: Date())
        }

        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = calendar
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func guideRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct QuickStartGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionCard(
                    title: "今日やること",
                    subtitle: "1日1つのお題に答えると、記録がこの端末に残ります。"
                ) {
                    guideLine("回答は自動で公開されません", systemImage: "lock.fill")
                    guideLine("保存後もあとから更新できます", systemImage: "square.and.pencil")
                }

                AppSectionCard(
                    title: "ガチャで増える楽しみ",
                    subtitle: "テーマや称号、共有カード用の見た目を集められます。"
                ) {
                    guideLine("無料ガチャから始められます", systemImage: "gift")
                    guideLine("有料チケットは任意で、確率は購入前に確認できます", systemImage: "ticket")
                }

                AppSectionCard(
                    title: "みんなの部屋",
                    subtitle: "ゲーム系の部屋には無料で参加できます。"
                ) {
                    guideLine("コミュニティ作成だけ Creator Pass が必要です", systemImage: "crown.fill")
                    guideLine("公開コメントやランキングは今は無効です", systemImage: "shield")
                }
            }
            .padding(16)
        }
        .background(AppScreenBackground())
        .navigationTitle("使い方")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }

    private func guideLine(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct JournalCard<Content: View>: View {
    @Environment(\.currentDecorationId) private var decorationId

    enum BackgroundStyle {
        case standard
        case accent
    }

    let backgroundStyle: BackgroundStyle
    @ViewBuilder let content: Content

    init(
        backgroundStyle: BackgroundStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundStyle = backgroundStyle
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var background: some View {
        ZStack {
            switch backgroundStyle {
            case .standard:
                Color(uiColor: .systemBackground)
            case .accent:
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.24),
                        Color.accentColor.opacity(0.10),
                        Color(uiColor: .systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            decorationOverlay
        }
    }

    private var decorationOverlay: some View {
        let style = DecorationThemeResolver.resolveStyleID(
            from: decorationId,
            supportedStyleIDs: [
                "classic", "sakura", "aurora", "neon", "gold", "starlight", "ocean", "paper", "noir", "glitch"
            ]
        )

        let colors: [Color]
        switch style {
        case "sakura":
            colors = [Color.pink.opacity(0.10), Color.purple.opacity(0.04), .clear]
        case "aurora":
            colors = [Color.green.opacity(0.08), Color.blue.opacity(0.08), .clear]
        case "neon", "glitch":
            colors = [Color.cyan.opacity(0.09), Color.indigo.opacity(0.06), .clear]
        case "gold":
            colors = [Color.yellow.opacity(0.09), Color.orange.opacity(0.05), .clear]
        case "starlight":
            colors = [Color.indigo.opacity(0.10), Color.blue.opacity(0.06), .clear]
        case "ocean":
            colors = [Color.cyan.opacity(0.08), Color.blue.opacity(0.06), .clear]
        case "paper":
            colors = [Color.brown.opacity(0.06), Color.orange.opacity(0.03), .clear]
        case "noir":
            colors = [Color.gray.opacity(0.08), Color.black.opacity(0.04), .clear]
        default:
            colors = [Color.accentColor.opacity(0.04), Color.clear, Color.clear]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.overlay)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        JournalCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)

                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
