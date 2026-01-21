import Foundation
import Combine
import Domain

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var userId: String = ""
    @Published var displayName: String = ""

    private let get: GetMyProfileUseCase
    private let update: UpdateMyProfileUseCase

    init(get: GetMyProfileUseCase, update: UpdateMyProfileUseCase) {
        self.get = get
        self.update = update
    }

    func load() {
        let p = get()
        userId = p.userId
        displayName = p.displayName
    }

    func save() {
        let p = update(displayName: displayName)
        userId = p.userId
        displayName = p.displayName
    }
}
