import SwiftUI
import UIKit
import LinkPresentation

/// 画像+テキスト+URL を「それっぽく」共有するためのアイテム（プレビュー整形用）
final class SharePayload: NSObject, UIActivityItemSource {
    private let text: String
    private let image: UIImage?
    private let url: URL?

    init(text: String, image: UIImage?, url: URL?) {
        self.text = text
        self.image = image
        self.url = url
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    /// ここはテキスト固定でOK（画像は別アイテムとして渡す）
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any {
        text
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        extractTitle(from: text) ?? "MyDailyPhrase"
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let meta = LPLinkMetadata()
        meta.title = extractTitle(from: text) ?? "MyDailyPhrase"

        if let url {
            meta.originalURL = url
            meta.url = url
        }

        if let image {
            let provider = NSItemProvider(object: image)
            meta.imageProvider = provider
            meta.iconProvider = provider
        }

        return meta
    }

    private func extractTitle(from text: String) -> String? {
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)

        guard let s = firstLine?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }

        return s.count > 40 ? String(s.prefix(40)) + "…" : s
    }
}

/// UIActivityViewController に渡す items を安定化（画像が確実に渡る）
enum ShareItemsBuilder {
    static func build(text: String, image: UIImage?, url: URL?) -> [Any] {
        var items: [Any] = []

        // 1) プレビュー整形
        items.append(SharePayload(text: text, image: image, url: url))

        // 2) 本体：画像（最重要）
        if let image { items.append(image) }

        // 3) URL（コピー/保存に強い）
        if let url { items.append(url) }

        // 4) テキスト（共有先により効く）
        items.append(text)

        return items
    }
}

/// SwiftUI から呼ぶ ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.excludedActivityTypes = excludedActivityTypes
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // no-op
    }
}
