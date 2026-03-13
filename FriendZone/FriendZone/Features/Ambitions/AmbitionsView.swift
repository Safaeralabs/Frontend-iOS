import SwiftUI

private struct HangoutRoute: Identifiable {
    let id: Int

    var path: String {
        "/hangout/\(id)"
    }
}

struct AmbitionsView: View {
    @EnvironmentObject private var session: AppSessionStore
    @StateObject private var viewModel = AmbitionsViewModel()

    @State private var presentedHangoutRoute: HangoutRoute?
    @State private var selectedSignal: AmbitionQuickSignal = .freeTonight
    @State private var selectedInterest: AmbitionInterestPreset = .coffee
    @State private var selectedVibe: AmbitionQuickVibe = .chill
    @State private var selectedRadiusKm = 10

    private let radiusOptions = [3, 5, 10, 20]

    var body: some View {
        ZStack(alignment: .top) {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    heroHeader

                    if let successMessage = viewModel.successMessage {
                        feedbackBanner(
                            icon: "checkmark.circle.fill",
                            message: successMessage,
                            tint: FriendZoneTheme.Colors.success,
                            background: FriendZoneTheme.Colors.success.opacity(0.12)
                        )
                    }

                    if let errorMessage = viewModel.errorMessage {
                        feedbackBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: FriendZoneTheme.Colors.warning,
                            background: FriendZoneTheme.Colors.warning.opacity(0.12)
                        )
                    }

                    intentComposer
                    liveSignalsSection
                    formingMatchesSection
                    unlockedHangoutsSection
                }
                .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
                .padding(.top, FriendZoneTheme.Chrome.topOffset)
                .padding(.bottom, 32)
            }
        }
        .overlay(loadingOverlay)
        .task {
            await viewModel.loadIfNeeded()
        }
        .task(id: viewModel.shouldPollForHangout) {
            guard viewModel.shouldPollForHangout else { return }
            while !Task.isCancelled && viewModel.shouldPollForHangout {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                await viewModel.pollForHangoutUpdates()
            }
        }
        .onChange(of: viewModel.pendingOpenHangoutID) { hangoutID in
            guard let hangoutID else { return }
            openHangout(id: hangoutID)
            viewModel.clearPendingHangoutOpen()
        }
        .sheet(item: $presentedHangoutRoute) { route in
            WebScreen(path: route.path)
        }
        .ignoresSafeArea(.container, edges: [.bottom])
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                FriendZoneTheme.Colors.background,
                FriendZoneTheme.Colors.primarySoft.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var heroHeader: some View {
        FriendZoneModuleHeader(
            leadingText: "Signal your ",
            highlightText: "next move",
            subtitle: "Start from intent. If the right people say yes, FriendZone turns it into a hangout.",
            horizontalPadding: FriendZoneTheme.Chrome.horizontalInset
        ) {
            HStack(spacing: 10) {
                if viewModel.isCreating || viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(FriendZoneTheme.Colors.primary)
                        .frame(width: 32, height: 32)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(Circle())
                } else {
                    Button {
                        viewModel.clearSuccessMessage()
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                            .frame(width: 32, height: 32)
                            .background(FriendZoneTheme.Colors.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                FriendZoneLogoMark(size: 32, cornerRadius: 12)
            }
        }
    }

    private var intentComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INTENT")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.8)

                    Text("What are you up for?")
                        .font(FriendZoneTheme.Typography.system(20, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }

                Spacer(minLength: 0)

                cityModePill
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionEyebrow("Signal")

                HStack(spacing: 8) {
                    ForEach(AmbitionQuickSignal.allCases) { signal in
                        AmbitionSelectionChip(
                            title: signal.title,
                            subtitle: signal.shortCaption,
                            emoji: signal.emoji,
                            isSelected: signal == selectedSignal
                        ) {
                            selectedSignal = signal
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionEyebrow("Intent")

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    ForEach(AmbitionInterestPreset.allCases) { interest in
                        AmbitionInterestTile(
                            interest: interest,
                            isSelected: interest == selectedInterest
                        ) {
                            selectedInterest = interest
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionEyebrow("Vibe")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AmbitionQuickVibe.allCases) { vibe in
                            AmbitionVibePill(
                                vibe: vibe,
                                isSelected: vibe == selectedVibe
                            ) {
                                selectedVibe = vibe
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            HStack(spacing: 10) {
                locationSummaryCard

                radiusSummaryCard
            }

            if activeCityPlaceId == nil {
                Text("Set your city first to start matching.")
                    .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.warning)
            }

            Button {
                startMatching()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isCreating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text(viewModel.isCreating ? "Matching..." : "Start matching")
                        .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCreating || activeCityPlaceId == nil)
            .opacity(viewModel.isCreating || activeCityPlaceId == nil ? 0.55 : 1)
        }
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private var cityModePill: some View {
        HStack(spacing: 6) {
            Image(systemName: session.isTravelModeActive ? "airplane" : "house.fill")
                .font(.system(size: 10, weight: .bold))

            Text(session.isTravelModeActive ? "TRAVEL" : "HOME")
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
        }
        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(Capsule())
    }

    private var locationSummaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.isTravelModeActive ? "Travel city" : "Current city")
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            Text(activeCityName ?? "Missing city")
                .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(1)
            Text(selectedSignal.windowLabel)
                .font(FriendZoneTheme.Typography.system(10.5, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FriendZoneTheme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var radiusSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Radius")
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            HStack(spacing: 6) {
                ForEach(radiusOptions, id: \.self) { radius in
                    Text("\(radius)km")
                        .font(FriendZoneTheme.Typography.system(10.5, weight: .bold))
                        .foregroundColor(radius == selectedRadiusKm ? .white : FriendZoneTheme.Colors.textSecondary)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(radius == selectedRadiusKm ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.surfaceMuted)
                        .clipShape(Capsule())
                        .onTapGesture {
                            selectedRadiusKm = radius
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FriendZoneTheme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var liveSignalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Live signals",
                subtitle: "Intentions that are still waiting for overlap."
            )

            if viewModel.ambitions.isEmpty {
                emptyStateCard(
                    title: "No live signal yet",
                    message: "Once you start matching, your active intent appears here."
                )
            } else {
                ForEach(viewModel.ambitions) { ambition in
                    liveSignalCard(ambition)
                }
            }
        }
    }

    private var formingMatchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Matches forming",
                subtitle: "People who overlap with this exact plan energy."
            )

            if viewModel.formingMatches.isEmpty {
                emptyStateCard(
                    title: "No crew forming yet",
                    message: "Signals that line up in time, city and vibe will show up here."
                )
            } else {
                ForEach(viewModel.formingMatches) { match in
                    formingMatchCard(match)
                }
            }
        }
    }

    private var unlockedHangoutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Hangouts unlocked",
                subtitle: "When enough people accept, the plan becomes a hangout."
            )

            if viewModel.hangoutMatches.isEmpty {
                emptyStateCard(
                    title: "Nothing unlocked yet",
                    message: "Accepted matches move here as soon as a hangout is created."
                )
            } else {
                ForEach(viewModel.hangoutMatches) { match in
                    unlockedHangoutCard(match)
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(20, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(subtitle)
                .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
    }

    private func sectionEyebrow(_ title: String) -> some View {
        Text(title.uppercased())
            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            .tracking(0.8)
    }

    private func feedbackBanner(icon: String, message: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)

            Text(message)
                .font(FriendZoneTheme.Typography.system(11.5, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func emptyStateCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(message)
                .font(FriendZoneTheme.Typography.system(11.5, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineSpacing(1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func liveSignalCard(_ ambition: Ambition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(interestDisplayTitle(for: ambition.primaryInterest))
                        .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(signalWindowLabel(for: ambition.startAt, endAt: ambition.endAt))
                        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                smallBadge(timeUntilLabel(for: ambition.startAt))
            }

            HStack(spacing: 8) {
                compactMetaPill((ambition.cityName ?? activeCityName ?? "City").uppercased())
                compactMetaPill(vibeDisplayTitle(for: ambition.vibe).uppercased())
                compactMetaPill((ambition.status ?? "active").uppercased())
            }
        }
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func formingMatchCard(_ match: AmbitionMatch) -> some View {
        let actionInFlight = viewModel.activeMatchActions[match.id]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(interestDisplayTitle(for: match.primaryInterest))
                        .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(matchTimingLine(match))
                        .font(FriendZoneTheme.Typography.system(11.5, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                smallBadge(matchQualityLabel(match.matchQualityScore))
            }

            if !(match.otherMembers ?? []).isEmpty {
                memberStrip(match)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(unlockLine(match))
                        .font(FriendZoneTheme.Typography.system(11.5, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Spacer(minLength: 0)

                    Text("\(match.acceptedCount ?? 0)/\(match.minSize ?? 2)")
                        .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }

                GeometryReader { proxy in
                    let progress = min(
                        1,
                        CGFloat(match.acceptedCount ?? 0) / CGFloat(max(match.minSize ?? 2, 1))
                    )

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(FriendZoneTheme.Colors.surfaceMuted)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(26, proxy.size.width * progress))
                    }
                }
                .frame(height: 8)
            }

            matchActionArea(for: match, actionInFlight: actionInFlight)
        }
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func memberStrip(_ match: AmbitionMatch) -> some View {
        let members = Array((match.otherMembers ?? []).prefix(4))

        return HStack(spacing: 8) {
            ForEach(members) { member in
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(FriendZoneTheme.Colors.primarySoft)
                            .frame(width: 28, height: 28)

                        Text(initials(for: member.user.username))
                            .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                    }

                    Text(member.user.username)
                        .font(FriendZoneTheme.Typography.system(10.5, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .frame(height: 36)
                .background(FriendZoneTheme.Colors.surfaceElevated)
                .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private func matchActionArea(for match: AmbitionMatch, actionInFlight: AmbitionMatchAction?) -> some View {
        if let hangoutID = match.hangout {
            Button {
                openHangout(id: hangoutID)
            } label: {
                Text("Open hangout")
                    .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            switch (match.userStatus ?? "suggested").lowercased() {
            case "suggested":
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await viewModel.respondToMatch(matchID: match.id, action: .decline)
                        }
                    } label: {
                        Group {
                            if actionInFlight == .decline {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(FriendZoneTheme.Colors.textSecondary)
                            } else {
                                Text("Pass")
                            }
                        }
                        .font(FriendZoneTheme.Typography.system(13.5, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(actionInFlight != nil)

                    Button {
                        Task {
                            await viewModel.respondToMatch(matchID: match.id, action: .accept)
                        }
                    } label: {
                        Group {
                            if actionInFlight == .accept {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("I'm in")
                            }
                        }
                        .font(FriendZoneTheme.Typography.system(13.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(actionInFlight != nil)
                }
            case "accepted":
                statusStrip("You are in. Waiting on the others.", tint: FriendZoneTheme.Colors.primary)
            case "declined":
                statusStrip("You passed on this one.", tint: FriendZoneTheme.Colors.textTertiary)
            default:
                statusStrip("Match is updating.", tint: FriendZoneTheme.Colors.textSecondary)
            }
        }
    }

    private func unlockedHangoutCard(_ match: AmbitionMatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(interestDisplayTitle(for: match.primaryInterest))
                        .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(matchTimingLine(match))
                        .font(FriendZoneTheme.Typography.system(11.5, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                smallBadge("UNLOCKED")
            }

            HStack(spacing: 8) {
                compactMetaPill((match.cityName ?? activeCityName ?? "City").uppercased())
                compactMetaPill("\(match.hangoutParticipantCount ?? match.acceptedCount ?? 0) IN")
                compactMetaPill(match.hangoutIsFull == true ? "FULL" : "OPEN")
            }

            if let hangoutID = match.hangout {
                Button {
                    openHangout(id: hangoutID)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Open hangout")
                            .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.primary.opacity(0.22), lineWidth: 1)
        }
    }

    private func smallBadge(_ text: String) -> some View {
        Text(text)
            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.primary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(FriendZoneTheme.Colors.primarySoft)
            .clipShape(Capsule())
    }

    private func compactMetaPill(_ text: String) -> some View {
        Text(text)
            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(FriendZoneTheme.Colors.surfaceMuted)
            .clipShape(Capsule())
    }

    private func statusStrip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(FriendZoneTheme.Typography.system(11.5, weight: .bold))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(tint.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading && viewModel.ambitions.isEmpty && viewModel.matches.isEmpty {
            Color.black.opacity(0.02)
                .ignoresSafeArea()
                .overlay {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(16)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .friendZoneShadow(FriendZoneTheme.Shadows.md)
                }
        }
    }

    private var activeCityName: String? {
        session.activeCityName
    }

    private var activeCityPlaceId: String? {
        session.activeCityPlaceId
    }

    private func startMatching() {
        guard let cityPlaceId = activeCityPlaceId, let cityName = activeCityName else {
            viewModel.errorMessage = "Set a city first to create an ambition."
            return
        }

        let payload = QuickAmbitionPayload(
            primaryInterest: selectedInterest.primaryInterest,
            signalType: selectedSignal.rawValue,
            vibe: selectedVibe.rawValue,
            cityPlaceId: cityPlaceId,
            cityName: cityName,
            interests: selectedInterest.relatedInterests,
            lat: nil,
            lng: nil,
            radiusKm: selectedRadiusKm
        )

        Task {
            await viewModel.createQuickAmbition(payload)
        }
    }

    private func matchTimingLine(_ match: AmbitionMatch) -> String {
        let city = match.cityName ?? activeCityName ?? "your city"
        return "\(signalWindowLabel(for: match.startAt, endAt: match.endAt)) · \(city)"
    }

    private func signalWindowLabel(for start: String?, endAt end: String?) -> String {
        guard let startDate = ISODateParser.parse(start) else { return "Timing to be confirmed" }
        let startFormatter = DateFormatter()
        startFormatter.locale = .autoupdatingCurrent
        startFormatter.dateFormat = "EEE h:mm a"

        guard let endDate = ISODateParser.parse(end) else {
            return startFormatter.string(from: startDate)
        }

        let durationHours = max(1, Int(round(endDate.timeIntervalSince(startDate) / 3600)))
        return "\(startFormatter.string(from: startDate)) · \(durationHours)h block"
    }

    private func timeUntilLabel(for start: String?) -> String {
        guard let startDate = ISODateParser.parse(start) else { return "SOON" }
        let now = Date()
        if startDate <= now {
            return "NOW"
        }

        let interval = Int(startDate.timeIntervalSince(now))
        if interval < 3600 {
            return "IN \(max(1, interval / 60))M"
        }
        if interval < 86_400 {
            return "IN \(interval / 3600)H"
        }
        return "NEXT"
    }

    private func unlockLine(_ match: AmbitionMatch) -> String {
        let accepted = match.acceptedCount ?? 0
        let minimum = max(match.minSize ?? 2, 2)
        let remaining = max(minimum - accepted, 0)

        if remaining == 0 {
            return "Enough people are in. Converting now."
        }
        if remaining == 1 {
            return "One more yes unlocks the hangout."
        }
        return "\(remaining) more yeses unlock the hangout."
    }

    private func matchQualityLabel(_ score: Double?) -> String {
        guard let score else { return "MATCH" }
        return "\(Int((score * 100).rounded()))% FIT"
    }

    private func interestDisplayTitle(for rawValue: String?) -> String {
        AmbitionInterestPreset.displayTitle(for: rawValue)
    }

    private func vibeDisplayTitle(for rawValue: String?) -> String {
        AmbitionQuickVibe.displayTitle(for: rawValue)
    }

    private func initials(for username: String) -> String {
        let pieces = username
            .split(whereSeparator: { $0 == "_" || $0 == "." || $0 == " " })
            .map(String.init)

        if pieces.count >= 2 {
            return pieces.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
        }

        return String(username.prefix(2)).uppercased()
    }

    private func openHangout(id: Int) {
        presentedHangoutRoute = HangoutRoute(id: id)
    }
}

private enum AmbitionQuickSignal: String, CaseIterable, Identifiable {
    case freeTonight = "free_tonight"
    case afterwork = "afterwork"
    case weekendPlan = "weekend_plan"
    case cravingFood = "craving_food"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freeTonight: return "Tonight"
        case .afterwork: return "Afterwork"
        case .weekendPlan: return "Weekend"
        case .cravingFood: return "Food run"
        }
    }

    var shortCaption: String {
        switch self {
        case .freeTonight: return "Now"
        case .afterwork: return "Later"
        case .weekendPlan: return "Ahead"
        case .cravingFood: return "Fast"
        }
    }

    var emoji: String {
        switch self {
        case .freeTonight: return "🌙"
        case .afterwork: return "🥂"
        case .weekendPlan: return "🎈"
        case .cravingFood: return "🍜"
        }
    }

    var windowLabel: String {
        switch self {
        case .freeTonight: return "Tonight window"
        case .afterwork: return "Afterwork slot"
        case .weekendPlan: return "Weekend block"
        case .cravingFood: return "Soon"
        }
    }
}

private enum AmbitionInterestPreset: String, CaseIterable, Identifiable {
    case coffee
    case drinks
    case food
    case walk
    case music
    case deepTalk = "deep_talk"

    var id: String { rawValue }

    var primaryInterest: String {
        rawValue
    }

    var title: String {
        switch self {
        case .coffee: return "Coffee"
        case .drinks: return "Drinks"
        case .food: return "Food"
        case .walk: return "Walk"
        case .music: return "Music"
        case .deepTalk: return "Deep talk"
        }
    }

    var emoji: String {
        switch self {
        case .coffee: return "☕"
        case .drinks: return "🍸"
        case .food: return "🍽️"
        case .walk: return "🚶"
        case .music: return "🎶"
        case .deepTalk: return "🧠"
        }
    }

    var relatedInterests: [String] {
        switch self {
        case .coffee:
            return ["coffee", "casual"]
        case .drinks:
            return ["drinks", "nightlife"]
        case .food:
            return ["food", "dinner"]
        case .walk:
            return ["walks", "outdoors"]
        case .music:
            return ["music", "culture"]
        case .deepTalk:
            return ["deep_talk", "conversation"]
        }
    }

    static func displayTitle(for rawValue: String?) -> String {
        guard let rawValue else { return "Signal" }
        return Self.allCases.first(where: { $0.rawValue == rawValue })?.title
            ?? rawValue
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
    }
}

private enum AmbitionQuickVibe: String, CaseIterable, Identifiable {
    case chill
    case drinks
    case activity
    case deepTalk = "deep_talk"
    case food
    case cultural

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chill: return "Chill"
        case .drinks: return "Social"
        case .activity: return "Active"
        case .deepTalk: return "Deep"
        case .food: return "Foodie"
        case .cultural: return "Culture"
        }
    }

    var emoji: String {
        switch self {
        case .chill: return "🫖"
        case .drinks: return "✨"
        case .activity: return "⚡"
        case .deepTalk: return "🧠"
        case .food: return "🍝"
        case .cultural: return "🎭"
        }
    }

    static func displayTitle(for rawValue: String?) -> String {
        guard let rawValue else { return "Vibe" }
        return Self.allCases.first(where: { $0.rawValue == rawValue })?.title
            ?? rawValue
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
    }
}

private struct AmbitionSelectionChip: View {
    let title: String
    let subtitle: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 18))

                Text(title)
                    .font(FriendZoneTheme.Typography.system(11.5, weight: .bold))

                Text(subtitle.uppercased())
                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                    .opacity(0.72)
            }
            .foregroundColor(isSelected ? .white : FriendZoneTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AmbitionInterestTile: View {
    let interest: AmbitionInterestPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(interest.emoji)
                    .font(.system(size: 17))

                Text(interest.title)
                    .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(FriendZoneTheme.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AmbitionVibePill: View {
    let vibe: AmbitionQuickVibe
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(vibe.emoji)
                    .font(.system(size: 14))

                Text(vibe.title)
                    .font(FriendZoneTheme.Typography.system(11.5, weight: .bold))
            }
            .foregroundColor(isSelected ? .white : FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.surfaceElevated)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
