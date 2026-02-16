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
    ) -> Any? {
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

        if let previewURL = ShareURLPolicy.previewURL(from: url) {
            meta.originalURL = previewURL
            meta.url = previewURL
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
        let effectiveText = ShareURLPolicy.textByAppendingCustomURLIfNeeded(text, url: url)

        // 1) プレビュー整形
        items.append(SharePayload(text: effectiveText, image: image, url: url))

        // 2) 本体：画像（最重要）
        if let image { items.append(image) }

        // 3) URL（Web URL のみを直接添付。custom scheme はテキスト側へ）
        if let shareURL = ShareURLPolicy.urlItem(from: url) {
            items.append(shareURL)
        }

        // 4) テキスト（共有先により効く）
        items.append(effectiveText)

        return items
    }
}

private enum ShareURLPolicy {
    static func previewURL(from url: URL?) -> URL? {
        guard let url, isWebURL(url) else { return nil }
        return url
    }

    static func urlItem(from url: URL?) -> URL? {
        guard let url, isWebURL(url) else { return nil }
        return url
    }

    static func textByAppendingCustomURLIfNeeded(_ text: String, url: URL?) -> String {
        guard let url else { return text }
        guard !isWebURL(url) else { return text }
        guard !text.contains(url.absoluteString) else { return text }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return url.absoluteString }
        return "\(trimmed)\n\(url.absoluteString)"
    }

    private static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
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
