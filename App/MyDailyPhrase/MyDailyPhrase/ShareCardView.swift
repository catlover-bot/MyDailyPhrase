import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Model

struct ShareCardModel: Equatable {
    let appName: String
    let dateText: String
    let streakText: String
    let prompt: String
    let answer: String

    let title: String?
    let summary: String?
    let moodTags: [String]
    let keywords: [String]

    let metaLine: String?
    let statsLine: String?

    let decorationId: String
    let shareURL: URL?

    init(
        appName: String,
        dateText: String,
        streakText: String,
        prompt: String,
        answer: String,
        title: String?,
        summary: String?,
        moodTags: [String],
        keywords: [String],
        metaLine: String? = nil,
        statsLine: String? = nil,
        decorationId: String = "classic",
        shareURL: URL? = URL(string: "https://github.com/catlover-bot/MyDailyPhrase")
    ) {
        self.appName = appName
        self.dateText = dateText
        self.streakText = streakText
        self.prompt = prompt
        self.answer = answer
        self.title = title
        self.summary = summary
        self.moodTags = moodTags
        self.keywords = keywords
        self.metaLine = metaLine
        self.statsLine = statsLine
        self.decorationId = decorationId
        self.shareURL = shareURL
    }
}

// MARK: - View

struct ShareCardView: View {
    let model: ShareCardModel

    private var decoration: DecorationStyle {
        DecorationStyle.from(model.decorationId)
    }

    var body: some View {
        ZStack {
            background
            decorationLayer
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                header

                if let meta = trimmed(model.metaLine), !meta.isEmpty {
                    Text(meta)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text((model.title?.isEmpty == false) ? (model.title ?? "") : "今日の一文")
                    .font(.system(size: 30, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let summary = trimmed(model.summary), !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let stats = trimmed(model.statsLine), !stats.isEmpty {
                    statsChip(stats)
                }

                cardSection(title: "お題", body: model.prompt, maxLines: 4)
                answerSection()

                if !model.moodTags.isEmpty {
                    chipRow(title: "気分", tags: Array(model.moodTags.prefix(6)))
                }

                if !model.keywords.isEmpty {
                    chipRow(title: "キーワード", tags: Array(model.keywords.prefix(6)))
                }

                Spacer(minLength: 8)
                footer
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(18)
    }

    // MARK: - Decoration Style

    private enum DecorationStyle: String {
        case classic
        case paper
        case noir
        case sakura
        case neon
        case aurora
        case glitch
        case gold

        static func from(_ raw: String) -> DecorationStyle {
            let norm = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return DecorationStyle(rawValue: norm) ?? .classic
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: baseTintColors,
                center: .topTrailing,
                startRadius: 40,
                endRadius: 360
            )
        )
    }

    private var baseTintColors: [Color] {
        switch decoration {
        case .classic:
            return [Color.purple.opacity(0.12), Color.blue.opacity(0.08), Color.clear]
        case .paper:
            return [Color.brown.opacity(0.08), Color.yellow.opacity(0.06), Color.clear]
        case .noir:
            return [Color.black.opacity(0.10), Color.gray.opacity(0.06), Color.clear]
        case .sakura:
            return [Color.pink.opacity(0.14), Color.purple.opacity(0.06), Color.clear]
        case .aurora:
            return [Color.green.opacity(0.10), Color.blue.opacity(0.10), Color.clear]
        case .neon:
            return [Color.cyan.opacity(0.10), Color.purple.opacity(0.08), Color.clear]
        case .glitch:
            return [Color.cyan.opacity(0.08), Color.red.opacity(0.06), Color.clear]
        case .gold:
            return [Color.yellow.opacity(0.12), Color.orange.opacity(0.08), Color.clear]
        }
    }

    // MARK: - Decoration Layer

    @ViewBuilder
    private var decorationLayer: some View {
        switch decoration {
        case .classic:
            EmptyView()
        case .paper:
            paperLayer
        case .noir:
            noirLayer
        case .sakura:
            sakuraLayer
        case .aurora:
            auroraLayer
        case .neon:
            neonLayer
        case .glitch:
            glitchLayer
        case .gold:
            goldLayer
        }
    }

    private var paperLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 罫線っぽい薄いライン
                Path { p in
                    let step: CGFloat = 22
                    var y: CGFloat = 40
                    while y < h - 40 {
                        p.move(to: CGPoint(x: 26, y: y))
                        p.addLine(to: CGPoint(x: w - 26, y: y))
                        y += step
                    }
                }
                .stroke(Color.black.opacity(0.05), lineWidth: 1)

                // 左余白のマージン線
                Path { p in
                    p.move(to: CGPoint(x: 58, y: 26))
                    p.addLine(to: CGPoint(x: 58, y: h - 26))
                }
                .stroke(Color.red.opacity(0.06), lineWidth: 2)
            }
        }
        .ignoresSafeArea()
    }

