import SwiftUI
import UIKit
import LinkPresentation

/// 画像+テキスト+URL を「それっぽく」共有するためのアイテム
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

    // プレースホルダ（必須）
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    // 実際に渡すアイテム（基本はテキスト返しが最も事故が少ない）
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any {
        text
    }

    // 件名（Mail等）
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        extractTitle(from: text) ?? "MyDailyPhrase"
    }

    // 共有プレビュー（メタデータ）
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
