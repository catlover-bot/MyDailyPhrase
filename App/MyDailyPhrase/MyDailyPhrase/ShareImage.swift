import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum ShareExportError: Error {
    case pngEncodingFailed
}

struct ShareImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        // Simulator のプレビュー落ちを避けるため「ファイル」として渡す
        FileRepresentation(exportedContentType: .png) { item in
            let dir = FileManager.default.temporaryDirectory
            let url = dir.appendingPathComponent("MyDailyPhrase-\(UUID().uuidString).png")

            guard let data = item.image.pngData() else {
                throw ShareExportError.pngEncodingFailed
            }
            try data.write(to: url, options: [.atomic])

            return SentTransferredFile(url)
        }
    }
}

@MainActor
enum ShareCardRenderer {
    static func render(model: ShareCardModel, scale: CGFloat = 3.0) -> ShareImage? {
        // 9:16 を 360x640 * scale=3 → 1080x1920 相当
        let view = ShareCardView(model: model)
            .frame(width: 360, height: 640)
            .background(Color(.systemBackground))

        let renderer = ImageRenderer(content: view)
        renderer.scale = scale

        guard let uiImage = renderer.uiImage else { return nil }
        return ShareImage(image: uiImage)
    }
}
