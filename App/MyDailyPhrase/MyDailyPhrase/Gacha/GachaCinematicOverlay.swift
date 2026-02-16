import SwiftUI
import UIKit
import Domain

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
    let onSkip: () -> Void
    let onClose: () -> Void

    @State private var rotate = false
    @State private var pulse = false

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
                    .scaleEffect(pulse ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
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
                        accent: theme.primary
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

        return panelContainer {
            VStack(spacing: 12) {
                Text("結果")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    resultChip(title: "NEW", value: "\(newCount)")
                    resultChip(title: "欠片", value: "+\(summary.shardsGained)")
                    resultChip(title: "天井", value: "\(summary.pityAfter)/\(pityMax)")
                }

                LazyVGrid(columns: [.init(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(Array(summary.drawn.enumerated()), id: \.offset) { _, d in
                        let isNew = summary.newIds.contains(d.id)
                        MiniResultCard(item: d, isNew: isNew, accent: theme.primary)
                    }
                }

                Button {
                    onClose()
                    Haptics.impact(.light)
                } label: {
                    Text("閉じる")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("gacha.cinematic.result.close")
            }
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
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 6.0).repeatForever(autoreverses: false), value: rotate)

            Circle()
                .strokeBorder(theme.primary.opacity(0.14), lineWidth: 1)
                .frame(width: 380, height: 380)
                .rotationEffect(.degrees(rotate ? -360 : 0))
                .animation(.linear(duration: 8.0).repeatForever(autoreverses: false), value: rotate)
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
}

private struct FlipRevealCard: View {
    let item: CardDecoration
    let isNew: Bool
    let accent: Color

    @State private var flipped = false

    var body: some View {
        ZStack {
            if flipped && item.rarity == .legendary {
                LegendaryHalo(accent: accent)
            }

            Group {
                if flipped {
                    Card(nil, decorationId: item.id) {
                        VStack(alignment: .leading, spacing: 8) {
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

                            Text(item.rarity.rawValue.uppercased())
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("タップでスキップ")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Card("???", decorationId: nil) {
                        Text("開封…")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.spring(response: 0.44, dampingFraction: 0.84), value: flipped)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                flipped = true
                Haptics.impact(item.rarity == .legendary ? .heavy : .medium)
                if item.rarity == .legendary {
                    Haptics.notify(.success)
                }
            }
        }
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
    let accent: Color

    var body: some View {
        Card(nil, decorationId: item.id) {
            VStack(alignment: .leading, spacing: 6) {
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

                Text(item.rarity.rawValue.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(isNew ? "NEW" : "dup")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
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
