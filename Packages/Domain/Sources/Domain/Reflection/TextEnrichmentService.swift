import Foundation

public protocol TextEnrichmentService: Sendable {
    func enrich(prompt: String, answer: String, locale: Locale) -> ReflectionArtifact
}
