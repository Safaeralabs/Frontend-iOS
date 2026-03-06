import SwiftUI

private struct HangoutRoute: Identifiable {
    let id: Int

    var path: String {
        "/hangout/\(id)"
    }
}

struct AmbitionsView: View {
    @StateObject private var viewModel = AmbitionsViewModel()
    @State private var presentedHangoutRoute: HangoutRoute?

    @State private var selectedInterest = "Coffee & Vibes"
    @State private var selectedVibe = "Chill"
    @State private var preferredTime = Self.roundedHour()
    @State private var desiredGroupSize = 4
    @State private var ambitionNote = ""

    private let interestOptions = [
        "Coffee & Vibes",
        "Sunset Walk",
        "Live Music",
        "Rooftop Drinks",
        "Art Crawl"
    ]

    private let vibeOptions = [
        "Chill",
        "Spontaneous",
        "Focused",
        "Low-key"
    ]

    private let storySteps: [FlowStep] = [
        .init(
            id: 0,
            icon: "bolt.fill",
            title: "Share the energy",
            detail: "Tell FriendZone when, where, and the tone you want.",
            accent: FriendZoneTheme.Colors.primary
        ),
        .init(
            id: 1,
            icon: "person.3.sequence.fill",
            title: "We fine tune",
            detail: "Matching people who are free for that exact block.",
            accent: FriendZoneTheme.Colors.primaryAccent
        ),
        .init(
            id: 2,
            icon: "sparkles",
            title: "Hangout appears",
            detail: "As soon as everyone agrees, the hangout card pops in.",
            accent: FriendZoneTheme.Colors.primarySoft
        )
    ]

    private let sampleMatches: [SampleFlowItem] = [
        .init(
            id: 1,
            title: "Daylight Coffee",
            subtitle: "Coffee & Vibes · Today · 6:15 PM",
            badge: "Waiting on you",
            participants: "2 people matched",
            accentColor: FriendZoneTheme.Colors.primary
        ),
        .init(
            id: 2,
            title: "Museo Stroll",
            subtitle: "Live Music · Today · 8:00 PM",
            badge: "3 people accepted",
            participants: "You are tagged in this one",
            accentColor: FriendZoneTheme.Colors.primaryAccent
        )
    ]

    private let sampleHangouts: [SampleFlowItem] = [
        .init(
            id: 3,
            title: "Golden Hour Walk",
            subtitle: "Sunset Walk · 7:30 PM · Retiro",
            badge: "Hangout ready",
            participants: "3 joined",
            accentColor: FriendZoneTheme.Colors.primary
        ),
        .init(
            id: 4,
            title: "Rooftop Drops",
            subtitle: "Rooftop Drinks · 9:00 PM",
            badge: "Adding one more",
            participants: "2 confirmed, 1 waiting",
            accentColor: FriendZoneTheme.Colors.primaryAccent
        )
    ]

    var body: some View {
        ZStack(alignment: .top) {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.lg) {
                    heroHeader

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    ambitionForm
                    flowTracker
                    matchesSection
                    hangoutsSection
                }
                .padding(.horizontal, FriendZoneTheme.Spacing.md)
                .padding(.top, FriendZoneTheme.Spacing.md)
                .padding(.bottom, FriendZoneTheme.Spacing.xl)
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
        .sheet(item: $presentedHangoutRoute) { route in
            WebScreen(path: route.path)
        }
        .ignoresSafeArea(.container, edges: [.bottom])
    }

