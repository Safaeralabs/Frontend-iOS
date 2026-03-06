import SwiftUI

struct FriendZoneShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum FriendZoneTokens {
    enum Colors {
        static let background = Color(hex: "#FAF9F5")
        static let surface = Color(hex: "#FFFFFF")
        static let surfaceElevated = Color(hex: "#FFFFFF")
        static let surfaceMuted = Color(hex: "#F9FAFB")

        static let primary = Color(hex: "#6527FC")
        static let primaryHover = Color(hex: "#5520D9")
        static let primaryAccent = Color(hex: "#8B5CF6")
        static let primarySoft = Color(hex: "#6527FC").opacity(0.10)
        static let primarySoftBorder = Color(hex: "#6527FC").opacity(0.20)

        static let textPrimary = Color(hex: "#0F0F0F")
        static let textSecondary = Color(hex: "#666666")
        static let textTertiary = Color(hex: "#999999")
        static let textInverse = Color(hex: "#FFFFFF")

        static let borderSubtle = Color.black.opacity(0.06)
        static let borderDefault = Color.black.opacity(0.10)
        static let borderStrong = Color.black.opacity(0.15)

        static let error = Color(hex: "#FF3B30")
        static let errorStrong = Color(hex: "#DC2626")
        static let success = Color(hex: "#34C759")
        static let successStrong = Color(hex: "#059669")
        static let successEmphasis = Color(hex: "#10B981")
        static let warning = Color(hex: "#FF9500")
        static let warningStrong = Color(hex: "#F59E0B")
        static let warningSoft = Color(hex: "#FEF3C7")
        static let warningGold = Color(hex: "#FFD700")
        static let warningAmber = Color(hex: "#FFA500")
        static let surfaceNight = Color(hex: "#1A1A2E")
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let x2l: CGFloat = 48
    }

    enum Radius {
        static let x2s: CGFloat = 2
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let x2l: CGFloat = 24
        static let pill: CGFloat = 9999
    }

    enum BorderWidth {
        static let thin: CGFloat = 1
        static let md: CGFloat = 1.5
        static let thick: CGFloat = 2
        static let strong: CGFloat = 3
    }

    enum Typography {
        static let size2XS: CGFloat = 10
        static let sizeXS: CGFloat = 12
        static let sizeSM: CGFloat = 14
        static let sizeBase: CGFloat = 16
        static let sizeLG: CGFloat = 18
        static let sizeXL: CGFloat = 24
        static let size2XL: CGFloat = 32

        static let lineHeightTight: CGFloat = 1.2
        static let lineHeightNormal: CGFloat = 1.5
        static let lineHeightRelaxed: CGFloat = 1.75

        static func system(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        static func displaySerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }
    }

    enum Shadows {
        static let sm = FriendZoneShadowToken(
            color: Color.black.opacity(0.04),
            radius: 2,
            x: 0,
            y: 1
        )

        static let md = FriendZoneShadowToken(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )

        static let lg = FriendZoneShadowToken(
            color: Color.black.opacity(0.12),
            radius: 16,
            x: 0,
            y: 4
        )
    }

    enum Motion {
        static let fastDuration: Double = 0.15
        static let baseDuration: Double = 0.20
        static let slowDuration: Double = 0.30

        static let easeOutExpo = Animation.timingCurve(0.19, 1.0, 0.22, 1.0, duration: baseDuration)
        static let easeOutBack = Animation.timingCurve(0.34, 1.56, 0.64, 1.0, duration: baseDuration)
        static let easeInOutCirc = Animation.timingCurve(0.85, 0.0, 0.15, 1.0, duration: baseDuration)
    }

    enum ZIndex {
        static let base: Double = 0
        static let dropdown: Double = 100
        static let sticky: Double = 200
        static let fixed: Double = 300
        static let modal: Double = 400
        static let toast: Double = 500
    }
}

extension View {
    func friendZoneShadow(_ token: FriendZoneShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
