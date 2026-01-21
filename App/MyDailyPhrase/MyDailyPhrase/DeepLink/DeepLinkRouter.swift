import Foundation
import Combine
import Domain

@MainActor
final class DeepLinkRouter: ObservableObject {
    enum LastEvent {
        case challenge(ChallengeEvent)
        case reaction(ReactionEvent)
    }

    @Published private(set) var lastEvent: LastEvent? = nil
    @Published private(set) var lastErrorMessage: String? = nil

    private let receiveChallenge: ReceiveChallengeLinkUseCase
    private let receiveReaction: ReceiveReactionLinkUseCase

    init(
        receiveChallenge: ReceiveChallengeLinkUseCase,
        receiveReaction: ReceiveReactionLinkUseCase
    ) {
        self.receiveChallenge = receiveChallenge
        self.receiveReaction = receiveReaction
    }

    func handle(url: URL) {
        do {
            switch try DeepLinkCodec.parse(url) {
            case .challenge:
                let ev = try receiveChallenge(url: url)
                lastEvent = .challenge(ev)
                lastErrorMessage = nil

            case .react:
                let ev = try receiveReaction(url: url)
                lastEvent = .reaction(ev)
                lastErrorMessage = nil
            }
        } catch {
            lastErrorMessage = "リンクの解析に失敗しました: \(error.localizedDescription)"
        }
    }

    func clearError() {
        lastErrorMessage = nil
    }
}