    private static func roundedHour() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        )
        return nextHour ?? Date()
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
            leadingText: "Set the",
            highlightText: "energy",
            subtitle: "Tell FriendZone what you are up for and we handle the matching.",
            horizontalPadding: 20
        ) {
            HStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Image(systemName: viewModel.isLoading ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                        .frame(width: 34, height: 34)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)

                FriendZoneLogoMark(size: 32, cornerRadius: 12)
            }
        }
        .padding(.top, 8)
    }

    private var ambitionForm: some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
            Text("Your next move")
                .font(FriendZoneTheme.Typography.displaySerif(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            TextField(
                "Describe what you are craving right now",
                text: $ambitionNote
            )
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM))
            .padding(12)
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))

            Text("Pick a vibe")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FriendZoneTheme.Spacing.sm) {
                    ForEach(interestOptions, id: \.self) { option in
                        interestChip(title: option, isActive: option == selectedInterest) {
                            selectedInterest = option
                            ambitionNote = option
                        }
                    }
                }
            }

            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                ForEach(vibeOptions, id: \.self) { vibe in
                    vibeChip(title: vibe, isActive: vibe == selectedVibe) {
                        selectedVibe = vibe
                    }
                }
            }

            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(FriendZoneTheme.Colors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("When")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    Text(formatTime(preferredTime))
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }

                Spacer()

                DatePicker(
                    "",
                    selection: $preferredTime,
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
            }

            Stepper(
                "Group size · \(desiredGroupSize) people",
                value: $desiredGroupSize,
                in: 2...8
            )
            .tint(FriendZoneTheme.Colors.primary)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Text("Broadcast ambition")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .background(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, FriendZoneTheme.Spacing.sm)
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous))
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private var flowTracker: some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
            sectionHeader(
                title: "Flow preview",
                subtitle: "A simple timeline showing what happens after you tap broadcast."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FriendZoneTheme.Spacing.sm) {
                    ForEach(storySteps) { FlowStepView(step: $0) }
                }
            }
        }
    }

    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
            sectionHeader(
                title: "Matches waiting for you",
                subtitle: "Confirm people you want to hang out with."
            )

            VStack(spacing: FriendZoneTheme.Spacing.sm) {
                if viewModel.formingMatches.isEmpty {
                    ForEach(sampleMatches) { sampleMatchCard($0) }
                } else {
                    ForEach(viewModel.formingMatches) { matchCard($0) }
                }
            }
        }
    }

    private var hangoutsSection: some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
            sectionHeader(
                title: "Hangouts in motion",
                subtitle: "When everyone says yes, a hangout card appears."
            )

            VStack(spacing: FriendZoneTheme.Spacing.sm) {
                if viewModel.hangoutMatches.isEmpty {
                    ForEach(sampleHangouts) { sampleHangoutCard($0) }
                } else {
                    ForEach(viewModel.hangoutMatches) { hangoutCard($0) }
                }
            }
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading {
            Color.black.opacity(0.02)
                .ignoresSafeArea()
                .overlay {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(16)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
                        .friendZoneShadow(FriendZoneTheme.Shadows.md)
                }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: FriendZoneTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.warning)

            Text(message)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
        .padding(.vertical, FriendZoneTheme.Spacing.sm)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FriendZoneTheme.Colors.borderSubtle)
                .frame(height: FriendZoneTheme.BorderWidth.thin)
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(subtitle)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
    }

    private func interestChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
            .foregroundColor(isActive ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.surfaceMuted)
            .clipShape(Capsule())
            .onTapGesture { action() }
    }

    private func vibeChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            .foregroundColor(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                    .stroke(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
            )
            .onTapGesture { action() }
    }

    private func matchCard(_ match: AmbitionMatch) -> some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
            Text(match.primaryInterest ?? "Match")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(matchSummary(match))
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .regular))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                if let cityName = match.cityName, !cityName.isEmpty {
                    capsule(cityName)
                }
                if let status = match.userStatus, !status.isEmpty {
                    capsule(status.capitalized)
                }
                if let start = match.startAt {
                    capsule(shortDate(start))
                }
            }

            matchActionArea(for: match)
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }

    private func sampleMatchCard(_ sample: SampleFlowItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sample.title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(sample.subtitle)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .regular))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            Text(sample.participants)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .foregroundColor(sample.accentColor)

            badgeLabel(sample.badge, color: sample.accentColor)
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }

    private func hangoutCard(_ match: AmbitionMatch) -> some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
            Text(match.primaryInterest ?? "Hangout")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                if let cityName = match.cityName, !cityName.isEmpty {
                    capsule(cityName)
                }
                if let start = match.startAt {
                    capsule(shortDate(start))
                }
                if let end = match.endAt {
                    capsule(shortDate(end))
                }
            }

            if let hangoutID = match.hangout {
                Button {
                    openHangout(id: hangoutID)
                } label: {
                    Text("Open hangout")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }

    private func sampleHangoutCard(_ sample: SampleFlowItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sample.title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(sample.subtitle)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .regular))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            Text(sample.participants)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .foregroundColor(sample.accentColor)

            badgeLabel(sample.badge, color: sample.accentColor)
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }

    @ViewBuilder
    private func matchActionArea(for match: AmbitionMatch) -> some View {
        let actionInFlight = viewModel.activeMatchActions[match.id]

        if let hangoutID = match.hangout {
            Button {
                openHangout(id: hangoutID)
            } label: {
                Text("Open hangout")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            switch (match.userStatus ?? "suggested").lowercased() {
            case "suggested":
                if match.hangoutIsFull == true {
                    statusBanner(
                        text: "Full",
                        foreground: FriendZoneTheme.Colors.warning,
                        background: FriendZoneTheme.Colors.warning.opacity(0.12)
                    )
                } else {
                    HStack(spacing: FriendZoneTheme.Spacing.sm) {
                        Button {
                            Task {
                                await viewModel.respondToMatch(matchID: match.id, action: .decline)
                            }
                        } label: {
                            if actionInFlight == .decline {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(FriendZoneTheme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            } else {
                                Text("Pass")
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
                        .disabled(actionInFlight != nil)

                        Button {
                            Task {
                                await viewModel.respondToMatch(matchID: match.id, action: .accept)
                            }
                        } label: {
                            if actionInFlight == .accept {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(FriendZoneTheme.Colors.textInverse)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            } else {
                                Text("Join solo")
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
                        .disabled(actionInFlight != nil)
                    }
                }
            case "accepted":
                statusBanner(
                    text: "You are in. Waiting on others...",
                    foreground: FriendZoneTheme.Colors.primary,
                    background: FriendZoneTheme.Colors.primarySoft
                )
            case "declined":
                statusBanner(
                    text: "You passed on this one",
                    foreground: FriendZoneTheme.Colors.textTertiary,
                    background: Color.black.opacity(0.03)
                )
            default:
                EmptyView()
            }
        }
    }

    private func statusBanner(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FriendZoneTheme.Spacing.sm)
            .frame(height: 44)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
    }

    private func badgeLabel(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, FriendZoneTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(FriendZoneTheme.Colors.surfaceMuted)
            .clipShape(Capsule())
    }

    private func shortDate(_ isoString: String) -> String {
        guard let date = ISODateParser.parse(isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    private func matchSummary(_ match: AmbitionMatch) -> String {
        let usernames = (match.otherMembers ?? []).map { $0.user.username }
        if usernames.isEmpty {
            return "Waiting for participants"
        }
        return usernames.prefix(3).joined(separator: ", ")
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, h:mm a"
        return formatter.string(from: date)
    }

    private func openHangout(id: Int) {
        presentedHangoutRoute = HangoutRoute(id: id)
    }
}

private struct FlowStepView: View {
    let step: FlowStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: step.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(step.accent)
                .padding(12)
                .background(step.accent.opacity(0.14))
                .clipShape(Circle())

            Text(step.title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(step.detail)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }
}

private struct FlowStep: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let detail: String
    let accent: Color
}

private struct SampleFlowItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let badge: String
    let participants: String
    let accentColor: Color
}
