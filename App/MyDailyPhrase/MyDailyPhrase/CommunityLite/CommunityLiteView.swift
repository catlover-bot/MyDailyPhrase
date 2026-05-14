import SwiftUI
import UIKit
import Combine
import Domain
import Presentation

@MainActor
final class CommunityLiteViewModel: ObservableObject {
    @Published private(set) var displayName: String = "Me"
    @Published private(set) var userId: String = ""
    @Published private(set) var selectedDecorationId: String = CardDecorationCatalog.classicId
    @Published private(set) var streak: Int = 0
    @Published private(set) var weeklyChallenge: CommunityLiteWeeklyChallenge
    @Published private(set) var inviteURL: URL? = nil
    @Published private(set) var inviteShareText: String = ""
    @Published var weeklyResponse: String = "" {
        didSet { persistWeeklyState() }
    }
    @Published var includeWeeklyResponseInShare: Bool = false {
        didSet { persistWeeklyState() }
    }
    @Published var includeStreakInProfileShare: Bool = true {
        didSet { persistWeeklyState() }
    }
    @Published var selectedReaction: CommunityLiteReactionStamp = .sparkles {
        didSet { persistWeeklyState() }
    }
    @Published var lastMessage: String? = nil

    private let getMyProfile: GetMyProfileUseCase
    private let computeStreak: ComputeStreakUseCase
    private let defaults: UserDefaults
    private let timeZone: TimeZone

    init(
        getMyProfile: GetMyProfileUseCase,
        computeStreak: ComputeStreakUseCase,
        defaults: UserDefaults,
        timeZone: TimeZone
    ) {
        self.getMyProfile = getMyProfile
        self.computeStreak = computeStreak
        self.defaults = defaults
        self.timeZone = timeZone
        self.weeklyChallenge = CommunityLiteSupport.challenge(for: Date(), calendar: Self.makeCalendar(timeZone: timeZone))
    }

    var equippedItem: CardDecoration {
        CardDecorationCatalog.byId(selectedDecorationId)
            ?? CardDecoration(id: CardDecorationCatalog.classicId, name: "Classic", rarity: .common, weight: 0)
    }

    var equippedTitle: String? {
        GachaThemePresentation.profileTitle(for: equippedItem)
    }

    var socialHeaderText: String {
        "公開フィードはまだありません。カードを外部共有して、安心な形でつながれる準備版です。"
    }

    func load(referenceDate: Date = Date()) {
        let calendar = Self.makeCalendar(timeZone: timeZone)
        weeklyChallenge = CommunityLiteSupport.challenge(for: referenceDate, calendar: calendar)

        let profile = getMyProfile()
        displayName = profile.displayName
        userId = profile.userId
        selectedDecorationId = profile.selectedDecorationId
        streak = computeStreak.execute()

        let referralCode = ReferralProgram.referralCode(for: profile.userId)
        inviteURL = ReferralProgram.inviteURL(
            inviterId: profile.userId,
            inviterName: profile.displayName,
            code: referralCode
        )
        inviteShareText = [
            "ひとこと日記 招待コード: \(referralCode)",
            "外部共有でつながろう。公開フィードは使わず、必要なときだけ共有できます。",
            "#ひとこと日記"
        ].joined(separator: "\n")

        restoreWeeklyState()
    }

    func weeklyChallengeShareText() -> String {
        CommunityLiteSupport.weeklyChallengeShareText(
            challenge: weeklyChallenge,
            displayName: displayName,
            profileTitle: equippedTitle,
            reaction: selectedReaction,
            answer: weeklyResponse,
            includeAnswer: includeWeeklyResponseInShare
        )
    }

    func profileShareText() -> String {
        CommunityLiteSupport.profileCardShareText(
            displayName: displayName,
            profileTitle: equippedTitle,
            streak: streak,
            reaction: selectedReaction,
            includeStreak: includeStreakInProfileShare
        )
    }

    func achievementShareText() -> String {
        CommunityLiteSupport.achievementShareText(
            displayName: displayName,
            streak: streak,
            profileTitle: equippedTitle,
            reaction: selectedReaction
        )
    }

    private func restoreWeeklyState() {
        weeklyResponse = defaults.string(forKey: weeklyDraftKey) ?? ""
        includeWeeklyResponseInShare = defaults.object(forKey: includeAnswerKey) as? Bool ?? false
        includeStreakInProfileShare = defaults.object(forKey: includeStreakKey) as? Bool ?? true

        if let rawStamp = defaults.string(forKey: reactionKey),
           let stamp = CommunityLiteReactionStamp(rawValue: rawStamp) {
            selectedReaction = stamp
        } else {
            selectedReaction = .sparkles
        }
    }

