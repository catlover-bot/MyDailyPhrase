import Foundation
import Testing
@testable import Data

@Suite("LocalPromptRepository")
struct LocalPromptRepositoryTests {
    @Test("contains at least 100 prompts")
    func hasAtLeast100Prompts() {
        let repo = LocalPromptRepository()
        #expect(repo.promptCount >= 100)
    }

    @Test("same day returns the same prompt")
    func promptIsStableForSameDate() {
        let repo = LocalPromptRepository()

        let first = repo.prompt(for: "20260429")
        let second = repo.prompt(for: "20260429")

        #expect(first == second)
    }

    @Test("different days produce varied prompts across a sample")
    func promptsVaryAcrossDays() {
        let repo = LocalPromptRepository()

        let uniquePrompts = Set((1...30).map { day in
            repo.prompt(for: String(format: "202605%02d", day)).text
        })

        #expect(uniquePrompts.count > 10)
    }
}
