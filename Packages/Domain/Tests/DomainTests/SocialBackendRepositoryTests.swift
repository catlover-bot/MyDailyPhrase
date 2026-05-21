import Foundation
import Testing
@testable import Domain

@Suite("Social backend repository contracts")
struct SocialBackendRepositoryTests {
    @Test("social report normalizes note and identifiers")
    func socialReportNormalizes() {
        var report = SocialReport(
            id: "  ",
            reporterUserID: " reporter ",
            targetKind: .user,
            targetID: " target ",
            reason: .harassment,
            note: String(repeating: "x", count: 400)
        )

        report.normalize()

        #expect(!report.id.isEmpty)
        #expect(report.reporterUserID == "reporter")
        #expect(report.targetID == "target")
        #expect((report.note ?? "").count == 280)
    }

    @Test("backend repository modes are explicit")
    func backendModesAreExplicit() {
        #expect(SocialBackendMode.localFallback.rawValue == "localFallback")
        #expect(SocialBackendMode.supabase.rawValue == "supabase")
    }
}
