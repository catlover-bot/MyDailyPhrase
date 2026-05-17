import Foundation
import Domain

public enum CreatorFeatureAccessSource: String, Equatable, Sendable {
    case none
    case storeKit
    case userRole
    case adminBypass

    public var label: String {
        switch self {
        case .none:
            return "未解放"
        case .storeKit:
            return "Creator Pass"
        case .userRole:
            return "creator ロール"
        case .adminBypass:
            return "管理者権限で有効"
        }
    }
}

public struct FeatureAccessSnapshot: Equatable, Sendable {
    public static let signedOutDefault = FeatureAccessSnapshot(
        isAuthenticated: false,
        isGuest: false,
        storeKitCreatorPassActive: false,
        creatorFeatureSource: .none,
        canCreateCommunity: false,
        canCustomizePrompts: false,
        canUseCreatorTheme: false,
        canPreviewAllItems: false,
        canUseDMPrototype: false,
        canAccessAdminMenu: false,
        adminCapabilities: []
    )

    public let isAuthenticated: Bool
    public let isGuest: Bool
    public let storeKitCreatorPassActive: Bool
    public let creatorFeatureSource: CreatorFeatureAccessSource
    public let canCreateCommunity: Bool
    public let canCustomizePrompts: Bool
    public let canUseCreatorTheme: Bool
    public let canPreviewAllItems: Bool
    public let canUseDMPrototype: Bool
    public let canAccessAdminMenu: Bool
    public let adminCapabilities: [AdminCapability]

    public var isAdminBypassingCreatorFeatures: Bool {
        creatorFeatureSource == .adminBypass
    }

    public var adminStatusLabel: String? {
        canAccessAdminMenu ? "管理者権限で有効" : nil
    }
}

public enum FeatureAccessResolver {
    public static func resolve(
        session: AuthSession?,
        creatorPassEntitled: Bool
    ) -> FeatureAccessSnapshot {
        guard let session else {
            return .signedOutDefault
        }

        let adminCapabilities = Set(session.adminCapabilities)
        let isGuest = session.isGuest
        let isAdmin = session.roles.contains(.admin) || !adminCapabilities.isEmpty
        let hasCreatorRole = session.roles.contains(.creator)

        let creatorFeatureSource: CreatorFeatureAccessSource
        if isAdmin && adminCapabilities.contains(.bypassCreatorPassForAdmin) {
            creatorFeatureSource = .adminBypass
        } else if creatorPassEntitled {
            creatorFeatureSource = .storeKit
        } else if hasCreatorRole {
            creatorFeatureSource = .userRole
        } else {
            creatorFeatureSource = .none
        }

        let creatorFeaturesEnabled = !isGuest && creatorFeatureSource != .none
        let diagnosticsEnabled = !isGuest && (isAdmin || adminCapabilities.contains(.viewDiagnostics))

        return FeatureAccessSnapshot(
            isAuthenticated: true,
            isGuest: isGuest,
            storeKitCreatorPassActive: creatorPassEntitled,
            creatorFeatureSource: creatorFeatureSource,
            canCreateCommunity: creatorFeaturesEnabled,
            canCustomizePrompts: creatorFeaturesEnabled,
            canUseCreatorTheme: creatorFeaturesEnabled,
            canPreviewAllItems: !isGuest && (isAdmin || adminCapabilities.contains(.previewAllItems)),
            canUseDMPrototype: !isGuest,
            canAccessAdminMenu: diagnosticsEnabled || adminCapabilities.contains(.accessAllFeatures),
            adminCapabilities: Array(adminCapabilities).sorted { $0.rawValue < $1.rawValue }
        )
    }
}
