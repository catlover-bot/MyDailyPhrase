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
    enum Treatment {
        case readableCard
        case softBackground
        case compactAccent
    }

    let decorationId: String
    var prefersThumbnail: Bool = false
    var imageInset: CGFloat = 14
    var treatment: Treatment = .readableCard

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
                            .opacity(backgroundOpacity)
                            .blur(radius: backgroundBlurRadius)
                    }

                    if let focalImage = preferredFocalImage(from: artwork, compact: compact) {
                        Image(uiImage: focalImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: focalFrameWidth(in: proxy.size), height: focalFrameHeight(in: proxy.size))
                            .padding(imageInset)
                            .opacity(focalOpacity)
                            .frame(
                                width: proxy.size.width,
                                height: proxy.size.height,
                                alignment: focalAlignment
                            )
                    }

                    if let frameImage = artwork.frame {
                        Image(uiImage: frameImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .opacity(frameOpacity)
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
        switch treatment {
        case .compactAccent:
            return nil
        case .readableCard, .softBackground:
            return artwork.background ?? artwork.artwork ?? artwork.thumbnail
        }
    }

    private func preferredFocalImage(
        from artwork: DecorationBundledArtwork,
        compact: Bool
    ) -> UIImage? {
        switch treatment {
        case .compactAccent:
            return artwork.thumbnail ?? artwork.artwork
        case .readableCard:
            return compact ? (artwork.thumbnail ?? artwork.artwork) : (artwork.thumbnail ?? artwork.artwork)
        case .softBackground:
            return compact ? (artwork.thumbnail ?? artwork.artwork) : (artwork.thumbnail ?? artwork.artwork)
        }
    }

    private var backgroundOpacity: Double {
        switch treatment {
        case .readableCard:
            return 0.05
        case .softBackground:
            return 0.08
        case .compactAccent:
            return 0
        }
    }

    private var backgroundBlurRadius: CGFloat {
        switch treatment {
        case .readableCard:
            return 2.0
        case .softBackground:
            return 1.4
        case .compactAccent:
            return 0
        }
    }

    private var focalOpacity: Double {
        switch treatment {
        case .readableCard:
            return 0.18
        case .softBackground:
            return 0.22
        case .compactAccent:
            return 0.92
        }
    }

    private var frameOpacity: Double {
        switch treatment {
        case .readableCard:
            return 0.18
        case .softBackground:
            return 0.24
        case .compactAccent:
            return 0.24
        }
    }

    private var focalAlignment: Alignment {
        switch treatment {
        case .readableCard, .softBackground:
            return .bottomTrailing
        case .compactAccent:
            return .topTrailing
        }
    }

    private func focalFrameWidth(in size: CGSize) -> CGFloat {
        switch treatment {
        case .readableCard:
            return min(size.width * 0.22, 72)
        case .softBackground:
            return min(size.width * 0.28, 88)
        case .compactAccent:
            return min(size.width * 0.22, 64)
        }
    }

    private func focalFrameHeight(in size: CGSize) -> CGFloat {
        switch treatment {
        case .readableCard:
            return min(size.height * 0.34, 72)
        case .softBackground:
            return min(size.height * 0.42, 96)
        case .compactAccent:
            return min(size.height * 0.28, 72)
        }
    }
}