    private var noirLayer: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .inset(by: 6)
            .stroke(Color.black.opacity(0.18), lineWidth: 3)
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.10), Color.clear, Color.black.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            )
            .blendMode(.multiply)
            .ignoresSafeArea()
    }

    private var glitchLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // スキャンライン
                Path { p in
                    let step: CGFloat = 10
                    var y: CGFloat = 20
                    while y < h - 20 {
                        p.move(to: CGPoint(x: 16, y: y))
                        p.addLine(to: CGPoint(x: w - 16, y: y))
                        y += step
                    }
                }
                .stroke(Color.black.opacity(0.03), lineWidth: 1)

                // “ズレ” っぽい矩形
                ForEach(0..<10, id: \.self) { i in
                    let frac = CGFloat(i) / 10.0
                    let y = 40 + (h - 80) * frac
                    RoundedRectangle(cornerRadius: 8)
                        .fill((i % 2 == 0) ? Color.cyan.opacity(0.06) : Color.red.opacity(0.05))
                        .frame(width: w * 0.72, height: 10)
                        .position(x: w * 0.52 + (i % 2 == 0 ? 8 : -8), y: y)
                        .blendMode(.screen)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var sakuraLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    let size = petalSize(i)
                    let p = petalPosition(i, w: w, h: h)

                    Circle()
                        .fill(Color.pink.opacity(0.10))
                        .frame(width: size, height: size)
                        .position(x: p.x, y: p.y)
                }
            }
            .blur(radius: 0.4)
        }
        .ignoresSafeArea()
    }

    private func petalSize(_ i: Int) -> CGFloat {
        let base = 10 + (i % 5) * 6
        return CGFloat(base)
    }

    private func petalPosition(_ i: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        func frac(_ x: CGFloat) -> CGFloat { x - floor(x) }
        let a = frac(CGFloat(i) * 0.6180339887)
        let b = frac(CGFloat(i) * 0.4142135623)
        let x = w * (0.10 + 0.80 * a)
        let y = h * (0.08 + 0.84 * b)
        return CGPoint(x: x, y: y)
    }

    private var auroraLayer: some View {
        LinearGradient(
            colors: [
                Color.green.opacity(0.10),
                Color.blue.opacity(0.10),
                Color.purple.opacity(0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.overlay)
        .opacity(0.85)
        .ignoresSafeArea()
    }

    private var neonLayer: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .inset(by: 8)
            .stroke(Color.cyan.opacity(0.22), lineWidth: 4)
            .blur(radius: 1.2)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .inset(by: 10)
                    .stroke(Color.purple.opacity(0.16), lineWidth: 2)
                    .blur(radius: 1.0)
            )
            .blendMode(.screen)
            .ignoresSafeArea()
    }

    private var goldLayer: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .inset(by: 6)
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
                lineWidth: 6
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .inset(by: 12)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .ignoresSafeArea()
    }

    // MARK: - Header / Footer

    private var header: some View {
        HStack {
            Text(model.appName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)

            Spacer()

            Text(model.dateText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            let s = model.streakText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty {
                Text("🔥 \(s)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("#MyDailyPhrase")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("今日の一文を作品にする")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let url = model.shareURL, let qr = makeQRCode(from: url.absoluteString) {
                VStack(alignment: .trailing, spacing: 6) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 70, height: 70)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.10), lineWidth: 1)
                        )

                    Text(shortURLText(url))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Sections

    private func cardSection(title: String, body: String, maxLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            Text(body)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(maxLines)
        }
        .padding(12)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func answerSection() -> some View {
        let body = model.answer.isEmpty ? "（未回答）" : model.answer

        return VStack(alignment: .leading, spacing: 8) {
            Text("回答")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .bottom) {
                Text(body)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 18)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func chipRow(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { t in
                    Text(t)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func statsChip(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func trimmed(_ s: String?) -> String? {
        s?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - QR

    private static let ciContext = CIContext()
    private static let qrFilter = CIFilter.qrCodeGenerator()

    private func makeQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)

        let f = Self.qrFilter
        f.message = data
        f.correctionLevel = "M"

        guard let outputImage = f.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        guard let cgImage = Self.ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func shortURLText(_ url: URL) -> String {
        let host = url.host ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty { return host.isEmpty ? url.absoluteString : host }
        let comps = path.split(separator: "/").prefix(2).joined(separator: "/")
        return host.isEmpty ? String(comps) : "\(host)/\(comps)"
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 360

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += (x > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
