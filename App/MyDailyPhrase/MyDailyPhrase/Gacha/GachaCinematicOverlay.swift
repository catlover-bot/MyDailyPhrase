import SwiftUI
import UIKit
import Domain
import Presentation

struct GachaCinematicOverlay: View {

    enum Mode: Equatable {
        case spinning(count: Int, bannerTitle: String)
        case revealing(summary: GachaDrawSummary, index: Int)
        case result(summary: GachaDrawSummary)
    }

    private struct Theme {
        let primary: Color
        let secondary: Color
        let highlight: Color
    }

    let mode: Mode
    let pityMax: Int
    let profileDisplayName: String
    let equippedDecorationId: String
    let onSkip: () -> Void
    let onEquip: (String) -> Void
    let onShare: (CardDecoration) -> Void
    let onDrawAgain: (() -> Void)?
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotate = false
    @State private var pulse = false
    @State private var selectedResultItemID: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.90),
                    theme.secondary.opacity(0.45),
                    Color.black.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if !isSpinningMode {
                portalBackground
                    .opacity(pulse ? 1.0 : 0.8)
                    .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.03 : 0.97))
                    .animation(
                        reduceMotion
                            ? .easeOut(duration: 0.18)
                            : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: pulse
                    )
            }

            VStack(spacing: 14) {
                topBar

                switch mode {
                case .spinning(let count, let bannerTitle):
                    spinningView(count: count, bannerTitle: bannerTitle)

                case .revealing(let summary, let index):
                    revealingView(summary: summary, index: index)

                case .result(let summary):
                    resultView(summary: summary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if canSkip {
                onSkip()
                Haptics.impact(.soft)
            }
        }
        .onAppear {
            rotate = true
            pulse = true
            synchronizeSelection(for: mode)
        }
        .onChange(of: mode) { _, newMode in
            synchronizeSelection(for: newMode)
        }
    }

    private var topBar: some View {
        HStack {
            if canSkip {
                Button {
                    onSkip()
                    Haptics.impact(.soft)
                } label: {
                    Label("スキップ", systemImage: "forward.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.38))
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("gacha.cinematic.skip")
            }

            Spacer()

            if canClose {
                Button {
                    onClose()
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .padding(12)
                        .background(.black.opacity(0.38))
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("gacha.cinematic.close")
            }
        }
        .foregroundStyle(.white)
    }

    private var canSkip: Bool {
        switch mode {
        case .spinning, .revealing: return true
        case .result: return false
        }
    }

    private var canClose: Bool {
        switch mode {
        case .result:
            return true
        case .spinning, .revealing:
            return false
        }
    }

    private var isSpinningMode: Bool {
        if case .spinning = mode { return true }
        return false
    }

    private var theme: Theme {
        switch mode {
        case .spinning:
            return .init(primary: .cyan, secondary: .blue, highlight: .white)
        case .revealing(let summary, let index):
            let items = summary.drawn
            if items.indices.contains(index) {
                return theme(for: items[index].rarity)
            }
            return theme(for: nil)
        case .result(let summary):
            let rarity = summary.drawn.max(by: { rank($0.rarity) < rank($1.rarity) })?.rarity
            return theme(for: rarity)
        }
    }

    private func theme(for rarity: CardDecorationRarity?) -> Theme {
        switch rarity {
        case .legendary:
            return .init(primary: .yellow, secondary: .orange, highlight: .white)
        case .epic:
            return .init(primary: .mint, secondary: .cyan, highlight: .white)
        case .rare:
            return .init(primary: .pink, secondary: .indigo, highlight: .white)
        case .common:
            return .init(primary: .gray, secondary: .blue, highlight: .white)
        case .none:
            return .init(primary: .cyan, secondary: .blue, highlight: .white)
        }
    }

    private func spinningView(count: Int, bannerTitle: String) -> some View {
        panelContainer {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.4)
                    .frame(width: 86, height: 86)

                Text("回しています…")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("\(count)回 / \(bannerTitle)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))

                Text("画面タップまたは「スキップ」で即結果へ")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func revealingView(summary: GachaDrawSummary, index: Int) -> some View {
        let items = summary.drawn
        let safeIndex = min(max(index, 0), max(0, items.count - 1))
        let item = items.isEmpty ? nil : items[safeIndex]
        let progress = items.isEmpty ? 1.0 : Double(safeIndex + 1) / Double(max(1, items.count))

        return panelContainer {
            VStack(spacing: 12) {
                HStack {
                    Text("開封中… \(safeIndex + 1)/\(max(1, items.count))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer()
                    if let item {
                        Text(item.rarity.rawValue.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.primary.opacity(0.28))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                    }
                }

                progressBar(progress)

                if let item {
                    FlipRevealCard(
                        item: item,
                        isNew: summary.newIds.contains(item.id),
                        accent: theme.primary,
                        reduceMotion: reduceMotion
                    )
                    .id("\(item.id)_\(safeIndex)")
                    .frame(maxWidth: .infinity)
                }

                Text("欠片 +\(summary.shardsGained) / 天井 \(summary.pityAfter)/\(pityMax)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
            }
        }
    }

    private func resultView(summary: GachaDrawSummary) -> some View {
        let newCount = summary.newIds.count
        let selectedItem = selectedResultItem(in: summary)
        let canRepeat = onDrawAgain != nil

        return panelContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("結果")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("見た目を確認して、その場で装備できます")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.76))
                    }

                    Spacer(minLength: 0)

                    if let selectedItem {
                        GachaRarityBadge(rarity: selectedItem.rarity)
                    }
                }

                HStack(spacing: 8) {
                    resultChip(title: "NEW", value: "\(newCount)")
                    resultChip(title: "欠片", value: "+\(summary.shardsGained)")
                    resultChip(title: "天井", value: "\(summary.pityAfter)/\(pityMax)")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let selectedItem {
                            GachaThemePreviewContent(
                                item: selectedItem,
                                ownedCount: max(1, summary.drawn.filter { $0.id == selectedItem.id }.count),
                                isOwned: true,
                                isEquipped: equippedDecorationId == selectedItem.id,
                                profileDisplayName: profileDisplayName,
                                previewSurfaceLimit: 3
                            )
                            .id("preview_\(selectedItem.id)_\(equippedDecorationId)")
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .opacity.combined(with: .scale(scale: 0.98))
                            )
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("今回の獲得アイテム")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.88))

                            LazyVGrid(columns: [.init(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                                ForEach(Array(summary.drawn.enumerated()), id: \.offset) { _, item in
                                    let isNew = summary.newIds.contains(item.id)
                                    MiniResultCard(
                                        item: item,
                                        isNew: isNew,
                                        isSelected: selectedItem?.id == item.id,
                                        accent: theme.primary
                                    ) {
                                        selectedResultItemID = item.id
                                        Haptics.impact(.soft)
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            equipButton(for: selectedItem)
                            shareButton(for: selectedItem)
                        }

                        VStack(spacing: 10) {
                            equipButton(for: selectedItem)
                            shareButton(for: selectedItem)
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            laterButton
                            if canRepeat {
                                drawAgainButton
                            }
                        }

                        VStack(spacing: 10) {
                            laterButton
                            if canRepeat {
                                drawAgainButton
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var portalBackground: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.primary.opacity(0.30), .clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 220
                    )
                )
                .scaleEffect(1.08)

            Circle()
                .strokeBorder(theme.highlight.opacity(0.16), lineWidth: 2)
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(reduceMotion ? 0 : (rotate ? 360 : 0)))
                .animation(
                    reduceMotion ? .default : .linear(duration: 6.0).repeatForever(autoreverses: false),
                    value: rotate
                )

            Circle()
                .strokeBorder(theme.primary.opacity(0.14), lineWidth: 1)
                .frame(width: 380, height: 380)
                .rotationEffect(.degrees(reduceMotion ? 0 : (rotate ? -360 : 0)))
                .animation(
                    reduceMotion ? .default : .linear(duration: 8.0).repeatForever(autoreverses: false),
                    value: rotate
                )
        }
        .frame(width: 520, height: 520)
    }

    private func panelContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.56),
                                theme.secondary.opacity(0.23)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(theme.primary.opacity(0.24), lineWidth: 1)
                    }
            }
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { geo in
            let p = min(1.0, max(0.0, progress))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(.white.opacity(0.14))

                RoundedRectangle(cornerRadius: 999)
                    .fill(
                        LinearGradient(
                            colors: [theme.primary.opacity(0.92), theme.secondary.opacity(0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * p)
            }
        }
        .frame(height: 8)
    }

    private func resultChip(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func rank(_ rarity: CardDecorationRarity) -> Int {
        switch rarity {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }

    private func selectedResultItem(in summary: GachaDrawSummary) -> CardDecoration? {
        if let selectedResultItemID,
           let selected = summary.drawn.last(where: { $0.id == selectedResultItemID }) {
            return selected
        }
        return defaultResultItem(in: summary)
    }

    private func defaultResultItem(in summary: GachaDrawSummary) -> CardDecoration? {
        let newItems = summary.drawn.filter { summary.newIds.contains($0.id) }
        let source = newItems.isEmpty ? summary.drawn : newItems
        guard let maxRank = source.map({ rank($0.rarity) }).max() else { return nil }
        return source.last(where: { rank($0.rarity) == maxRank })
    }

    private func synchronizeSelection(for mode: Mode) {
        guard case .result(let summary) = mode else { return }
        selectedResultItemID = defaultResultItem(in: summary)?.id
    }

    private func equipButton(for item: CardDecoration?) -> some View {
        Button {
            guard let item else { return }
            onEquip(item.id)
            Haptics.notify(.success)
        } label: {
            Label(
                item.map { GachaThemePresentation.primaryEquipLabel(for: $0, isEquipped: equippedDecorationId == $0.id) } ?? "まとめて装備",
                systemImage: item.map { equippedDecorationId == $0.id ? "checkmark.circle.fill" : "person.crop.circle.badge.checkmark" } ?? "person.crop.circle.badge.checkmark"
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(item == nil || item.map { equippedDecorationId == $0.id } == true)
    }

    private func shareButton(for item: CardDecoration?) -> some View {
        Button {
            guard let item else { return }
            onShare(item)
            Haptics.impact(.light)
        } label: {
            Label("結果を共有", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .disabled(item == nil || !FeatureFlags.nativeSharingEnabled)
    }

    private var laterButton: some View {
        Button {
            onClose()
            Haptics.impact(.light)
        } label: {
            Label("あとで使う", systemImage: "clock")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("gacha.cinematic.result.close")
    }

    private var drawAgainButton: some View {
        Button {
            onDrawAgain?()
            Haptics.impact(.medium)
        } label: {
            Label("もう一回ひく", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
    }
}

private struct FlipRevealCard: View {
    let item: CardDecoration
    let isNew: Bool
    let accent: Color
    let reduceMotion: Bool

    @State private var flipped = false

    var body: some View {
        ZStack {
            if flipped && item.rarity == .legendary && !reduceMotion {
                LegendaryHalo(accent: accent)
            }

            Group {
                if flipped {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(item.name)
                                .font(.title3.weight(.bold))
                            Spacer()
                            if isNew {
                                Text("NEW")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                        }

                        GachaArtworkView(
                            item: item,
                            displayMode: .decorativeAccent,
                            customMaxHeight: 116,
                            customCornerRadius: 18
                        )

                        GachaRarityBadge(rarity: item.rarity)

                        Text(GachaThemePresentation.flavorText(for: item))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Text("タップでスキップ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                } else {
                    Card("???", decorationId: nil) {
                        Text("開封…")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (flipped ? 180 : 0)),
                axis: (x: 0, y: 1, z: 0)
            )
            .scaleEffect(reduceMotion ? (flipped ? 1.0 : 0.98) : 1.0)
            .opacity(flipped ? 1.0 : (reduceMotion ? 0.75 : 1.0))
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.22)
                : .spring(response: 0.44, dampingFraction: 0.84),
            value: flipped
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                flipped = true
                Haptics.impact(item.rarity == .legendary ? .heavy : .medium)
                if item.rarity == .legendary && !reduceMotion {
                    Haptics.notify(.success)
                }
            }
        }
    }
}

struct GachaResultDetailScreen: View {
    let summary: GachaDrawSummary
    let pityMax: Int
    let profileDisplayName: String
    let equippedDecorationId: String
    let onEquip: (String) -> Void
    let onShare: (CardDecoration) -> Void
    let onDrawAgain: (() -> Void)?
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedResultItemID: String?

    var body: some View {
        ZStack {
            AppScreenBackground()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let selectedItem {
                            heroSection(for: selectedItem)

                            GachaThemePreviewContent(
                                item: selectedItem,
                                ownedCount: max(1, summary.drawn.filter { $0.id == selectedItem.id }.count),
                                isOwned: true,
                                isEquipped: equippedDecorationId == selectedItem.id,
                                profileDisplayName: profileDisplayName,
                                showsHeroCard: false,
                                showsSummaryCard: false,
                                showsUsageCard: true,
                                previewSurfaceLimit: 1
                            )
                            .id("result_preview_\(selectedItem.id)_\(equippedDecorationId)")
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .opacity.combined(with: .scale(scale: 0.99))
                            )
                        }

                        AppSectionCard(
                            title: "今回の獲得アイテム",
                            subtitle: "気になるアイテムを選ぶと、上のプレビューが切り替わります。"
                        ) {
                            LazyVGrid(columns: [.init(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                                ForEach(Array(summary.drawn.enumerated()), id: \.offset) { _, item in
                                    MiniResultCard(
                                        item: item,
                                        isNew: summary.newIds.contains(item.id),
                                        isSelected: selectedItem?.id == item.id,
                                        accent: item.rarity.previewAccent
                                    ) {
                                        selectedResultItemID = item.id
                                        Haptics.impact(.soft)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 220)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .onAppear {
            if selectedResultItemID == nil {
                selectedResultItemID = defaultResultItem(in: summary)?.id
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                onClose()
                Haptics.impact(.light)
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("獲得アイテム")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("見た目を確認して、使う場所を選べます")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if let selectedItem {
                GachaRarityBadge(rarity: selectedItem.rarity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private func heroSection(for item: CardDecoration) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionCard(
                title: "画像プレビュー",
                subtitle: "このアイテムの見た目です。"
            ) {
                GachaArtworkView(
                    item: item,
                    displayMode: .resultHero
                )
            }

            AppSectionCard(
                title: item.name,
                subtitle: GachaThemePresentation.revealPhrase(for: item)
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 10) {
                            HStack(spacing: 8) {
                                stateBadge(for: item)
                                typeBadge(for: item)
                            }
                            Spacer(minLength: 0)
                            GachaRarityBadge(rarity: item.rarity)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                stateBadge(for: item)
                                typeBadge(for: item)
                            }
                            GachaRarityBadge(rarity: item.rarity)
                        }
                    }

                    Text(GachaThemePresentation.flavorText(for: item))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("装備できる場所")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    surfaceChipGrid(labels: GachaThemePresentation.applicableSurfaceLabels(for: item))

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            summaryChip(
                                title: "NEW",
                                value: summary.newIds.contains(item.id) ? "はい" : "既所持",
                                tint: summary.newIds.contains(item.id) ? item.rarity.previewAccent : .secondary
                            )
                            summaryChip(title: "欠片", value: "+\(summary.shardsGained)", tint: .orange)
                            summaryChip(title: "天井", value: "\(summary.pityAfter)/\(pityMax)", tint: .blue)
                        }

                        VStack(spacing: 10) {
                            summaryChip(
                                title: "NEW",
                                value: summary.newIds.contains(item.id) ? "はい" : "既所持",
                                tint: summary.newIds.contains(item.id) ? item.rarity.previewAccent : .secondary
                            )
                            summaryChip(title: "欠片", value: "+\(summary.shardsGained)", tint: .orange)
                            summaryChip(title: "天井", value: "\(summary.pityAfter)/\(pityMax)", tint: .blue)
                        }
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    equipButton
                    shareButton
                }

                VStack(spacing: 10) {
                    equipButton
                    shareButton
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    closeButton
                    if let onDrawAgain {
                        drawAgainButton(onDrawAgain)
                    }
                }

                VStack(spacing: 10) {
                    closeButton
                    if let onDrawAgain {
                        drawAgainButton(onDrawAgain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var selectedItem: CardDecoration? {
        if let selectedResultItemID,
           let selected = summary.drawn.last(where: { $0.id == selectedResultItemID }) {
            return selected
        }
        return defaultResultItem(in: summary)
    }

    private func defaultResultItem(in summary: GachaDrawSummary) -> CardDecoration? {
        let newItems = summary.drawn.filter { summary.newIds.contains($0.id) }
        let source = newItems.isEmpty ? summary.drawn : newItems
        guard let maxRank = source.map({ rank($0.rarity) }).max() else { return nil }
        return source.last(where: { rank($0.rarity) == maxRank })
    }

    private func rank(_ rarity: CardDecorationRarity) -> Int {
        switch rarity {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }

    private func stateBadge(for item: CardDecoration) -> some View {
        let isEquipped = equippedDecorationId == item.id
        let label = isEquipped ? "現在装備中" : (summary.newIds.contains(item.id) ? "NEW" : "所持済み")
        let tint = isEquipped ? item.rarity.previewAccent : (summary.newIds.contains(item.id) ? item.rarity.previewAccent : .secondary)

        return Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }

    private func typeBadge(for item: CardDecoration) -> some View {
        Text(GachaThemePresentation.itemTypeLabel(for: item))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func summaryChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }

    private func surfaceChipGrid(labels: [String]) -> some View {
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

    private var equipButton: some View {
        Button {
            guard let selectedItem else { return }
            onEquip(selectedItem.id)
            Haptics.notify(.success)
        } label: {
            Label(
                selectedItem.map { GachaThemePresentation.primaryEquipLabel(for: $0, isEquipped: equippedDecorationId == $0.id) } ?? "まとめて装備",
                systemImage: selectedItem.map { equippedDecorationId == $0.id ? "checkmark.circle.fill" : "person.crop.circle.badge.checkmark" } ?? "person.crop.circle.badge.checkmark"
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedItem == nil || selectedItem.map { equippedDecorationId == $0.id } == true)
    }

    private var shareButton: some View {
        Button {
            guard let selectedItem else { return }
            onShare(selectedItem)
            Haptics.impact(.light)
        } label: {
            Label("結果を共有", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItem == nil || !FeatureFlags.nativeSharingEnabled)
    }

    private var closeButton: some View {
        Button {
            onClose()
            Haptics.impact(.light)
        } label: {
            Label("閉じる", systemImage: "xmark")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
    }

    private func drawAgainButton(_ action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.impact(.medium)
        } label: {
            Label("もう一回ひく", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
    }
}

private struct LegendaryHalo: View {
    let accent: Color

    @State private var expand = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.34), lineWidth: 3)
                .scaleEffect(expand ? 1.22 : 0.82)
                .opacity(expand ? 0.0 : 1.0)

            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 1.5)
                .scaleEffect(expand ? 1.12 : 0.92)
                .opacity(expand ? 0.0 : 1.0)
        }
        .padding(6)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.66).repeatForever(autoreverses: false)) {
                expand = true
            }
        }
    }
}

private struct MiniResultCard: View {
    let item: CardDecoration
    let isNew: Bool
    let isSelected: Bool
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                GachaArtworkView(
                    item: item,
                    displayMode: .thumbnail,
                    customMaxHeight: 64,
                    customCornerRadius: 14
                )

                HStack {
                    Circle()
                        .fill(accent.opacity(0.7))
                        .frame(width: 6, height: 6)
                    Text(item.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    if isNew { Image(systemName: "sparkles") }
                }

                Text(GachaThemePresentation.rarityLabel(for: item.rarity))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(isNew ? "NEW" : "所持済み")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.95) : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(type)
    }
}
