import Foundation

public enum GachaViewLifecycleState: Equatable, Sendable {
    case idle
    case spinning
    case result
    case error
}

public enum GachaSkipOutcome: Equatable, Sendable {
    case ignored
    case closeReveal
    case hideSpinAndAwaitResult
}

public enum GachaRecoveryReason: String, Equatable, Sendable {
    case elapsedExceeded
    case noRunningDraw
    case timeoutTaskMissing
}

public struct GachaSpinSnapshot: Equatable, Sendable {
    public let elapsedInSpin: TimeInterval
    public let hasRunningDrawID: Bool
    public let hasDrawTask: Bool
    public let hasTimeoutTask: Bool

    public init(
        elapsedInSpin: TimeInterval,
        hasRunningDrawID: Bool,
        hasDrawTask: Bool,
        hasTimeoutTask: Bool
    ) {
        self.elapsedInSpin = elapsedInSpin
        self.hasRunningDrawID = hasRunningDrawID
        self.hasDrawTask = hasDrawTask
        self.hasTimeoutTask = hasTimeoutTask
    }
}

public enum GachaInteractionPolicy {
    public static func drawTapDecision(
        isBusy: Bool,
        now: Date,
        lockedUntil: Date?,
        minInterval: TimeInterval = 0.35
    ) -> (accepted: Bool, nextLockedUntil: Date?) {
        guard !isBusy else { return (false, lockedUntil) }
        if let lockedUntil, now < lockedUntil {
            return (false, lockedUntil)
        }
        return (true, now.addingTimeInterval(max(0.0, minInterval)))
    }

    public static func skipDecision(
        isRevealActive: Bool,
        state: GachaViewLifecycleState
    ) -> GachaSkipOutcome {
        if isRevealActive {
            return .closeReveal
        }
        if state == .spinning {
            return .hideSpinAndAwaitResult
        }
        return .ignored
    }

    public static func recoveryReason(for snapshot: GachaSpinSnapshot) -> GachaRecoveryReason? {
        if snapshot.elapsedInSpin > 7.0 {
            return .elapsedExceeded
        }
        if !snapshot.hasRunningDrawID && !snapshot.hasDrawTask && snapshot.elapsedInSpin > 1.2 {
            return .noRunningDraw
        }
        if snapshot.hasRunningDrawID && !snapshot.hasTimeoutTask && snapshot.elapsedInSpin > 2.5 {
            return .timeoutTaskMissing
        }
        return nil
    }
}
