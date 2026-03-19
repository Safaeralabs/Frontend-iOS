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
                emoji: hangout.vibe.emoji,
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
                        text: "\(hangout.vibe.emoji) \(hangout.vibe.title)",
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

                Text(hangout.isLive ? "LIVE" : (timeRemainingText(from: Date(), to: hangout.startAt) ?? "SOON"))
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
    case .social:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#D7F1EE"),
            wallpaperBottom: Color(hex: "#A8DED6"),
            panel: Color(hex: "#F4FCFB"),
            footerPanel: Color(hex: "#EAF8F6"),
            ink: Color(hex: "#143B39"),
            mutedInk: Color(hex: "#316562"),
            tertiaryInk: Color(hex: "#5B8884"),
            accent: Color(hex: "#199C94"),
            badgeFill: Color(hex: "#D7F2EE"),
            border: Color(hex: "#91CEC8"),
            perforation: Color(hex: "#76B9B2"),
            emojiTint: Color(hex: "#58BDB6"),
            datePanelTop: Color(hex: "#128B84"),
            datePanelBottom: Color(hex: "#0D7670"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .party:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#F6D3E6"),
            wallpaperBottom: Color(hex: "#E89BC2"),
            panel: Color(hex: "#FFF7FB"),
            footerPanel: Color(hex: "#FBEAF3"),
            ink: Color(hex: "#4B1735"),
            mutedInk: Color(hex: "#7C3E61"),
            tertiaryInk: Color(hex: "#A66789"),
            accent: Color(hex: "#D9468D"),
            badgeFill: Color(hex: "#F9E0EE"),
            border: Color(hex: "#D7A0BF"),
            perforation: Color(hex: "#C78AAE"),
            emojiTint: Color(hex: "#E06AA5"),
            datePanelTop: Color(hex: "#D2367F"),
            datePanelBottom: Color(hex: "#B9286B"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .creative:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#E9E1FF"),
            wallpaperBottom: Color(hex: "#C8B8F3"),
            panel: Color(hex: "#FBF8FF"),
            footerPanel: Color(hex: "#F3ECFF"),
            ink: Color(hex: "#312056"),
            mutedInk: Color(hex: "#5D448F"),
            tertiaryInk: Color(hex: "#8470B2"),
            accent: Color(hex: "#7F63E8"),
            badgeFill: Color(hex: "#EEE8FF"),
            border: Color(hex: "#BEAFE9"),
            perforation: Color(hex: "#A997DB"),
            emojiTint: Color(hex: "#927BEF"),
            datePanelTop: Color(hex: "#7155D9"),
            datePanelBottom: Color(hex: "#5E43C0"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .outdoors:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#DCEFD6"),
            wallpaperBottom: Color(hex: "#B8D8AE"),
            panel: Color(hex: "#F7FBF4"),
            footerPanel: Color(hex: "#EEF6EA"),
            ink: Color(hex: "#21381E"),
            mutedInk: Color(hex: "#476243"),
            tertiaryInk: Color(hex: "#6C8867"),
            accent: Color(hex: "#3E9557"),
            badgeFill: Color(hex: "#E3F0DE"),
            border: Color(hex: "#A7C79F"),
            perforation: Color(hex: "#8AB984"),
            emojiTint: Color(hex: "#6AAA6F"),
            datePanelTop: Color(hex: "#317B46"),
            datePanelBottom: Color(hex: "#28653A"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .drinks:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#EEF0D4"),
            wallpaperBottom: Color(hex: "#D5D99C"),
            panel: Color(hex: "#FCFCEF"),
            footerPanel: Color(hex: "#F5F6E1"),
            ink: Color(hex: "#384118"),
            mutedInk: Color(hex: "#5F6D33"),
            tertiaryInk: Color(hex: "#808E4D"),
            accent: Color(hex: "#7D9731"),
            badgeFill: Color(hex: "#EFF2D1"),
            border: Color(hex: "#BBC67A"),
            perforation: Color(hex: "#A5AF63"),
            emojiTint: Color(hex: "#95AA4B"),
            datePanelTop: Color(hex: "#708927"),
            datePanelBottom: Color(hex: "#5E721F"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .deepTalk:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#DEE3FA"),
            wallpaperBottom: Color(hex: "#BDC8F0"),
            panel: Color(hex: "#F9FAFF"),
            footerPanel: Color(hex: "#EEF1FD"),
            ink: Color(hex: "#202A4B"),
            mutedInk: Color(hex: "#43557D"),
            tertiaryInk: Color(hex: "#6778A1"),
            accent: Color(hex: "#5057B8"),
            badgeFill: Color(hex: "#E4E8FA"),
            border: Color(hex: "#A7B0DA"),
            perforation: Color(hex: "#919BCB"),
            emojiTint: Color(hex: "#7079CC"),
            datePanelTop: Color(hex: "#4950A8"),
            datePanelBottom: Color(hex: "#3B428F"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .boardGames:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#F5E2BF"),
            wallpaperBottom: Color(hex: "#EAC978"),
            panel: Color(hex: "#FFF9ED"),
            footerPanel: Color(hex: "#FBF1DB"),
            ink: Color(hex: "#4B3111"),
            mutedInk: Color(hex: "#755222"),
            tertiaryInk: Color(hex: "#9C7540"),
            accent: Color(hex: "#C98217"),
            badgeFill: Color(hex: "#F8E7C1"),
            border: Color(hex: "#D4AF6E"),
            perforation: Color(hex: "#C39752"),
            emojiTint: Color(hex: "#D8A139"),
            datePanelTop: Color(hex: "#BE7410"),
            datePanelBottom: Color(hex: "#A25F0C"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .culture:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#F2DADF"),
            wallpaperBottom: Color(hex: "#E0B2BE"),
            panel: Color(hex: "#FFF8FA"),
            footerPanel: Color(hex: "#F9ECF0"),
            ink: Color(hex: "#4C2230"),
            mutedInk: Color(hex: "#774656"),
            tertiaryInk: Color(hex: "#9D6B7A"),
            accent: Color(hex: "#A23E61"),
            badgeFill: Color(hex: "#F4DDE3"),
            border: Color(hex: "#D3A6B3"),
            perforation: Color(hex: "#C38B9D"),
            emojiTint: Color(hex: "#C16284"),
            datePanelTop: Color(hex: "#963755"),
            datePanelBottom: Color(hex: "#7E2D46"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .foodie:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#F5DDD1"),
            wallpaperBottom: Color(hex: "#E7B193"),
            panel: Color(hex: "#FFF8F3"),
            footerPanel: Color(hex: "#FCEEE6"),
            ink: Color(hex: "#4C2619"),
            mutedInk: Color(hex: "#7B4B38"),
            tertiaryInk: Color(hex: "#A2705C"),
            accent: Color(hex: "#D95F3D"),
            badgeFill: Color(hex: "#FBE4DA"),
            border: Color(hex: "#D3A08B"),
            perforation: Color(hex: "#C38B75"),
            emojiTint: Color(hex: "#DE7857"),
            datePanelTop: Color(hex: "#CB5534"),
            datePanelBottom: Color(hex: "#AE4628"),
            dateInk: Color.white,
            dateCapsule: Color.white.opacity(0.18)
        )
    case .sporty:
        return DiscoverHangoutPalette(
            wallpaperTop: Color(hex: "#D8E9FF"),
            wallpaperBottom: Color(hex: "#AFCFF7"),
            panel: Color(hex: "#F7FBFF"),
            footerPanel: Color(hex: "#EAF3FF"),
            ink: Color(hex: "#183352"),
            mutedInk: Color(hex: "#40678F"),
            tertiaryInk: Color(hex: "#678BB3"),
            accent: Color(hex: "#1E7BE8"),
            badgeFill: Color(hex: "#DFECFF"),
            border: Color(hex: "#9DBCE5"),
            perforation: Color(hex: "#85A6D5"),
            emojiTint: Color(hex: "#5E96E9"),
            datePanelTop: Color(hex: "#1A6FD2"),
            datePanelBottom: Color(hex: "#165DB0"),
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
