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
