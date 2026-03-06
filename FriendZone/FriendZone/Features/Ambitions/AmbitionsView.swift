import SwiftUI

private struct HangoutRoute: Identifiable {
    let id: Int

    var path: String {
        "/hangout/\(id)"
    }
}

struct AmbitionsView: View {
    @StateObject private var viewModel = AmbitionsViewModel()
    @State private var activeSection: AmbitionsSection = .ambition
    @State private var presentedHangoutRoute: HangoutRoute?

    var body: some View {
        VStack(spacing: 0) {
            heroHeader
            overviewRow
            mainPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(FriendZoneTheme.Colors.background)
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
        .onChange(of: viewModel.pendingOpenHangoutID) { newValue in
            guard let hangoutID = newValue else { return }
            presentedHangoutRoute = HangoutRoute(id: hangoutID)
            viewModel.clearPendingHangoutOpen()
        }
        .sheet(item: $presentedHangoutRoute) { route in
            WebScreen(path: route.path)
        }
        .ignoresSafeArea(.container, edges: [.bottom])
    }

    private var heroHeader: some View {
        HStack(alignment: .top, spacing: FriendZoneTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                Text("What's the ")
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                + Text("move?")
                    .foregroundColor(FriendZoneTheme.Colors.primary)
            }
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XL, weight: .bold))

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(FriendZoneTheme.Colors.primary)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                        .frame(width: 36, height: 36)
                        .background(FriendZoneTheme.Colors.primarySoft)
                        .clipShape(Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh ambitions")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FriendZoneTheme.Spacing.lg)
        .padding(.top, FriendZoneTheme.Spacing.lg)
        .padding(.bottom, FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FriendZoneTheme.Colors.borderSubtle)
                .frame(height: FriendZoneTheme.BorderWidth.thin)
        }
    }

    private var overviewRow: some View {
        HStack(spacing: FriendZoneTheme.Spacing.sm) {
            overviewCard(label: "Live now", value: viewModel.totalActive)
            overviewCard(label: "Matches", value: viewModel.formingMatches.count)
            overviewCard(label: "Hangouts", value: viewModel.hangoutMatches.count)
        }
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
        .padding(.vertical, 10)
    }

    private func overviewCard(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            Text("\(value)")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            segmentedTabs

            if let errorMessage = viewModel.errorMessage {
                errorBanner(errorMessage)
            }

            pagedContent
        }
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
        .padding(.bottom, FriendZoneTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var segmentedTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                ForEach(AmbitionsSection.allCases) { section in
                    let isActive = section == activeSection
                    Button {
                        withAnimation(FriendZoneTheme.Motion.easeOutBack) {
                            activeSection = section
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon)
                                .font(.system(size: 16, weight: .semibold))

                            Text(section.title)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))

                            let count = viewModel.count(for: section)
                            if count > 0 {
                                Text("\(count)")
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                    .foregroundColor(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textPrimary)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(
                                        Capsule()
                                            .fill(isActive ? FriendZoneTheme.Colors.primarySoftBorder : FriendZoneTheme.Colors.borderSubtle)
                                    )
                            }
                        }
                        .foregroundColor(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textTertiary)
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                        .background(isActive ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surface)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(
                                    isActive ? FriendZoneTheme.Colors.primarySoftBorder : FriendZoneTheme.Colors.borderSubtle,
                                    lineWidth: FriendZoneTheme.BorderWidth.thin
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FriendZoneTheme.Spacing.md)
            .padding(.vertical, 9)
        }
        .scrollIndicators(.never)
        .background(FriendZoneTheme.Colors.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FriendZoneTheme.Colors.borderSubtle)
                .frame(height: FriendZoneTheme.BorderWidth.thin)
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
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FriendZoneTheme.Colors.borderSubtle)
                .frame(height: FriendZoneTheme.BorderWidth.thin)
        }
    }

    private var pagedContent: some View {
        TabView(selection: $activeSection) {
            ForEach(AmbitionsSection.allCases) { section in
                sectionPage(for: section)
                    .tag(section)
                    .padding(FriendZoneTheme.Spacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FriendZoneTheme.Colors.background)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    @ViewBuilder
    private func sectionPage(for section: AmbitionsSection) -> some View {
        switch section {
        case .ambition:
            if viewModel.ambitions.isEmpty {
                emptyState(for: section)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                        ForEach(viewModel.ambitions) { ambition in
                            ambitionCard(ambition)
                        }
                    }
                }
            }
        case .matches:
            if viewModel.formingMatches.isEmpty {
                emptyState(for: section)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                        ForEach(viewModel.formingMatches) { match in
                            matchCard(match)
                        }
                    }
                }
            }
        case .hangouts:
            if viewModel.hangoutMatches.isEmpty {
                emptyState(for: section)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                        ForEach(viewModel.hangoutMatches) { match in
                            hangoutCard(match)
                        }
                    }
                }
            }
        case .weekly:
            if viewModel.patterns.isEmpty {
                emptyState(for: section)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                        ForEach(viewModel.patterns) { pattern in
                            weeklyCard(pattern)
                        }
                    }
                }
            }
        }
    }

    private func ambitionCard(_ ambition: Ambition) -> some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
            Text(ambition.primaryInterest ?? "Ambition")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                capsule(ambition.vibe?.capitalized ?? "Vibe")
                if let cityName = ambition.cityName, !cityName.isEmpty {
                    capsule(cityName)
                }
                if let end = ambition.endAt {
                    capsule(shortDate(end))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
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
                if let status = match.status, !status.isEmpty {
                    capsule(status.capitalized)
                }
            }

            matchActionArea(for: match)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

            Text("Hangout #\(match.hangout ?? 0)")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.primary)

            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                if let cityName = match.cityName, !cityName.isEmpty {
                    capsule(cityName)
                }
                if let start = match.startAt {
                    capsule(shortDate(start))
                }
            }

            if let hangoutID = match.hangout {
                Button {
                    openHangout(id: hangoutID)
                } label: {
                    Text("Open Hangout")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }

    private func weeklyCard(_ pattern: RecurringAvailability) -> some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
            Text(pattern.vibe?.capitalized ?? "Weekly pattern")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(weeklySummary(pattern))
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .regular))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                if let cityName = pattern.cityName, !cityName.isEmpty {
                    capsule(cityName)
                }
                if let active = pattern.isActive {
                    capsule(active ? "Active" : "Paused")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("Open Hangout")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        } else {
            switch (match.userStatus ?? "suggested").lowercased() {
            case "suggested":
                if match.hangoutIsFull == true {
                    statusBanner(
                        text: "Full",
                        foreground: FriendZoneTokens.Colors.warningStrong,
                        background: FriendZoneTokens.Colors.warningSoft
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
                                Text("Not Interested")
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
                                Text("I'm In")
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
                    .padding(.top, 4)
                }
            case "accepted":
                statusBanner(
                    text: "You are in. Waiting for others...",
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
            .padding(.top, 4)
    }

    private func openHangout(id: Int) {
        presentedHangoutRoute = HangoutRoute(id: id)
    }

    private func emptyState(for section: AmbitionsSection) -> some View {
        VStack(spacing: FriendZoneTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(FriendZoneTheme.Colors.primarySoft)
                    .frame(width: 64, height: 64)
                Image(systemName: section.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
            }

            VStack(spacing: FriendZoneTheme.Spacing.sm) {
                Text(section.emptyTitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(section.emptySubtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
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

    private func weeklySummary(_ pattern: RecurringAvailability) -> String {
        let weekday = weekdayName(pattern.weekday)
        let start = pattern.startTime ?? "--:--"
        let end = pattern.endTime ?? "--:--"
        return "\(weekday) · \(start) - \(end)"
    }

    private func weekdayName(_ value: Int?) -> String {
        switch value {
        case 0: return "Mon"
        case 1: return "Tue"
        case 2: return "Wed"
        case 3: return "Thu"
        case 4: return "Fri"
        case 5: return "Sat"
        case 6: return "Sun"
        default: return "Weekday"
        }
    }
}

#Preview {
    AmbitionsView()
}
