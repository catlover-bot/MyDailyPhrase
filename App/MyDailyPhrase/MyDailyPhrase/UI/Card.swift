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

    private enum DecorationStyle: String, CaseIterable {
        case classic, sakura, aurora, neon, gold, starlight, ocean

        static func from(_ raw: String) -> DecorationStyle {
            let resolved = DecorationThemeResolver.resolveStyleID(
                from: raw,
                supportedStyleIDs: Set(Self.allCases.map(\.rawValue))
            )
            return DecorationStyle(rawValue: resolved) ?? .classic
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
        case .starlight:
            return RadialGradient(
                colors: [Color(hex: 0x6a0dad).opacity(0.12), Color(hex: 0x00008b).opacity(0.10), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 240
            )
        case .ocean:
            return RadialGradient(
                colors: [Color.cyan.opacity(0.12), Color.blue.opacity(0.10), Color.clear],
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
        case .starlight:
            starlightLayer
        case .ocean:
            oceanLayer
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

    private var starlightLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                ForEach(0..<25, id: \.self) { i in
                    let size = 1 + CGFloat(i % 5) * 0.8
                    let p = starPosition(i, w: w, h: h)
                    let opacity = starOpacity(i)

                    Circle()
                        .fill(starColor(i))
                        .frame(width: size, height: size)
                        .position(x: p.x, y: p.y)
                        .opacity(opacity)
                }
            }
            .blur(radius: 0.6)
        }
    }

    private var oceanLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.15),
                    Color.blue.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.overlay)
            .opacity(0.8)

            RadialGradient(
                colors: [Color.white.opacity(0.1), .clear],
                center: .top,
                startRadius: 5,
                endRadius: 150
            )
            .blendMode(.screen)
            .opacity(0.5)
        }
    }

    private func starPosition(_ i: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        func frac(_ x: CGFloat) -> CGFloat { x - floor(x) }
        let a = frac(CGFloat(i) * 0.3180339887) // Use different seeds
        let b = frac(CGFloat(i) * 0.6142135623)
        let x = w * (0.05 + 0.90 * a)
        let y = h * (0.05 + 0.90 * b)
        return CGPoint(x: x, y: y)
    }

    private func starOpacity(_ i: Int) -> Double {
        func frac(_ x: Double) -> Double { x - floor(x) }
        return 0.3 + frac(Double(i) * 0.11) * 0.5
    }

    private func starColor(_ i: Int) -> Color {
        let colors: [Color] = [.white.opacity(0.8), .cyan.opacity(0.5), .purple.opacity(0.4)]
        return colors[i % colors.count]
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
