import SwiftUI
import UIKit
import Domain
import Presentation

struct GachaThemePreviewContent: View {
    let item: CardDecoration
    let ownedCount: Int
    let isOwned: Bool
    let isEquipped: Bool
    let profileDisplayName: String
    var showsHeroCard: Bool = true
    var showsSummaryCard: Bool = true
    var showsUsageCard: Bool = true
    var previewSurfaceLimit: Int? = nil

    private var ownershipState: GachaThemeOwnershipState {
        GachaThemePresentation.ownershipState(isOwned: isOwned, isEquipped: isEquipped)
    }

    private var previewSurfaces: [DecorationSurface] {
        GachaThemePresentation.orderedUsagePreviewSurfaces(for: item)
    }

    private var visiblePreviewSurfaces: [DecorationSurface] {
        guard let previewSurfaceLimit else { return previewSurfaces }
        return Array(previewSurfaces.prefix(previewSurfaceLimit))
    }

    private var overflowPreviewSurfaces: [DecorationSurface] {
        guard let previewSurfaceLimit, previewSurfaces.count > previewSurfaceLimit else { return [] }
        return Array(previewSurfaces.dropFirst(previewSurfaceLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHeroCard {
                artworkHeroCard
            }
            if showsSummaryCard {
                summaryCard
            }
            if showsUsageCard {
                usageCard
            }
            usagePreviewSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artworkHeroCard: some View {
        AppSectionCard(
            title: "画像プレビュー",
            subtitle: "このアイテムの見た目です。実際のカードでは、文字が読みやすいように控えめに反映されます。"
        ) {
            GachaArtworkView(
                item: item,
                displayMode: .detailHero
            )
        }
    }

    private var summaryCard: some View {
        AppSectionCard(
            title: item.name,
            subtitle: GachaThemePresentation.revealPhrase(for: item)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        GachaRarityBadge(rarity: item.rarity)
                        GachaOwnershipBadge(state: ownershipState)
                        detailChip(systemImage: "square.stack.3d.up", text: GachaThemePresentation.itemTypeLabel(for: item))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GachaRarityBadge(rarity: item.rarity)
                        HStack(spacing: 8) {
                            GachaOwnershipBadge(state: ownershipState)
                            detailChip(systemImage: "square.stack.3d.up", text: GachaThemePresentation.itemTypeLabel(for: item))
                        }
                    }
                }

                detailChip(
                    systemImage: "shippingbox",
                    text: isOwned ? "コレクション登録済み x\(max(1, ownedCount))" : "コレクション未登録"
                )

                Text(GachaThemePresentation.compactUsageSummary(for: item))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(GachaThemePresentation.flavorText(for: item))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var usageCard: some View {
        AppSectionCard(
            title: "装備できる場所",
            subtitle: "このアイテムは以下の画面で見た目に反映できます。"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(GachaThemePresentation.usageText(for: item))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !GachaThemePresentation.applicableSurfaceLabels(for: item).isEmpty {
                    FlexibleSurfaceChips(labels: GachaThemePresentation.applicableSurfaceLabels(for: item))
                }
            }
        }
    }

    private var usagePreviewSection: some View {
        AppSectionCard(
            title: "このアイテムの使われ方",
            subtitle: "実際に反映される画面だけを、読みやすさを保った形で表示します。"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(visiblePreviewSurfaces, id: \.self) { surface in
                    usagePreviewCard(for: surface)
                }

                if !overflowPreviewSurfaces.isEmpty {
                    DisclosureGroup("ほかの見え方を見る") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(overflowPreviewSurfaces, id: \.self) { surface in
                                usagePreviewCard(for: surface)
                            }
                        }
                        .padding(.top, 12)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private func readablePreviewCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AppSectionCard(
            title: title,
            subtitle: subtitle
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        GachaArtworkView(
                            item: item,
                            displayMode: .decorativeAccent
                        )
                        .frame(width: 72, height: 72)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("このアイテムの見た目")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text("実際のカードでは、文字が読みやすいように控えめに反映されます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        GachaArtworkView(
                            item: item,
                            displayMode: .decorativeAccent
                        )
                        .frame(width: 72, height: 72)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("このアイテムの見た目")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text("実際のカードでは、文字が読みやすいように控えめに反映されます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func usagePreviewCard(for surface: DecorationSurface) -> some View {
        GachaItemUsagePreviewCard(
            item: item,
            title: GachaThemePresentation.usagePreviewTitle(for: surface),
            subtitle: GachaThemePresentation.usagePreviewDescription(
                for: surface,
                item: item,
                isEquipped: isEquipped
            )
        ) {
            usagePreviewContent(for: surface)
        }
    }

    @ViewBuilder
    private func usagePreviewContent(for surface: DecorationSurface) -> some View {
        switch surface {
        case .journalCard:
            previewTextPanel {
                Label("サンプルお題", systemImage: "text.quote")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("今日の終わりに、残しておきたい気持ちは？")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(GachaThemePresentation.sampleJournalAnswer(for: item))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .promptCard:
            previewTextPanel {
                Label("お題カード", systemImage: "sparkles.rectangle.stack")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("今日遊びたいゲームを1つだけ残すなら？")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("お題の雰囲気やカードの見た目に反映されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .profileCard:
            previewTextPanel {
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(item.rarity.previewAccent.opacity(0.22))
                        .frame(width: 54, height: 54)
                        .overlay {
                            Text(profileInitial)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(item.rarity.previewAccent)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Text(profileDisplayName)
                                    .font(.headline)
                                if let title = GachaThemePresentation.profileTitle(for: item) {
                                    inlinePreviewChip(title)
                                }
                                if isEquipped {
                                    emphasizedChip("装備中", tint: item.rarity.previewAccent)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(profileDisplayName)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    if let title = GachaThemePresentation.profileTitle(for: item) {
                                        inlinePreviewChip(title)
                                    }
                                    if isEquipped {
                                        emphasizedChip("装備中", tint: item.rarity.previewAccent)
                                    }
                                }
                            }
                        }

                        Text(GachaThemePresentation.sampleProfileLine(for: item, isEquipped: isEquipped))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        case .shareCard:
            previewTextPanel {
                HStack {
                    Text("ひとこと日記")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    inlinePreviewChip(GachaThemePresentation.rarityLabel(for: item.rarity))
                }

                Text(item.name)
                    .font(.headline)

                if let template = GachaThemePresentation.shareTemplateName(for: item) {
                    inlinePreviewChip(template)
                }

                Text(GachaThemePresentation.sampleShareCaption(for: item, isEquipped: isEquipped))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .communityCard:
            previewTextPanel {
                HStack {
                    Text("みんなの部屋")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    inlinePreviewChip("参加は無料")
                }

                Text("ゲーム好きの部屋")
                    .font(.headline)
                Text("最近の神BGMを1曲だけ挙げるなら？")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("部屋カードやお題プレビューの見た目に反映されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .gachaResultCard:
            previewTextPanel {
                HStack {
                    Text("獲得アイテム")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    GachaRarityBadge(rarity: item.rarity)
                }

                Text(item.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    emphasizedChip(isOwned ? (isEquipped ? "装備中" : "所持") : "NEW", tint: item.rarity.previewAccent)
                    Text("結果画面のプレビューや一覧に反映")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .collectionCard:
            previewTextPanel {
                HStack(alignment: .top, spacing: 12) {
                    GachaArtworkView(item: item, displayMode: .thumbnail)
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(GachaThemePresentation.itemTypeLabel(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(GachaThemePresentation.compactUsageSummary(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        case .gachaCapsule:
            previewTextPanel {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles.tv")
                        .font(.title2)
                        .foregroundStyle(item.rarity.previewAccent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("開封演出")
                            .font(.headline)
                        Text("ガチャを引いた瞬間の光や空気感に反映されます。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        case .appBackground:
            previewTextPanel {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                item.rarity.previewAccent.opacity(0.22),
                                Color(uiColor: .secondarySystemBackground),
                                item.rarity.previewAccent.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 110)
                    .overlay(alignment: .bottomLeading) {
                        Text("背景アクセント")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(12)
                    }
            }
        case .badge:
            previewTextPanel {
                HStack(spacing: 12) {
                    GachaArtworkView(item: item, displayMode: .decorativeAccent)
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("バッジとして表示")
                            .font(.headline)
                        Text("プロフィールや共有カードの小さな印として使われます。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        case .sticker:
            previewTextPanel {
                HStack(spacing: 12) {
                    GachaArtworkView(item: item, displayMode: .decorativeAccent)
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("小さなステッカー装飾")
                            .font(.headline)
                        Text("カードの角に置かれる軽いアクセントとして使われます。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        case .auraFrame:
            previewTextPanel {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(height: 110)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(item.rarity.previewAccent.opacity(0.42), lineWidth: 2)
                            .shadow(color: item.rarity.previewAccent.opacity(0.24), radius: 12)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text("オーラ枠")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(12)
                    }
            }
        case .titlePlate:
            previewTextPanel {
                VStack(alignment: .leading, spacing: 8) {
                    Text(profileDisplayName)
                        .font(.headline)
                    inlinePreviewChip(GachaThemePresentation.profileTitle(for: item) ?? item.name)
                    Text("名前まわりの称号プレートとして表示されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func previewTextPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func inlinePreviewChip(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(Capsule())
    }

    private func emphasizedChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    private var profileInitial: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "M" : trimmed).prefix(1)).uppercased()
    }

    private func detailChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(Capsule())
    }
}

struct GachaArtworkView: View {
    enum DisplayMode {
        case thumbnail
        case collectionTile
        case diagnostics
        case detailHero
        case resultHero
        case decorativeAccent

        var maxHeight: CGFloat {
            switch self {
            case .thumbnail:
                return 72
            case .collectionTile:
                return 104
            case .diagnostics:
                return 144
            case .detailHero:
                return 220
            case .resultHero:
                return 248
            case .decorativeAccent:
                return 72
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .thumbnail:
                return 12
            case .collectionTile:
                return 16
            case .diagnostics:
                return 16
            case .detailHero:
                return 22
            case .resultHero:
                return 22
            case .decorativeAccent:
                return 16
            }
        }

        var contentPadding: CGFloat {
            switch self {
            case .thumbnail:
                return 10
            case .collectionTile:
                return 12
            case .diagnostics:
                return 14
            case .detailHero:
                return 18
            case .resultHero:
                return 18
            case .decorativeAccent:
                return 12
            }
        }

        var prefersThumbnail: Bool {
            switch self {
            case .thumbnail, .collectionTile:
                return true
            case .diagnostics, .detailHero, .resultHero, .decorativeAccent:
                return false
            }
        }

        var symbolSize: CGFloat {
            switch self {
            case .thumbnail:
                return 22
            case .collectionTile:
                return 26
            case .diagnostics:
                return 30
            case .detailHero:
                return 36
            case .resultHero:
                return 42
            case .decorativeAccent:
                return 22
            }
        }
    }

    let item: CardDecoration
    let displayMode: DisplayMode
    var customMaxHeight: CGFloat? = nil
    var customCornerRadius: CGFloat? = nil

    private var metadata: DecorationItem {
        GachaThemePresentation.decorationItem(for: item)
    }

    private var resolvedImage: UIImage? {
        preferredAssetNames
            .compactMap { assetName in
                UIImage(named: assetName)
            }
            .first
    }

    private var preferredAssetNames: [String] {
        let candidates: [String?]
        if displayMode.prefersThumbnail {
            candidates = [metadata.thumbnailAssetName, metadata.assetName]
        } else {
            candidates = [metadata.assetName, metadata.thumbnailAssetName]
        }

        return candidates.compactMap { $0 }.reduce(into: [String]()) { partialResult, value in
            if !partialResult.contains(value) {
                partialResult.append(value)
            }
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundGradient)

            if let resolvedImage {
                Image(uiImage: resolvedImage)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(displayMode.contentPadding)
            } else {
                fallbackArtwork
                    .padding(displayMode.contentPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxHeight: maxHeight)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(item.rarity.previewAccent.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                item.rarity.previewAccent.opacity(0.18),
                Color(uiColor: .secondarySystemBackground),
                item.rarity.previewAccent.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackArtwork: some View {
        ZStack {
            Circle()
                .fill(item.rarity.previewAccent.opacity(0.10))
                .frame(width: displayMode.symbolSize * 2.1, height: displayMode.symbolSize * 2.1)

            Image(systemName: symbolName)
                .font(.system(size: displayMode.symbolSize, weight: .semibold))
                .foregroundStyle(item.rarity.previewAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbolName: String {
        switch metadata.itemType {
        case .fullTheme:
            return "paintpalette.fill"
        case .background:
            return "sun.max.fill"
        case .cardFrame:
            return "rectangle.inset.filled"
        case .sticker:
            return "seal.fill"
        case .badge:
            return "rosette"
        case .profileTitle:
            return "textformat.size.larger"
        case .shareTemplate:
            return "square.and.arrow.up.fill"
        case .gachaRevealEffect:
            return "sparkles.tv"
        case .promptPack:
            return "text.quote"
        case .journalPaper:
            return "doc.text.image"
        case .auraStyle:
            return "circle.hexagongrid.fill"
        }
    }

    private var cornerRadius: CGFloat {
        customCornerRadius ?? displayMode.cornerRadius
    }

    private var maxHeight: CGFloat {
        customMaxHeight ?? displayMode.maxHeight
    }
}

struct FlexibleSurfaceChips: View {
    let labels: [String]

    var body: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(labels, id: \.self) { label in
                DecorationSurfaceChip(label: label)
            }
        }
    }
}

struct DecorationSurfaceChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

struct GachaItemUsagePreviewCard<Content: View>: View {
    let item: CardDecoration
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(
        item: CardDecoration,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.item = item
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    GachaArtworkView(item: item, displayMode: .decorativeAccent)
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    GachaArtworkView(item: item, displayMode: .decorativeAccent)
                        .frame(width: 64, height: 64)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct GachaCollectionTile: View {
    let item: CardDecoration
    let ownedCount: Int
    let isOwned: Bool
    let isEquipped: Bool
    let onTap: () -> Void

    private var ownershipState: GachaThemeOwnershipState {
        GachaThemePresentation.ownershipState(isOwned: isOwned, isEquipped: isEquipped)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        GachaRarityBadge(rarity: item.rarity)
                        Spacer()
                        if isEquipped {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(item.rarity.previewAccent)
                        }
                    }

                    GachaArtworkView(
                        item: item,
                        displayMode: .collectionTile
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(GachaThemePresentation.itemTypeLabel(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(GachaThemePresentation.compactUsageSummary(for: item))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .opacity(isOwned ? 1.0 : 0.72)

                HStack(alignment: .center, spacing: 8) {
                    GachaOwnershipBadge(state: ownershipState)
                    Spacer(minLength: 0)
                    Text(isOwned ? "x\(max(1, ownedCount))" : "Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct GachaThemePreviewSheet: View {
    let item: CardDecoration
    let ownedCount: Int
    let isOwned: Bool
    let isEquipped: Bool
    let profileDisplayName: String
    let onEquip: () -> Void
    let onShare: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                GachaThemePreviewContent(
                    item: item,
                    ownedCount: ownedCount,
                    isOwned: isOwned,
                    isEquipped: isEquipped,
                    profileDisplayName: profileDisplayName
                )
                .padding(16)
                .padding(.bottom, 196)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    equipButton
                    laterButton
                }

                VStack(spacing: 10) {
                    equipButton
                    laterButton
                }
            }

            if FeatureFlags.nativeSharingEnabled && isOwned {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        onShare()
                    }
                } label: {
                    Label("共有する", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var equipButton: some View {
        Button {
            onEquip()
        } label: {
            Label(
                GachaThemePresentation.primaryEquipLabel(for: item, isEquipped: isEquipped),
                systemImage: isEquipped ? "checkmark.circle.fill" : "person.crop.circle.badge.checkmark"
            )
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isOwned || isEquipped)
    }

    private var laterButton: some View {
        Button {
            dismiss()
        } label: {
            Label(isOwned ? "あとで見る" : "閉じる", systemImage: "xmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

struct GachaShareCardModel: Equatable {
    let appName: String
    let itemName: String
    let rarityLabel: String
    let flavorText: String
    let revealPhrase: String
    let statusLine: String
    let decorationId: String
    let profileTitle: String?
}

struct GachaShareCardView: View {
    let model: GachaShareCardModel

    private var decoration: CardDecoration? {
        CardDecorationCatalog.byId(model.decorationId)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.appName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("ガチャで新しい装飾を獲得")
                            .font(.title2.weight(.bold))
                    }

                    Spacer(minLength: 0)

                    Text(model.rarityLabel)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                if let decoration {
                    AppSectionCard(
                        title: "画像プレビュー",
                        subtitle: "見た目だけを先に確認できます。"
                    ) {
                        GachaArtworkView(
                            item: decoration,
                            displayMode: .detailHero,
                            customMaxHeight: 164,
                            customCornerRadius: 20
                        )
                    }
                }

                AppSectionCard(
                    title: model.itemName,
                    subtitle: model.revealPhrase
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let profileTitle = model.profileTitle {
                            Text(profileTitle)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(uiColor: .tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                        Text(model.flavorText)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ひとことカード")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("短い一言でも、今日はちゃんと残しておきたい。")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("プロフィール")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Me")
                            .font(.headline)
                        Text(model.statusLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                Spacer(minLength: 0)

                Text(model.statusLine)
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
        .padding(18)
    }
}

@MainActor
enum GachaShareCardRenderer {
    static func render(
        model: GachaShareCardModel,
        size: CGSize = CGSize(width: 360, height: 640),
        scale: CGFloat = 3.0
    ) -> ShareImage? {
        let content = GachaShareCardView(model: model)
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

struct GachaRarityBadge: View {
    let rarity: CardDecorationRarity

    var body: some View {
        Label(GachaThemePresentation.rarityLabel(for: rarity), systemImage: "sparkles")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(rarity.previewAccent.opacity(0.18))
            .foregroundStyle(rarity.previewAccent)
            .clipShape(Capsule())
    }
}

struct GachaOwnershipBadge: View {
    let state: GachaThemeOwnershipState

    var body: some View {
        Text(state.label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(backgroundColor.opacity(0.14))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch state {
        case .equipped:
            return .green
        case .owned:
            return .secondary
        case .locked:
            return .orange
        }
    }
}

extension CardDecorationRarity {
    var previewAccent: Color {
        switch self {
        case .common:
            return .gray
        case .rare:
            return .blue
        case .epic:
            return .purple
        case .legendary:
            return .orange
        }
    }
}
