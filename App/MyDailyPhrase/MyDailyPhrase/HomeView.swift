import SwiftUI
import Domain
import Presentation

struct HomeView: View {
    @StateObject private var vm: HomeViewModel

    init(viewModel: HomeViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if vm.isLoading && vm.promptText.isEmpty {
                    loadingCard
                } else {
                    promptCard
                    answerCard
                    answerStateCard
                    progressSection
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("今日")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            vm.load()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(formattedDateText)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("MyDailyPhrase")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("一日の終わりに、ひとことだけ。短くても、ちゃんと残ります。")
                .font(.body)
                .foregroundStyle(.secondary)

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
            }
        }
    }

    private var answerStateCard: some View {
        JournalCard {
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
        }
        .accessibilityElement(children: .combine)
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
