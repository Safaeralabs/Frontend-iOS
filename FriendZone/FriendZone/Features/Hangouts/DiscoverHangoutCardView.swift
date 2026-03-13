import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct DiscoverHangoutCardView: View {
    let hangout: HangoutItem
    private let footer: AnyView?
    @State private var coverArtwork: UIImage?
    @State private var coverAccent: UIColor?

    private var basePalette: DiscoverHangoutPalette {
        discoverPalette(for: hangout.vibe)
    }

    private var palette: DiscoverHangoutPalette {
        guard let coverAccent else { return basePalette }
        return discoverPhotoPalette(from: coverAccent, fallback: basePalette)
    }

    init(hangout: HangoutItem) {
        self.hangout = hangout
        footer = nil
    }

    init<Footer: View>(hangout: HangoutItem, @ViewBuilder footer: () -> Footer) {
        self.hangout = hangout
        self.footer = AnyView(footer())
    }

    var body: some View {
        VStack(spacing: 12) {
            headerContent

            if let footer {
                footer
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.footerPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(palette.border.opacity(0.92), lineWidth: 1)
                    }
            }
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.border, lineWidth: 1.2)
        }
        .shadow(color: Color.black.opacity(0.09), radius: 16, x: 0, y: 10)
        .overlay {
            GeometryReader { proxy in
                let radius: CGFloat = 8
                let y = proxy.size.height * 0.5

                ZStack {
                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(x: 0, y: y)

                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(x: proxy.size.width, y: y)
                }
            }
        }
        .task(id: coverArtworkSourceKey) {
            await resolveCoverArtwork()
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if let coverArtwork {
            coverPhotoBackground(coverArtwork)
        } else {
            wallpaperBackground
        }
    }

    private var wallpaperBackground: some View {
        ZStack {
            LinearGradient(
                colors: [palette.wallpaperTop, palette.wallpaperBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accent.opacity(0.18))
                .frame(width: 188, height: 188)
                .blur(radius: 26)
                .offset(x: 106, y: -46)

            Circle()
                .fill(palette.panel.opacity(0.38))
                .frame(width: 152, height: 152)
                .blur(radius: 18)
                .offset(x: -84, y: 72)

            discoverEmojiPattern(
                emoji: discoverVibeEmoji(for: hangout.vibe),
                tint: palette.emojiTint,
                isExtended: footer != nil
            )
        }
    }

    private func coverPhotoBackground(_ artwork: UIImage) -> some View {
        ZStack {
            Image(uiImage: artwork)
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [
                    palette.wallpaperTop.opacity(0.34),
                    palette.wallpaperBottom.opacity(0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.36),
                    Color.black.opacity(0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    palette.accent.opacity(0.16),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 18,
                endRadius: 220
            )
        }
        .clipped()
    }

    private var headerContent: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("HANGOUT")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(palette.tertiaryInk)
                        .tracking(0.8)

                    Spacer()

                    if let sourceTag = discoverSourceTag(for: hangout.sourceType) {
                        labelChip(
                            text: sourceTag.title,
                            foreground: sourceTag.ink,
                            background: sourceTag.fill
                        )
                    }

                    labelChip(
                        text: "\(discoverVibeEmoji(for: hangout.vibe)) \(hangout.vibe.title)",
                        foreground: palette.accent,
                        background: palette.badgeFill
                    )
                }

                Text(hangout.title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                    .foregroundColor(palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 6) {
                    metadataLine(
                        icon: hangout.hasUnlockedLocation ? "📍" : "🔒",
                        text: hangout.publicLocationDisplay
                    )

                    metadataLine(
                        icon: hangout.hostName.lowercased() == "you" ? "👑" : "🎯",
                        text: "Hosted by \(hangout.hostName)"
                    )
                }

                HStack(spacing: 8) {
                    labelChip(
                        text: hangout.hasUnlimitedCapacity
                            ? "👥 Open spots"
                            : (hangout.isFull ? "⛔ Full" : "👥 \(hangout.spotsLeft) spots left"),
                        foreground: hangout.isFull ? Color(hex: "#7F1D1D") : palette.accent,
                        background: hangout.isFull ? Color(hex: "#F5D6D8") : palette.badgeFill
                    )

                    if let locationHint = hangout.publicLocationHint {
                        Text(locationHint)
                            .font(FriendZoneTheme.Typography.system(10, weight: .medium))
                            .foregroundColor(palette.tertiaryInk)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(palette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.border.opacity(0.9), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                ForEach(0 ..< 14, id: \.self) { _ in
                    Circle()
                        .fill(palette.perforation)
                        .frame(width: 2.4, height: 2.4)
                }
            }
            .frame(width: 3)
            .padding(.horizontal, 2)

            VStack(spacing: 6) {
                Text(discoverDayLabel(hangout.startAt))
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(palette.dateInk.opacity(0.78))
                    .tracking(0.7)

                Text(discoverDateNumber(hangout.startAt))
                    .font(FriendZoneTheme.Typography.system(25, weight: .heavy))
                    .foregroundColor(palette.dateInk)

                Text(discoverTimeLabel(hangout.startAt))
                    .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                    .foregroundColor(palette.dateInk.opacity(0.88))
                    .multilineTextAlignment(.center)

                Text(timeRemainingText(from: Date(), to: hangout.startAt) ?? "SOON")
                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                    .foregroundColor(palette.dateInk)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(palette.dateCapsule)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [palette.datePanelTop, palette.datePanelBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.border.opacity(0.95), lineWidth: 1)
            }
            .frame(width: 78)
        }
    }

    private var coverArtworkSourceKey: String {
        if let data = hangout.coverImageData, !data.isEmpty {
            return "data-\(hangout.id)-\(data.count)"
        }
        if let url = normalizedCoverURL?.absoluteString {
            return "url-\(url)"
        }
        return "none-\(hangout.id)"
    }

    private var normalizedCoverURL: URL? {
        guard let rawValue = hangout.coverImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }
        if let url = URL(string: rawValue), url.scheme != nil {
            return url
        }
        return AppConfig.url(for: rawValue)
    }

    private func resolveCoverArtwork() async {
        if let data = hangout.coverImageData,
           !data.isEmpty {
            await applyResolvedCoverData(data)
            return
        }

        guard let url = normalizedCoverURL else {
            await clearResolvedCover()
            return
        }

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 18)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }
            await applyResolvedCoverData(data)
        } catch {
            await clearResolvedCover()
        }
    }

    @MainActor
    private func applyResolvedCoverData(_ data: Data?) {
        let image = data.flatMap(UIImage.init(data:))
        coverArtwork = image
        coverAccent = image.flatMap(discoverAverageUIColor(from:))
    }

    @MainActor
    private func clearResolvedCover() {
        coverArtwork = nil
        coverAccent = nil
    }

    private func metadataLine(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 11))

            Text(text)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(palette.mutedInk)
                .lineLimit(1)
        }
    }

    private func labelChip(text: String, foreground: Color, background: Color) -> some View {
        Text(text.uppercased())
            .font(FriendZoneTheme.Typography.system(9, weight: .bold))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(background)
            .clipShape(Capsule())
    }

    private func timeRemainingText(from now: Date, to date: Date) -> String? {
        let diff = Int(date.timeIntervalSince(now))
        if diff <= 0 { return nil }
        let minutes = diff / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

private struct DiscoverHangoutPalette {
    let wallpaperTop: Color
    let wallpaperBottom: Color
    let panel: Color
    let footerPanel: Color
    let ink: Color
    let mutedInk: Color
    let tertiaryInk: Color
    let accent: Color
    let badgeFill: Color
    let border: Color
    let perforation: Color
    let emojiTint: Color
    let datePanelTop: Color
    let datePanelBottom: Color
    let dateInk: Color
    let dateCapsule: Color
}

private struct DiscoverSourceTagStyle {
    let title: String
    let fill: Color
    let ink: Color
}

private let discoverAverageColorContext = CIContext(options: [.workingColorSpace: NSNull()])

private func discoverPalette(for vibe: HangoutVibe) -> DiscoverHangoutPalette {
    switch vibe {
    case .chill:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#DBE5FA"),
            wallpaperBottom: Color(hex: "#C4D2F2"),
            panel: Color(hex: "#F8FAFF"),
            footerPanel: Color(hex: "#F2F6FF"),
            ink: Color(hex: "#1A2440"),
            mutedInk: Color(hex: "#4D5C79"),
            tertiaryInk: Color(hex: "#7080A0"),
            accent: Color(hex: "#5B70D6"),
            badgeFill: Color(hex: "#E7EEFF"),
            border: Color(hex: "#A8B7DD"),
            perforation: Color(hex: "#98A8CF"),
            emojiTint: Color(hex: "#7F94E6"),
            datePanelTop: Color(hex: "#5B70D6"),
            datePanelBottom: Color(hex: "#4E63C4"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .drinks:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#F0DCC8"),
            wallpaperBottom: Color(hex: "#DBB48E"),
            panel: Color(hex: "#FFF8F1"),
            footerPanel: Color(hex: "#FBF0E2"),
            ink: Color(hex: "#442515"),
            mutedInk: Color(hex: "#6E4831"),
            tertiaryInk: Color(hex: "#916A50"),
            accent: Color(hex: "#B9652A"),
            badgeFill: Color(hex: "#F8E7D7"),
            border: Color(hex: "#C79D79"),
            perforation: Color(hex: "#B68A65"),
            emojiTint: Color(hex: "#C27A45"),
            datePanelTop: Color(hex: "#A95924"),
            datePanelBottom: Color(hex: "#8F491C"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .deepTalk:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#E3DAF2"),
            wallpaperBottom: Color(hex: "#C9B7E8"),
            panel: Color(hex: "#FBF9FF"),
            footerPanel: Color(hex: "#F5F0FC"),
            ink: Color(hex: "#2F1E49"),
            mutedInk: Color(hex: "#594078"),
            tertiaryInk: Color(hex: "#7E69A1"),
            accent: Color(hex: "#7A58BB"),
            badgeFill: Color(hex: "#EEE7FB"),
            border: Color(hex: "#B59FD9"),
            perforation: Color(hex: "#A88CCC"),
            emojiTint: Color(hex: "#8E71C8"),
            datePanelTop: Color(hex: "#7350B1"),
            datePanelBottom: Color(hex: "#5E409A"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .activity:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#D7E7CC"),
            wallpaperBottom: Color(hex: "#BCD1AF"),
            panel: Color(hex: "#F5FAF1"),
            footerPanel: Color(hex: "#EEF6E7"),
            ink: Color(hex: "#213524"),
            mutedInk: Color(hex: "#4B6650"),
            tertiaryInk: Color(hex: "#718A74"),
            accent: Color(hex: "#4E8753"),
            badgeFill: Color(hex: "#E2F0E0"),
            border: Color(hex: "#9EBD9E"),
            perforation: Color(hex: "#88A887"),
            emojiTint: Color(hex: "#709E6E"),
            datePanelTop: Color(hex: "#4C7846"),
            datePanelBottom: Color(hex: "#3E653A"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .foodie:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#F2D9CB"),
            wallpaperBottom: Color(hex: "#E4B28D"),
            panel: Color(hex: "#FFF7F1"),
            footerPanel: Color(hex: "#FCEEE3"),
            ink: Color(hex: "#4A2417"),
            mutedInk: Color(hex: "#7A4935"),
            tertiaryInk: Color(hex: "#9D7059"),
            accent: Color(hex: "#C6653C"),
            badgeFill: Color(hex: "#FBE4D8"),
            border: Color(hex: "#D0A289"),
            perforation: Color(hex: "#BF8E74"),
            emojiTint: Color(hex: "#D07A54"),
            datePanelTop: Color(hex: "#BD5C34"),
            datePanelBottom: Color(hex: "#A54B29"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .sporty:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#E3E7C4"),
            wallpaperBottom: Color(hex: "#CDD49A"),
            panel: Color(hex: "#FBFCEF"),
            footerPanel: Color(hex: "#F4F6E4"),
            ink: Color(hex: "#2F3818"),
            mutedInk: Color(hex: "#5D6C36"),
            tertiaryInk: Color(hex: "#7A8750"),
            accent: Color(hex: "#73873B"),
            badgeFill: Color(hex: "#EEF1D3"),
            border: Color(hex: "#B6BE82"),
            perforation: Color(hex: "#A1A96E"),
            emojiTint: Color(hex: "#8D9A4A"),
            datePanelTop: Color(hex: "#6C7E34"),
            datePanelBottom: Color(hex: "#59692C"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    }
}

private func discoverPhotoPalette(from averageColor: UIColor, fallback: DiscoverHangoutPalette) -> DiscoverHangoutPalette {
    let accent = discoverNormalizedAccentColor(from: averageColor)
    let charcoal = UIColor(red: 20 / 255, green: 24 / 255, blue: 31 / 255, alpha: 1)
    let deepInk = discoverMix(charcoal, accent, amount: 0.22)
    let footerInk = discoverMix(charcoal, accent, amount: 0.30)
    let stroke = discoverMix(charcoal, accent, amount: 0.48)
    let dateTop = discoverMix(accent, .black, amount: 0.34)
    let dateBottom = discoverMix(accent, .black, amount: 0.54)

    return DiscoverHangoutPalette(
        wallpaperTop: Color(uiColor: discoverMix(accent, .white, amount: 0.10)),
        wallpaperBottom: Color(uiColor: discoverMix(accent, .black, amount: 0.26)),
        panel: Color(uiColor: deepInk).opacity(0.82),
        footerPanel: Color(uiColor: footerInk).opacity(0.86),
        ink: Color.white,
        mutedInk: Color.white.opacity(0.90),
        tertiaryInk: Color.white.opacity(0.70),
        accent: Color(uiColor: discoverMix(accent, .white, amount: 0.08)),
        badgeFill: Color(uiColor: discoverMix(footerInk, accent, amount: 0.28)).opacity(0.92),
        border: Color(uiColor: stroke).opacity(0.78),
        perforation: Color.white.opacity(0.22),
        emojiTint: fallback.emojiTint,
        datePanelTop: Color(uiColor: dateTop),
        datePanelBottom: Color(uiColor: dateBottom),
        dateInk: Color.white,
        dateCapsule: Color.white.opacity(0.16)
    )
}

private func discoverSourceTag(for sourceType: HangoutSourceType) -> DiscoverSourceTagStyle? {
    switch sourceType {
    case .hangout:
        return nil
    case .event:
        return DiscoverSourceTagStyle(
            title: "From Event",
            fill: Color(hex: "#F5D6DE"),
            ink: Color(hex: "#8C3550")
        )
    case .offer:
        return DiscoverSourceTagStyle(
            title: "From Offer",
            fill: Color(hex: "#F7E4C9"),
            ink: Color(hex: "#9C5E19")
        )
    }
}

func discoverAccentColor(for hangout: HangoutItem) -> Color {
    discoverPalette(for: hangout.vibe).accent
}

private func discoverVibeEmoji(for vibe: HangoutVibe) -> String {
    switch vibe {
    case .chill:
        return "🛋️"
    case .drinks:
        return "🍸"
    case .deepTalk:
        return "🗣️"
    case .activity:
        return "🚴"
    case .foodie:
        return "🍝"
    case .sporty:
        return "⚽"
    }
}

private func discoverEmojiPattern(emoji: String, tint: Color, isExtended: Bool) -> some View {
    let stepX: CGFloat = isExtended ? 66 : 74
    let stepY: CGFloat = isExtended ? 60 : 68

    return GeometryReader { proxy in
        let columnCount = Int(ceil(proxy.size.width / stepX)) + 2
        let rowCount = Int(ceil(proxy.size.height / stepY)) + 2

        ZStack {
            ForEach(0 ..< rowCount, id: \.self) { row in
                ForEach(0 ..< columnCount, id: \.self) { column in
                    let isLarge = (row + column).isMultiple(of: 4)
                    let xOffset = row.isMultiple(of: 2) ? stepX * 0.18 : stepX * 0.58
                    let x = CGFloat(column) * stepX + xOffset
                    let y = CGFloat(row) * stepY + stepY * 0.44

                    Text(emoji)
                        .font(.system(size: isLarge ? (isExtended ? 26 : 24) : (isExtended ? 16 : 14)))
                        .foregroundColor(tint.opacity(isLarge ? 0.22 : 0.10))
                        .rotationEffect(.degrees(isLarge ? -4 : 3))
                        .position(x: x, y: y)
                }
            }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
}

private func discoverDayLabel(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.dateFormat = "EEE"
    return formatter.string(from: value).uppercased()
}

private func discoverTimeLabel(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: value)
}

private func discoverDateNumber(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.dateFormat = "d"
    return formatter.string(from: value)
}

private func discoverAverageUIColor(from image: UIImage) -> UIColor? {
    guard let inputImage = CIImage(image: image) else { return nil }
    let extent = inputImage.extent
    guard !extent.isEmpty else { return nil }

    let filter = CIFilter.areaAverage()
    filter.inputImage = inputImage
    filter.extent = extent

    guard let outputImage = filter.outputImage else { return nil }

    var bitmap = [UInt8](repeating: 0, count: 4)
    discoverAverageColorContext.render(
        outputImage,
        toBitmap: &bitmap,
        rowBytes: 4,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        format: .RGBA8,
        colorSpace: nil
    )

    return UIColor(
        red: CGFloat(bitmap[0]) / 255,
        green: CGFloat(bitmap[1]) / 255,
        blue: CGFloat(bitmap[2]) / 255,
        alpha: 1
    )
}

private func discoverNormalizedAccentColor(from color: UIColor) -> UIColor {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0

    guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
        return color
    }

    let normalizedSaturation = min(max(saturation * 1.25, 0.45), 0.86)
    let normalizedBrightness = min(max(brightness * 0.90, 0.50), 0.80)
    return UIColor(hue: hue, saturation: normalizedSaturation, brightness: normalizedBrightness, alpha: 1)
}

private func discoverMix(_ first: UIColor, _ second: UIColor, amount: CGFloat) -> UIColor {
    let clamped = min(max(amount, 0), 1)
    var firstRed: CGFloat = 0
    var firstGreen: CGFloat = 0
    var firstBlue: CGFloat = 0
    var firstAlpha: CGFloat = 0
    var secondRed: CGFloat = 0
    var secondGreen: CGFloat = 0
    var secondBlue: CGFloat = 0
    var secondAlpha: CGFloat = 0

    guard first.getRed(&firstRed, green: &firstGreen, blue: &firstBlue, alpha: &firstAlpha),
          second.getRed(&secondRed, green: &secondGreen, blue: &secondBlue, alpha: &secondAlpha) else {
        return first
    }

    return UIColor(
        red: firstRed + (secondRed - firstRed) * clamped,
        green: firstGreen + (secondGreen - firstGreen) * clamped,
        blue: firstBlue + (secondBlue - firstBlue) * clamped,
        alpha: firstAlpha + (secondAlpha - firstAlpha) * clamped
    )
}
