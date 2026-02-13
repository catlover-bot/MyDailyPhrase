import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum ShareExportError: Error {
    case pngEncodingFailed
}

struct ShareImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
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
    static func render(
        model: ShareCardModel,
        size: CGSize = CGSize(width: 360, height: 640),
        scale: CGFloat = 3.0,
        forceLightMode: Bool = true
    ) -> ShareImage? {

        // ベースは常に同じ修飾子を当てておく（分岐で片方だけ background 等を当てない）
        let baseView = ShareCardView(model: model)
            .frame(width: size.width, height: size.height)
            .background(Color(.systemBackground))

        // ✅ 型不一致回避：AnyView で型消去（ternary の罠を完全に避ける）
        let content: AnyView
        if forceLightMode {
            content = AnyView(baseView.environment(\.colorScheme, .light))
        } else {
            content = AnyView(baseView)
        }

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.isOpaque = true

        guard let uiImage = renderer.uiImage else { return nil }
        return ShareImage(image: uiImage)
    }
}
