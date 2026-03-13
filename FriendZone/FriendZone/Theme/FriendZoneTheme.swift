import SwiftUI

enum FriendZoneTheme {
    static let background = FriendZoneTokens.Colors.background
    static let surface = FriendZoneTokens.Colors.surface
    static let primary = FriendZoneTokens.Colors.primary
    static let primaryAccent = FriendZoneTokens.Colors.primaryAccent
    static let textPrimary = FriendZoneTokens.Colors.textPrimary
    static let textSecondary = FriendZoneTokens.Colors.textSecondary
    static let borderSubtle = FriendZoneTokens.Colors.borderSubtle

    enum Colors {
        static let background = FriendZoneTokens.Colors.background
        static let surface = FriendZoneTokens.Colors.surface
        static let surfaceElevated = FriendZoneTokens.Colors.surfaceElevated
        static let surfaceMuted = FriendZoneTokens.Colors.surfaceMuted

        static let primary = FriendZoneTokens.Colors.primary
        static let primaryHover = FriendZoneTokens.Colors.primaryHover
        static let primaryAccent = FriendZoneTokens.Colors.primaryAccent
        static let primarySoft = FriendZoneTokens.Colors.primarySoft
        static let primarySoftBorder = FriendZoneTokens.Colors.primarySoftBorder

        static let textPrimary = FriendZoneTokens.Colors.textPrimary
        static let textSecondary = FriendZoneTokens.Colors.textSecondary
        static let textTertiary = FriendZoneTokens.Colors.textTertiary
        static let textInverse = FriendZoneTokens.Colors.textInverse

        static let borderSubtle = FriendZoneTokens.Colors.borderSubtle
        static let borderDefault = FriendZoneTokens.Colors.borderDefault
        static let borderStrong = FriendZoneTokens.Colors.borderStrong

        static let error = FriendZoneTokens.Colors.error
        static let success = FriendZoneTokens.Colors.success
        static let warning = FriendZoneTokens.Colors.warning
        static let surfaceNight = FriendZoneTokens.Colors.surfaceNight
    }

    enum Spacing {
        static let xs = FriendZoneTokens.Spacing.xs
        static let sm = FriendZoneTokens.Spacing.sm
        static let md = FriendZoneTokens.Spacing.md
        static let lg = FriendZoneTokens.Spacing.lg
        static let xl = FriendZoneTokens.Spacing.xl
        static let x2l = FriendZoneTokens.Spacing.x2l
    }

    enum Radius {
        static let x2s = FriendZoneTokens.Radius.x2s
        static let xs = FriendZoneTokens.Radius.xs
        static let sm = FriendZoneTokens.Radius.sm
        static let md = FriendZoneTokens.Radius.md
        static let lg = FriendZoneTokens.Radius.lg
        static let xl = FriendZoneTokens.Radius.xl
        static let x2l = FriendZoneTokens.Radius.x2l
        static let pill = FriendZoneTokens.Radius.pill
    }

    enum BorderWidth {
        static let thin = FriendZoneTokens.BorderWidth.thin
        static let md = FriendZoneTokens.BorderWidth.md
        static let thick = FriendZoneTokens.BorderWidth.thick
        static let strong = FriendZoneTokens.BorderWidth.strong
    }

    enum Shadows {
        static let sm = FriendZoneTokens.Shadows.sm
        static let md = FriendZoneTokens.Shadows.md
        static let lg = FriendZoneTokens.Shadows.lg
    }

    enum Chrome {
        static let horizontalInset: CGFloat = 16
        static let topOffset: CGFloat = 10
        static let sectionGap: CGFloat = 8
        static let moduleHeaderContentTop: CGFloat = 10
    }

    enum Typography {
        static let size2XS = FriendZoneTokens.Typography.size2XS
        static let sizeXS = FriendZoneTokens.Typography.sizeXS
        static let sizeSM = FriendZoneTokens.Typography.sizeSM
        static let sizeBase = FriendZoneTokens.Typography.sizeBase
        static let sizeLG = FriendZoneTokens.Typography.sizeLG
        static let sizeXL = FriendZoneTokens.Typography.sizeXL
        static let size2XL = FriendZoneTokens.Typography.size2XL

        static func system(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            FriendZoneTokens.Typography.system(size, weight: weight)
        }

        static func displaySerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            FriendZoneTokens.Typography.displaySerif(size, weight: weight)
        }
    }

    enum Motion {
        static let fastDuration = FriendZoneTokens.Motion.fastDuration
        static let baseDuration = FriendZoneTokens.Motion.baseDuration
        static let slowDuration = FriendZoneTokens.Motion.slowDuration

        static let easeOutExpo = FriendZoneTokens.Motion.easeOutExpo
        static let easeOutBack = FriendZoneTokens.Motion.easeOutBack
        static let easeInOutCirc = FriendZoneTokens.Motion.easeInOutCirc
    }
}

struct FriendZoneModuleHeader<Trailing: View>: View {
    let leadingText: String
    let highlightText: String
    let subtitle: String?
    let topInset: CGFloat
    let horizontalPadding: CGFloat
    let trailing: Trailing

    init(
        leadingText: String,
        highlightText: String,
        subtitle: String? = nil,
        topInset: CGFloat = 0,
        horizontalPadding: CGFloat = FriendZoneTheme.Chrome.horizontalInset,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leadingText = leadingText
        self.highlightText = highlightText
        self.subtitle = subtitle
        self.topInset = topInset
        self.horizontalPadding = horizontalPadding
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                (
                    Text(leadingText)
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    + Text(highlightText)
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                )
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XL, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                trailing
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topInset + FriendZoneTheme.Chrome.moduleHeaderContentTop)
        .padding(.bottom, 14)
        .background(FriendZoneTheme.Colors.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.x2l, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.x2l, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }
}

extension FriendZoneModuleHeader where Trailing == EmptyView {
    init(
        leadingText: String,
        highlightText: String,
        subtitle: String? = nil,
        topInset: CGFloat = 0,
        horizontalPadding: CGFloat = FriendZoneTheme.Chrome.horizontalInset
    ) {
        self.init(
            leadingText: leadingText,
            highlightText: highlightText,
            subtitle: subtitle,
            topInset: topInset,
            horizontalPadding: horizontalPadding
        ) {
            EmptyView()
        }
    }
}

struct FriendZoneLogoMark: View {
    var size: CGFloat = 20
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.86))
            .frame(width: size, height: size)
            .overlay {
                Image("FriendZoneLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.74, height: size * 0.74)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
    }
}

struct FriendZoneBrandPill: View {
    var textColor: Color = FriendZoneTheme.Colors.textPrimary

    var body: some View {
        HStack(spacing: 10) {
            FriendZoneLogoMark(size: 20, cornerRadius: 6)
            Text("FriendZone")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.white.opacity(0.80))
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}
