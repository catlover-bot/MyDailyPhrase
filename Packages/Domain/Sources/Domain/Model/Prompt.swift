// Packages/Domain/Sources/Model/Prompt.swift
import Foundation

public struct Prompt: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}
