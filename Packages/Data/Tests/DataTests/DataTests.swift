import Foundation
import Testing
import Domain
@testable import Data

@Suite("AppGroupUserProfileRepository")
struct AppGroupUserProfileRepositoryTests {
    private let primaryKey = "MyDailyPhrase.profile.v1"
    private let backupKey = "MyDailyPhrase.profile.backup.v1"
    private let corruptKey = "MyDailyPhrase.profile.corrupt.v1"
    private let recoveryKey = "MyDailyPhrase.profile.recoveredAt.v1"

    @Test("primary破損時はbackupから復旧する")
    func recoversFromBackupWhenPrimaryCorrupt() throws {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("suiteNameが作成できませんでした: \(suite)")
            return
        }

        let repo = AppGroupUserProfileRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        let base = UserProfile(
            userId: "u-recovery",
            displayName: "tester",
            selectedDecorationId: "paper",
            ownedDecorationCounts: [
                CardDecorationCatalog.classicId: 1,
                "paper": 1
            ],
            gachaTickets: 5
        )

        repo.saveMyProfile(base)
        let backupData = defaults.data(forKey: backupKey)
        #expect(backupData != nil)

        defaults.set(Data([0xFF, 0x00, 0xAA]), forKey: primaryKey)

        let recovered = repo.getMyProfile()
        #expect(recovered?.userId == base.userId)
        #expect(recovered?.selectedDecorationId == base.selectedDecorationId)
        #expect(recovered?.gachaTickets == base.gachaTickets)

        let restoredPrimary = defaults.data(forKey: primaryKey)
        #expect(restoredPrimary == backupData)
        #expect(defaults.data(forKey: corruptKey) != nil)
        #expect(defaults.double(forKey: recoveryKey) > 0)
    }

    @Test("正常保存時はcorruptマーカーをクリアする")
    func saveClearsCorruptMarker() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("suiteNameが作成できませんでした: \(suite)")
            return
        }

        let repo = AppGroupUserProfileRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        defaults.set(Data([0x10, 0x20]), forKey: corruptKey)

        repo.saveMyProfile(
            UserProfile(
                userId: "u-clean",
                displayName: "tester",
                selectedDecorationId: CardDecorationCatalog.classicId,
                ownedDecorationCounts: [CardDecorationCatalog.classicId: 1]
            )
        )

        #expect(defaults.data(forKey: corruptKey) == nil)
        #expect(defaults.data(forKey: primaryKey) != nil)
        #expect(defaults.data(forKey: backupKey) != nil)
    }

    @Test("保存データが無い場合はnilを返す")
    func returnsNilWhenNoProfileData() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupUserProfileRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        #expect(repo.getMyProfile() == nil)
    }

    private func makeSuiteName() -> String {
        "group.MyDailyPhrase.tests.\(UUID().uuidString)"
    }

    private func cleanupSuite(_ suite: String) {
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}
