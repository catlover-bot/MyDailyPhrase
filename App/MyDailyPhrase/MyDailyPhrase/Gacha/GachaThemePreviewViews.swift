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

    private var ownershipState: GachaThemeOwnershipState {
        GachaThemePresentation.ownershipState(isOwned: isOwned, isEquipped: isEquipped)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHeroCard {
                heroCard
            }
            journalPreviewCard
            profilePreviewCard
            sharePreviewCard
            usageCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCard: some View {
        Card(nil, decorationId: item.id) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(GachaThemePresentation.revealPhrase(for: item))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 8) {
                            GachaRarityBadge(rarity: item.rarity)
                            GachaOwnershipBadge(state: ownershipState)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(GachaThemePresentation.revealPhrase(for: item))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            GachaRarityBadge(rarity: item.rarity)
                            GachaOwnershipBadge(state: ownershipState)
                        }
                    }
                }

                Text(GachaThemePresentation.flavorText(for: item))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        detailChip(systemImage: "sparkles", text: ownershipState.label)
                        detailChip(systemImage: "square.stack.3d.up", text: GachaThemePresentation.itemTypeLabel(for: item))
                        detailChip(systemImage: "shippingbox", text: isOwned ? "所持 x\(max(1, ownedCount))" : "コレクション未登録")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        detailChip(systemImage: "sparkles", text: ownershipState.label)
                        detailChip(systemImage: "square.stack.3d.up", text: GachaThemePresentation.itemTypeLabel(for: item))
                        detailChip(systemImage: "shippingbox", text: isOwned ? "所持 x\(max(1, ownedCount))" : "コレクション未登録")
                    }
                }

                GachaArtworkPreviewPanel(
                    item: item,
                    prefersThumbnail: false,
                    minHeight: 212
                )
            }
        }
    }

    private var journalPreviewCard: some View {
        Card(journalPreviewTitle, decorationId: item.id) {
            VStack(alignment: .leading, spacing: 10) {
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
        }
    }

    private var profilePreviewCard: some View {
        Card(profilePreviewTitle, decorationId: item.id) {
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
                                Text(title)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                            if isEquipped {
                                Text("装備中")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.rarity.previewAccent.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(profileDisplayName)
                                .font(.headline)

                            HStack(spacing: 8) {
                                if let title = GachaThemePresentation.profileTitle(for: item) {
                                    Text(title)
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                }
                                if isEquipped {
                                    Text("装備中")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(item.rarity.previewAccent.opacity(0.18))
                                        .clipShape(Capsule())
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
    }

    private var sharePreviewCard: some View {
        Card(sharePreviewTitle, decorationId: item.id) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ひとこと日記")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(GachaThemePresentation.rarityLabel(for: item.rarity))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                Text(item.name)
                    .font(.headline)

                if let template = GachaThemePresentation.shareTemplateName(for: item) {
                    Text(template)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                Text(GachaThemePresentation.sampleShareCaption(for: item, isEquipped: isEquipped))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("装備できる場所", systemImage: "rectangle.on.rectangle.angled")
                .font(.subheadline.weight(.semibold))

            Text(GachaThemePresentation.usageText(for: item))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !GachaThemePresentation.applicableSurfaceLabels(for: item).isEmpty {
                FlexibleSurfaceChips(labels: GachaThemePresentation.applicableSurfaceLabels(for: item))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var profileInitial: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "M" : trimmed).prefix(1)).uppercased()
    }

    private var journalPreviewTitle: String {
        switch GachaThemePresentation.decorationItem(for: item).itemType {
        case .journalPaper:
            return "日記カード（紙面）"
        case .cardFrame:
            return "日記カード（フレーム）"
        case .promptPack:
            return "お題カード"
        default:
            return "日記カード"
        }
    }

    private var profilePreviewTitle: String {
        switch GachaThemePresentation.decorationItem(for: item).itemType {
        case .profileTitle:
            return "プロフィールカード（称号）"
        case .background:
            return "プロフィールカード（背景）"
        case .badge:
            return "プロフィールカード（バッジ）"
        default:
            return "プロフィールカード"
        }
    }

    private var sharePreviewTitle: String {
        switch GachaThemePresentation.decorationItem(for: item).itemType {
        case .shareTemplate:
            return "共有カード（テンプレート）"
        case .gachaRevealEffect:
            return "共有カード（演出）"
        case .badge:
            return "共有カード（バッジ）"
        default:
            return "共有カード"
        }
    }

    private func detailChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

struct GachaArtworkPreviewPanel: View {
    let item: CardDecoration
    let prefersThumbnail: Bool
    let minHeight: CGFloat
    var cornerRadius: CGFloat = 18
    var showsCaption: Bool = true

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
        if prefersThumbnail {
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
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundGradient)

            if let resolvedImage {
                Image(uiImage: resolvedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
            } else {
                fallbackArtwork
                    .padding(16)
            }

            if showsCaption {
                caption
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(GachaThemePresentation.itemTypeLabel(for: item))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.rarity.previewAccent)
                    Text(item.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: symbolName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(item.rarity.previewAccent)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                GachaRarityBadge(rarity: item.rarity)
                if prefersThumbnail {
                    Text("画像準備前プレビュー")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            if resolvedImage != nil {
                Text("アートワークを表示")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("画像未追加でもこのまま使えます")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(item.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
}

private struct FlexibleSurfaceChips: View {
    let labels: [String]

    var body: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
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
                Card(nil, decorationId: item.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            GachaRarityBadge(rarity: item.rarity)
                            Spacer()
                            if isEquipped {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(item.rarity.previewAccent)
                            }
                        }

                        GachaArtworkPreviewPanel(
                            item: item,
                            prefersThumbnail: true,
                            minHeight: 84,
                            cornerRadius: 14,
                            showsCaption: false
                        )

                        Text(item.name)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(GachaThemePresentation.itemTypeLabel(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(height: 214)
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

                Card(nil, decorationId: model.decorationId) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.itemName)
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text(model.revealPhrase)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if let profileTitle = model.profileTitle {
                            Text(profileTitle)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                        Text(model.flavorText)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(height: 180)

                HStack(spacing: 12) {
                    Card("ひとことカード", decorationId: model.decorationId) {
                        Text("短い一言でも、今日はちゃんと残しておきたい。")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Card("プロフィール", decorationId: model.decorationId) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Me")
                                .font(.headline)
                            Text(model.statusLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
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
