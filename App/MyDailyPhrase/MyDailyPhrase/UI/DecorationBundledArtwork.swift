import SwiftUI
import UIKit
import Domain

struct DecorationBundledArtwork {
    let item: DecorationItem
    let artwork: UIImage?
    let thumbnail: UIImage?
    let background: UIImage?
    let frame: UIImage?

    var hasAnyAsset: Bool {
        artwork != nil || thumbnail != nil || background != nil || frame != nil
    }
}

enum DecorationBundledArtworkCatalog {
    static func item(for decorationId: String?) -> DecorationItem? {
        guard let normalized = normalizedDecorationId(decorationId) else {
            return nil
        }
        return CardDecorationCatalog.item(for: normalized)
    }

    static func artwork(for decorationId: String?) -> DecorationBundledArtwork? {
        guard let item = item(for: decorationId) else {
            return nil
        }

        let result = DecorationBundledArtwork(
            item: item,
            artwork: image(named: item.assetName),
            thumbnail: image(named: item.thumbnailAssetName),
            background: image(named: item.backgroundAssetName),
            frame: image(named: item.frameAssetName)
        )

        return result.hasAnyAsset ? result : nil
    }

    static func hasBundledArtwork(for decorationId: String?) -> Bool {
        artwork(for: decorationId) != nil
    }

    private static func normalizedDecorationId(_ decorationId: String?) -> String? {
        guard let decorationId = decorationId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !decorationId.isEmpty else {
            return nil
        }
        return decorationId.lowercased()
    }

    private static func image(named name: String?) -> UIImage? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return UIImage(named: trimmed)
    }
}

struct DecorationBundledArtworkLayer: View {
    let decorationId: String
    var prefersThumbnail: Bool = false
    var imageInset: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            if let artwork = DecorationBundledArtworkCatalog.artwork(for: decorationId) {
                let compact = prefersThumbnail || min(proxy.size.width, proxy.size.height) <= 180

                ZStack {
                    if let backgroundImage = preferredBackgroundImage(from: artwork, compact: compact) {
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }

                    if let focalImage = preferredFocalImage(from: artwork, compact: compact) {
                        Image(uiImage: focalImage)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                maxWidth: max(0, proxy.size.width - imageInset * 2),
                                maxHeight: max(0, proxy.size.height - imageInset * 2)
                            )
                            .padding(imageInset)
                    }

                    if let frameImage = artwork.frame {
                        Image(uiImage: frameImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private func preferredBackgroundImage(
        from artwork: DecorationBundledArtwork,
        compact: Bool
    ) -> UIImage? {
        if let background = artwork.background {
            return background
        }
        if compact {
            return nil
        }
        return artwork.artwork ?? artwork.thumbnail
    }

    private func preferredFocalImage(
        from artwork: DecorationBundledArtwork,
        compact: Bool
    ) -> UIImage? {
        if compact {
            return artwork.thumbnail ?? artwork.artwork
        }
        return artwork.artwork ?? artwork.thumbnail
    }
}