    private func persistWeeklyState() {
        defaults.set(weeklyResponse, forKey: weeklyDraftKey)
        defaults.set(includeWeeklyResponseInShare, forKey: includeAnswerKey)
        defaults.set(includeStreakInProfileShare, forKey: includeStreakKey)
        defaults.set(selectedReaction.rawValue, forKey: reactionKey)
    }

    private var weeklyDraftKey: String {
        "MyDailyPhrase.communityLite.weeklyDraft.\(weeklyChallenge.weekKey)"
    }

    private let includeAnswerKey = "MyDailyPhrase.communityLite.includeAnswer.v1"
    private let includeStreakKey = "MyDailyPhrase.communityLite.includeStreak.v1"
    private let reactionKey = "MyDailyPhrase.communityLite.reaction.v1"

    private static func makeCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
}

struct CommunityLiteView: View {
    @ObservedObject var vm: CommunityLiteViewModel

    @State private var shareSheetItems: [Any] = []
    @State private var isPresentingShareSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                heroCard
                weeklyChallengeSection
                profileExchangeSection
                streakSection
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("みんなとつながる")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidUpdate)) { _ in
            vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            vm.load()
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ShareSheet(activityItems: shareSheetItems)
        }
    }

    private var heroCard: some View {
        Card("Community Lite", decorationId: vm.selectedDecorationId) {
            VStack(alignment: .leading, spacing: 10) {
                Text(vm.socialHeaderText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label("コメント欄や公開ランキングはまだ非公開です", systemImage: "shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weeklyChallengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "みんなのチャレンジ",
                subtitle: "今週のお題に参加して、外部共有でゆるくつながれます。"
            )

            CommunityLiteSharePreviewCard(
                model: weeklyChallengeModel(includeAnswer: vm.includeWeeklyResponseInShare)
            )

            Card("今週のお題", decorationId: vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.weeklyChallenge.title)
                                .font(.headline)
                            Text(vm.weeklyChallenge.weekKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(vm.weeklyChallenge.badgeTitle)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }

                    Text(vm.weeklyChallenge.prompt)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))

                        TextEditor(text: $vm.weeklyResponse)
                            .frame(minHeight: 120)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel("今週のお題の下書き")

                        if vm.weeklyResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("共有したいときだけ、ひとことをここに書けます。")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                    Toggle("回答も共有カードに入れる", isOn: $vm.includeWeeklyResponseInShare)
                        .font(.subheadline)

                    Text("初期状態では回答は共有されません。外部に出すのは明示的にONにしたときだけです。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            reactionPicker

            actionButtons(
                primaryTitle: "チャレンジカードを共有",
                primarySystemImage: "square.and.arrow.up",
                primaryAction: { shareWeeklyChallengeCard() },
                secondaryTitle: "あとで書く",
                secondarySystemImage: "bookmark",
                secondaryAction: { vm.lastMessage = "下書きを保存しました" }
            )
        }
    }

    private var profileExchangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "プロフィールカード",
                subtitle: "いま装備しているテーマで、プロフィールや招待を共有できます。"
            )

            CommunityLiteSharePreviewCard(
                model: profileModel(includeStreak: vm.includeStreakInProfileShare)
            )

            Toggle("連続記録もプロフィールカードに入れる", isOn: $vm.includeStreakInProfileShare)
                .font(.subheadline)

            actionButtons(
                primaryTitle: "プロフィールカードを共有",
                primarySystemImage: "person.crop.rectangle",
                primaryAction: { shareProfileCard() },
                secondaryTitle: "招待リンクを共有",
                secondarySystemImage: "link",
                secondaryAction: { shareInviteLink() }
            )
        }
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "続けている記録",
                subtitle: "公開ランキングは使わずに、自分の節目だけを共有できます。"
            )

            CommunityLiteSharePreviewCard(
                model: achievementModel
            )

            Button {
                shareAchievementCard()
            } label: {
                Label("連続記録カードを共有", systemImage: "flame")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let lastMessage = vm.lastMessage {
                Text(lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reactionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("リアクションスタンプ")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CommunityLiteReactionStamp.allCases) { stamp in
                        Button {
                            vm.selectedReaction = stamp
                        } label: {
                            HStack(spacing: 8) {
                                Text(stamp.rawValue)
                                Text(stamp.label)
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(vm.selectedReaction == stamp ? Color.accentColor.opacity(0.16) : Color(uiColor: .secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionButtons(
        primaryTitle: String,
        primarySystemImage: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondarySystemImage: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Button(action: primaryAction) {
                    Label(primaryTitle, systemImage: primarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: secondaryAction) {
                    Label(secondaryTitle, systemImage: secondarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 10) {
                Button(action: primaryAction) {
                    Label(primaryTitle, systemImage: primarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: secondaryAction) {
                    Label(secondaryTitle, systemImage: secondarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var equippedTitleLine: String? {
        vm.equippedTitle
    }

    private func weeklyChallengeModel(includeAnswer: Bool) -> CommunityLiteShareCardModel {
        CommunityLiteShareCardModel(
            kindTitle: "今週のチャレンジ",
            headline: vm.weeklyChallenge.title,
            body: includeAnswer
                ? (vm.weeklyResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "回答はまだ入力されていません"
                    : vm.weeklyResponse.trimmingCharacters(in: .whitespacesAndNewlines))
                : vm.weeklyChallenge.prompt,
            footer: vm.weeklyChallenge.hashtag,
            decorationId: vm.selectedDecorationId,
            badgeText: vm.weeklyChallenge.badgeTitle,
            titlePlate: equippedTitleLine,
            reaction: vm.selectedReaction.rawValue
        )
    }

    private func profileModel(includeStreak: Bool) -> CommunityLiteShareCardModel {
        let streakLine = includeStreak ? "連続記録 \(vm.streak)日" : "プロフィールを共有"
        return CommunityLiteShareCardModel(
            kindTitle: "プロフィールカード",
            headline: vm.displayName,
            body: streakLine,
            footer: "#ひとこと日記",
            decorationId: vm.selectedDecorationId,
            badgeText: GachaThemePresentation.itemTypeLabel(for: vm.equippedItem),
            titlePlate: equippedTitleLine,
            reaction: vm.selectedReaction.rawValue
        )
    }

    private var achievementModel: CommunityLiteShareCardModel {
        CommunityLiteShareCardModel(
            kindTitle: "続けている記録",
            headline: "\(vm.streak)日ストリーク",
            body: "今週も続いています",
            footer: "#ひとこと日記",
            decorationId: vm.selectedDecorationId,
            badgeText: "継続中",
            titlePlate: equippedTitleLine,
            reaction: vm.selectedReaction.rawValue
        )
    }

    private func shareWeeklyChallengeCard() {
        let text = vm.weeklyChallengeShareText()
        let image = CommunityLiteShareCardRenderer.render(model: weeklyChallengeModel(includeAnswer: vm.includeWeeklyResponseInShare))?.image
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func shareProfileCard() {
        let text = vm.profileShareText()
        let image = CommunityLiteShareCardRenderer.render(model: profileModel(includeStreak: vm.includeStreakInProfileShare))?.image
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func shareAchievementCard() {
        let text = vm.achievementShareText()
        let image = CommunityLiteShareCardRenderer.render(model: achievementModel)?.image
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func shareInviteLink() {
        guard let inviteURL = vm.inviteURL else {
            vm.lastMessage = "招待リンクをまだ生成できません"
            return
        }
        shareSheetItems = ShareItemsBuilder.build(text: vm.inviteShareText, image: nil, url: inviteURL)
        isPresentingShareSheet = true
    }
}

private struct CommunityLiteShareCardModel: Equatable {
    let kindTitle: String
    let headline: String
    let body: String
    let footer: String
    let decorationId: String
    let badgeText: String?
    let titlePlate: String?
    let reaction: String
}

private struct CommunityLiteSharePreviewCard: View {
    let model: CommunityLiteShareCardModel

    var body: some View {
        CommunityLiteShareCardView(model: model)
            .frame(maxWidth: .infinity)
            .frame(height: 260)
    }
}

private struct CommunityLiteShareCardView: View {
    let model: CommunityLiteShareCardModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ひとこと日記")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(model.kindTitle)
                            .font(.title3.weight(.bold))
                    }

                    Spacer(minLength: 0)

                    Text(model.reaction)
                        .font(.title2)
                }

                Card(nil, decorationId: model.decorationId) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(model.headline)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if let badgeText = model.badgeText {
                                Text(badgeText)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                        }

                        if let titlePlate = model.titlePlate {
                            Text(titlePlate)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }

                        Text(model.body)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                Text(model.footer)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

@MainActor
private enum CommunityLiteShareCardRenderer {
    static func render(
        model: CommunityLiteShareCardModel,
        size: CGSize = CGSize(width: 360, height: 640),
        scale: CGFloat = 3.0
    ) -> ShareImage? {
        let content = CommunityLiteShareCardView(model: model)
            .frame(width: size.width, height: size.height)
            .background(Color(.systemBackground))
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.isOpaque = true

        guard let uiImage = renderer.uiImage else { return nil }
        return ShareImage(image: uiImage)
    }
}
