import SwiftUI

struct Card<Content: View>: View {
    @Environment(\.currentDecorationId) private var envDecorationId

    let title: String?
    let decorationId: String?
    let content: Content

    init(_ title: String? = nil, decorationId: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.decorationId = decorationId
        self.content = content()
    }

    private var style: DecorationStyle {
        DecorationStyle.from(decorationId ?? envDecorationId)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .fontDesign(.rounded)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)

                // ほんのり雰囲気を変える
                shape.fill(tintOverlay)
                    .blendMode(.overlay)
                    .opacity(0.95)

                decorationLayer
                    .allowsHitTesting(false)
                    .clipShape(shape)
            }
        }
        .clipShape(shape)
        .overlay {
            ZStack {
                // 基本の薄い枠
                shape.stroke(.white.opacity(0.10))

                // 装飾ごとの枠強化
                specialBorder(shape)
            }
        }
    }

    // MARK: - Decoration Style

    private enum DecorationStyle: String {
        case classic, sakura, aurora, neon, gold

        static func from(_ raw: String) -> DecorationStyle {
            let norm = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return DecorationStyle(rawValue: norm) ?? .classic
        }
    }

    // MARK: - Tint Overlay

    private var tintOverlay: some ShapeStyle {
        switch style {
        case .classic:
            return RadialGradient(
                colors: [Color.purple.opacity(0.10), Color.blue.opacity(0.06), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 220
            )
        case .sakura:
            return RadialGradient(
                colors: [Color.pink.opacity(0.14), Color.purple.opacity(0.06), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 220
            )
        case .aurora:
            return RadialGradient(
                colors: [Color.green.opacity(0.10), Color.blue.opacity(0.10), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 240
            )
        case .neon:
            return RadialGradient(
                colors: [Color.cyan.opacity(0.10), Color.purple.opacity(0.08), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 240
            )
        case .gold:
            return RadialGradient(
                colors: [Color.yellow.opacity(0.12), Color.orange.opacity(0.08), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 240
            )
        }
    }

    // MARK: - Decoration Layer

    @ViewBuilder
    private var decorationLayer: some View {
        switch style {
        case .classic:
            EmptyView()
        case .sakura:
            sakuraLayer
        case .aurora:
            auroraLayer
        case .neon:
            neonLayer
        case .gold:
            EmptyView() // gold は枠で見せる（下で specialBorder）
        }
    }

    private var sakuraLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                ForEach(0..<14, id: \.self) { i in
                    let size = 8 + CGFloat((i % 5) * 4)
                    let p = petalPosition(i, w: w, h: h)

                    Circle()
                        .fill(Color.pink.opacity(0.10))
                        .frame(width: size, height: size)
                        .position(x: p.x, y: p.y)
                }
            }
            .blur(radius: 0.4)
        }
    }

    private func petalPosition(_ i: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        func frac(_ x: CGFloat) -> CGFloat { x - floor(x) }
        let a = frac(CGFloat(i) * 0.6180339887)
        let b = frac(CGFloat(i) * 0.4142135623)
        let x = w * (0.10 + 0.80 * a)
        let y = h * (0.12 + 0.76 * b)
        return CGPoint(x: x, y: y)
    }

    private var auroraLayer: some View {
        LinearGradient(
            colors: [
                Color.green.opacity(0.10),
                Color.blue.opacity(0.10),
                Color.purple.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.overlay)
        .opacity(0.85)
    }

    private var neonLayer: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .inset(by: 8)
            .stroke(Color.cyan.opacity(0.22), lineWidth: 3)
            .blur(radius: 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .inset(by: 10)
                    .stroke(Color.purple.opacity(0.16), lineWidth: 2)
                    .blur(radius: 0.9)
            )
            .blendMode(.screen)
    }

    // MARK: - Special Border

    @ViewBuilder
    private func specialBorder(_ shape: RoundedRectangle) -> some View {
        switch style {
        case .gold:
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.55),
                            Color.orange.opacity(0.35),
                            Color.yellow.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        default:
            EmptyView()
        }
    }
}
