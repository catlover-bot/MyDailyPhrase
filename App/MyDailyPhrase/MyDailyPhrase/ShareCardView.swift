import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

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

    // ✅ 呼び出し側から差し替え可能にする
    let shareURL: URL?

    // ✅ 既存呼び出しを壊さない（デフォルトは GitHub）
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
        self.shareURL = shareURL
    }
}


struct ShareCardView: View {
    let model: ShareCardModel

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 14) {
                header

                Text((model.title?.isEmpty == false) ? (model.title ?? "") : "今日の一文")
                    .font(.system(size: 30, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let summary = model.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
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
                colors: [
                    Color.purple.opacity(0.12),
                    Color.blue.opacity(0.08),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 360
            )
        )
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

            Text("🔥 \(model.streakText)")
                .font(.system(size: 12, weight: .bold))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
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
                        // ✅ Quiet Zone を強制（スキャン率が上がる）
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

                // ✅ 下端にフェード（長文でも“読める感”が出る）
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.04)
                    ],
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

    // MARK: - QR

    private static let ciContext = CIContext()
    private static let qrFilter = CIFilter.qrCodeGenerator()

    private func makeQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)

        let f = Self.qrFilter
        f.setValue(data, forKey: "inputMessage")
        f.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = f.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        guard let cgImage = Self.ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func shortURLText(_ url: URL) -> String {
        let host = url.host ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty { return host }
        let comps = path.split(separator: "/").prefix(2).joined(separator: "/")
        return host.isEmpty ? String(comps) : "\(host)/\(comps)"
    }
}

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
