import Foundation
import Combine

@MainActor
final class DecorationStore: ObservableObject {
    @Published private(set) var currentDecorationId: String

    init(currentDecorationId: String = "classic") {
        self.currentDecorationId = currentDecorationId
    }

    func set(_ id: String) {
        let norm = id.trimmingCharacters(in: .whitespacesAndNewlines)
        currentDecorationId = norm.isEmpty ? "classic" : norm
    }
}
