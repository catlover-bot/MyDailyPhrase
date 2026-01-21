import Foundation

public struct EnrichEntryUseCase: Sendable {
    private let service: TextEnrichmentService
    private let locale: Locale

    public init(service: TextEnrichmentService, locale: Locale = .current) {
        self.service = service
        self.locale = locale
    }

    public func execute(prompt: String, answer: String) -> ReflectionArtifact {
        service.enrich(prompt: prompt, answer: answer, locale: locale)
    }
}
