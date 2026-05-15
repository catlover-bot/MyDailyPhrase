import SwiftUI

enum AppChrome {
    static let screenHorizontalPadding: CGFloat = 16
    static let pageSectionSpacing: CGFloat = 14
    static let bottomTabBarReservedSpace: CGFloat = 110
    static let bottomFloatingBannerReservedSpace: CGFloat = 72
    static let bottomTabBarItemMinHeight: CGFloat = 52
}

struct AppScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(uiColor: .systemBackground),
                Color(red: 0.14, green: 0.16, blue: 0.19),
                Color(red: 0.10, green: 0.12, blue: 0.15)
            ]
        }

        return [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.97, green: 0.95, blue: 0.90),
            Color(red: 0.94, green: 0.97, blue: 0.99)
        ]
    }
}

struct PageHeroCard<Content: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String
    var accent: Color = .accentColor
    @ViewBuilder let content: Content

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String,
        accent: Color = .accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.regularMaterial)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.18),
                                accent.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 12)
    }
}

struct AppSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 10)
    }
}

struct SummaryMetricTile: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }
}

struct InfoBadge: View {
    let title: String
    let systemImage: String
    var tint: Color = .blue

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct PremiumBadge: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "crown.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.orange.opacity(0.14), in: Capsule())
    }
}

struct AppBottomTabBarItem<ID: Hashable> {
    let id: ID
    let title: String
    let systemImage: String
    let selectedSystemImage: String
}

struct AppBottomTabBar<ID: Hashable>: View {
    let items: [AppBottomTabBarItem<ID>]
    @Binding var selection: ID
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let isSelected = selection == item.id

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selection = item.id
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: isSelected ? item.selectedSystemImage : item.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .symbolVariant(isSelected ? .fill : .none)

                        Text(item.title)
                            .font(.caption2.weight(isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AppChrome.bottomTabBarItemMinHeight)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.accentColor.opacity(0.16))
                                .matchedGeometryEffect(id: "activeTabBackground", in: selectionNamespace)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct EquippedItemBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.16), in: Capsule())
    }
}
