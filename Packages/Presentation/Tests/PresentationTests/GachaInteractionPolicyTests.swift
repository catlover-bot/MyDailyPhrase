import Foundation
import Testing
@testable import Presentation

@Suite("Gacha interaction policy")
struct GachaInteractionPolicyTests {

    @Test("連打時は一定時間2回目を受け付けない")
    func drawTapIsThrottled() {
        let now = Date(timeIntervalSince1970: 100)
        let first = GachaInteractionPolicy.drawTapDecision(
            isBusy: false,
            now: now,
            lockedUntil: nil
        )
        #expect(first.accepted == true)
        #expect(first.nextLockedUntil != nil)

        let second = GachaInteractionPolicy.drawTapDecision(
            isBusy: false,
            now: now.addingTimeInterval(0.10),
            lockedUntil: first.nextLockedUntil
        )
        #expect(second.accepted == false)

        let third = GachaInteractionPolicy.drawTapDecision(
            isBusy: false,
            now: now.addingTimeInterval(0.40),
            lockedUntil: first.nextLockedUntil
        )
        #expect(third.accepted == true)
    }

    @Test("スキップは状態に応じて結果が分岐する")
    func skipDecisionMatchesState() {
        let reveal = GachaInteractionPolicy.skipDecision(
            isRevealActive: true,
            state: .result
        )
        #expect(reveal == .closeReveal)

        let spinning = GachaInteractionPolicy.skipDecision(
            isRevealActive: false,
            state: .spinning
        )
        #expect(spinning == .hideSpinAndAwaitResult)

        let idle = GachaInteractionPolicy.skipDecision(
            isRevealActive: false,
            state: .idle
        )
        #expect(idle == .ignored)
    }

    @Test("失敗復帰判定はタイムアウトと整合性条件を監視する")
    func recoveryReasonRules() {
        let elapsed = GachaInteractionPolicy.recoveryReason(
            for: .init(
                elapsedInSpin: 7.1,
                hasRunningDrawID: true,
                hasDrawTask: true,
                hasTimeoutTask: true
            )
        )
        #expect(elapsed == .elapsedExceeded)

        let noRunning = GachaInteractionPolicy.recoveryReason(
            for: .init(
                elapsedInSpin: 1.3,
                hasRunningDrawID: false,
                hasDrawTask: false,
                hasTimeoutTask: true
            )
        )
        #expect(noRunning == .noRunningDraw)

        let timeoutMissing = GachaInteractionPolicy.recoveryReason(
            for: .init(
                elapsedInSpin: 2.6,
                hasRunningDrawID: true,
                hasDrawTask: true,
                hasTimeoutTask: false
            )
        )
        #expect(timeoutMissing == .timeoutTaskMissing)

        let stable = GachaInteractionPolicy.recoveryReason(
            for: .init(
                elapsedInSpin: 0.9,
                hasRunningDrawID: true,
                hasDrawTask: true,
                hasTimeoutTask: true
            )
        )
        #expect(stable == nil)
    }
}
