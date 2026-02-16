import Foundation
import AuthenticationServices
import UIKit

@MainActor
protocol ExternalAuthTokenBroker: AnyObject {
    func canHandle(provider: ExternalAuthProvider) -> Bool
    func fetchToken(for provider: ExternalAuthProvider) async throws -> String
}

enum ExternalAuthTokenBrokerError: LocalizedError {
    case providerNotConfigured(provider: ExternalAuthProvider)
    case cancelled
    case sessionStartFailed
    case callbackMissingToken
    case callbackInvalid

    var errorDescription: String? {
        switch self {
        case .providerNotConfigured(let provider):
            return "\(provider.displayName) ログイン設定が未構成です"
        case .cancelled:
            return "ログインをキャンセルしました"
        case .sessionStartFailed:
            return "ログイン画面を開始できませんでした"
        case .callbackMissingToken:
            return "ログインコールバックにトークンが含まれていません"
        case .callbackInvalid:
            return "ログインコールバックが不正です"
        }
    }
}

@MainActor
final class OAuthWebAuthTokenBroker: NSObject, ExternalAuthTokenBroker {
    private let startURLs: [ExternalAuthProvider: URL]
    private let callbackScheme: String
    private var session: ASWebAuthenticationSession?

    init(startURLs: [ExternalAuthProvider: URL], callbackScheme: String) {
        self.startURLs = startURLs
        self.callbackScheme = callbackScheme
        super.init()
    }

    func canHandle(provider: ExternalAuthProvider) -> Bool {
        startURLs[provider] != nil
    }

    func fetchToken(for provider: ExternalAuthProvider) async throws -> String {
        guard let startURL = startURLs[provider] else {
            throw ExternalAuthTokenBrokerError.providerNotConfigured(provider: provider)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: startURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.session = nil

                if let error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: ExternalAuthTokenBrokerError.cancelled)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: ExternalAuthTokenBrokerError.callbackInvalid)
                    return
                }

                guard let token = Self.extractToken(from: callbackURL) else {
                    continuation.resume(throwing: ExternalAuthTokenBrokerError.callbackMissingToken)
                    return
                }

                continuation.resume(returning: token)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true

            guard session.start() else {
                continuation.resume(throwing: ExternalAuthTokenBrokerError.sessionStartFailed)
                return
            }

            self.session = session
        }
    }

    private static func extractToken(from callbackURL: URL) -> String? {
        if let token = token(in: callbackURL) {
            return token
        }

        // Some providers return fragment instead of query.
        guard let parts = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let fragment = parts.fragment,
              let fragmentParts = URLComponents(string: "https://callback.local/?\(fragment)") else {
            return nil
        }

        return token(in: fragmentParts)
    }

    private static func token(in callbackURL: URL) -> String? {
        guard let parts = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return token(in: parts)
    }

    private static func token(in parts: URLComponents) -> String? {
        let keys = ["provider_token", "id_token", "token", "access_token"]
        for key in keys {
            if let value = parts.queryItems?.first(where: { $0.name == key })?.value {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }
}

extension OAuthWebAuthTokenBroker: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes where scene.activationState == .foregroundActive {
            if let keyWindow = scene.windows.first(where: \.isKeyWindow) {
                return keyWindow
            }
            if let firstWindow = scene.windows.first {
                return firstWindow
            }
        }
        guard let fallbackScene = scenes.first else {
            preconditionFailure("No UIWindowScene available for ASWebAuthenticationSession")
        }
        return ASPresentationAnchor(windowScene: fallbackScene)
    }
}
