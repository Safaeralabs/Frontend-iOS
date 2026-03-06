import SwiftUI
import Combine
import UIKit

struct HangoutsView: View {
    var usesExternalBackdrop: Bool = false
    var onRequestOpenMaps: (() -> Void)? = nil

    @StateObject private var viewModel = HangoutsViewModel()
    @State private var now = Date()
    @State private var isPresentingCreate = false
    @State private var isPresentingAdvancedFilters = false
    @State private var isPresentingProfile = false
    @State private var isPresentingSettings = false
    @State private var isPresentingNotifications = false
    @State private var isPresentingPlans = false
    @State private var selectedMode: DiscoveryMode = .hangouts
    @State private var selectedMenuHangout: HangoutItem?
    @State private var isShowingHangoutMenu = false
    @State private var isShowingReportAcknowledgement = false
    @State private var animateDayDots = false

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let calendar = Calendar.current

    private enum DiscoveryMode: String, CaseIterable, Identifiable {
        case hangouts
        case events
        case offers

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hangouts: return "Hangouts"
            case .events: return "Events"
            case .offers: return "Offers"
            }
        }
    }

    private struct DiscoveryEventItem: Identifiable {
        let id: Int
        let title: String
        let venue: String
        let startAt: Date
        let groups: Int
        let category: String
    }

    private struct DiscoveryOfferItem: Identifiable {
        let id: Int
        let title: String
        let venue: String
        let perk: String
        let validUntil: Date
        let spotsLeft: Int
    }

    private var mockEvents: [DiscoveryEventItem] {
        [
            DiscoveryEventItem(id: 401, title: "Midnight Neo-Soul Jam", venue: "Neon Hall", startAt: Date().addingTimeInterval(60 * 60 * 2), groups: 8, category: "Music"),
            DiscoveryEventItem(id: 402, title: "Street Art Walk", venue: "East Side Gallery", startAt: Date().addingTimeInterval(60 * 60 * 26), groups: 5, category: "Culture"),
            DiscoveryEventItem(id: 403, title: "Startup Open Mic", venue: "Werk Loft", startAt: Date().addingTimeInterval(60 * 60 * 50), groups: 12, category: "Networking")
        ]
        .sorted { $0.startAt < $1.startAt }
    }

    private var mockOffers: [DiscoveryOfferItem] {
        [
            DiscoveryOfferItem(id: 701, title: "2x1 Matcha Before 6PM", venue: "Mitte Bean Lab", perk: "Show FriendZone code at counter", validUntil: Date().addingTimeInterval(60 * 60 * 8), spotsLeft: 14),
            DiscoveryOfferItem(id: 702, title: "Rooftop Entry + Drink", venue: "Skyline Terrace", perk: "Fast lane + welcome cocktail", validUntil: Date().addingTimeInterval(60 * 60 * 30), spotsLeft: 6),
            DiscoveryOfferItem(id: 703, title: "Late Ramen Set", venue: "Ramen Shiro", perk: "Noodles + iced tea combo", validUntil: Date().addingTimeInterval(60 * 60 * 55), spotsLeft: 18)
        ]
        .sorted { $0.validUntil < $1.validUntil }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            backdrop

            VStack(spacing: 0) {
                topIcons
                header
                modeSwitch
                dayPicker
                sectionHeader
                content
            }

            if selectedMode == .hangouts {
                createFAB
            }
        }
        .background(usesExternalBackdrop ? Color.clear : FriendZoneTheme.Colors.background)
        .task {
            await viewModel.loadIfNeeded()
        }
        .onReceive(minuteTicker) { value in
            now = value
        }
        .fullScreenCover(isPresented: $isPresentingCreate) {
            CreateHangoutView(
                onCancel: { isPresentingCreate = false },
                onCreate: { draft in
                    viewModel.addCreatedHangout(from: draft)
                }
            )
        }
        .fullScreenCover(isPresented: $isPresentingProfile) {
            NavigationStack {
                NativeProfileHubView(
                    onClose: { isPresentingProfile = false }
                )
            }
        }
        .fullScreenCover(isPresented: $isPresentingSettings) {
            NavigationStack {
                NativeSettingsHubView(
                    onClose: { isPresentingSettings = false }
                )
            }
        }
        .fullScreenCover(isPresented: $isPresentingNotifications) {
            NavigationStack {
                NativeNotificationsHubView(
                    onClose: { isPresentingNotifications = false }
                )
            }
        }
        .fullScreenCover(isPresented: $isPresentingPlans) {
            NavigationStack {
                NativePlansHubView(
                    onClose: { isPresentingPlans = false }
                )
            }
        }
        .sheet(isPresented: $isPresentingAdvancedFilters) {
            HangoutsAdvancedFiltersSheet(
                filters: $viewModel.advancedFilters,
                onClose: { isPresentingAdvancedFilters = false },
                onReset: { viewModel.clearAdvancedFilters() }
            )
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Hangout actions",
            isPresented: $isShowingHangoutMenu,
            titleVisibility: .visible
        ) {
            Button("Report Hangout", role: .destructive) {
                selectedMenuHangout = nil
                isShowingReportAcknowledgement = true
                FriendZoneHaptics.lightImpact()
            }
            Button("Cancel", role: .cancel) {
                selectedMenuHangout = nil
            }
        } message: {
            if let title = selectedMenuHangout?.title {
                Text("What do you want to do with \"\(title)\"?")
            }
        }
        .alert("Report sent", isPresented: $isShowingReportAcknowledgement) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks. We will review this hangout.")
        }
        .animation(FriendZoneTheme.Motion.easeOutExpo, value: selectedMode)
        .animation(FriendZoneTheme.Motion.easeOutExpo, value: viewModel.selectedDay)
        .animation(FriendZoneTheme.Motion.easeOutExpo, value: viewModel.advancedFilters)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    guard let onRequestOpenMaps else { return }
                    let deltaX = value.translation.width
                    let deltaY = value.translation.height
                    let isHorizontal = abs(deltaX) > abs(deltaY) * 1.2
                    if isHorizontal, deltaX < -45 {
                        onRequestOpenMaps()
                    }
                }
        )
    }

    private var backdrop: some View {
        ZStack {
            if usesExternalBackdrop {
                Rectangle()
                    .fill(Color(hex: "#F3F4FA").opacity(0.94))
                .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(Color(hex: "#F3F4FA"))
                    .ignoresSafeArea()
            }
        }
    }

    private var topIcons: some View {
        HStack {
            Button {
                isPresentingProfile = true
            } label: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Text("U")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    }
                    .frame(width: 32, height: 32)
                    .padding(4)
                    .background(Color.white.opacity(0.82))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    isPresentingNotifications = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                        .frame(width: 40, height: 40)
                        .background(FriendZoneTheme.Colors.primarySoft)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(FriendZoneTheme.Colors.primarySoftBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    isPresentingPlans = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    isPresentingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("☀️")
                    .font(.system(size: 11))
                Text("BERLIN • \(clockLabel(now))")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1.1)
            }

            Button {
                isPresentingNotifications = true
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(FriendZoneTheme.Colors.primary)
                        .frame(width: 6, height: 6)
                        .overlay {
                            Circle()
                                .stroke(FriendZoneTheme.Colors.primary.opacity(0.32), lineWidth: 6)
                        }
                    Text("Live updates")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            ForEach(DiscoveryMode.allCases) { mode in
                let isActive = mode == selectedMode
                Button {
                    selectedMode = mode
                    FriendZoneHaptics.selection()
                } label: {
                    Text(mode.title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            isActive
                                ? LinearGradient(
                                    colors: [FriendZoneTheme.Colors.primary.opacity(0.15), FriendZoneTheme.Colors.primaryAccent.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(colors: [Color.white.opacity(0.72), Color.white.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(
                                    isActive ? FriendZoneTheme.Colors.primarySoftBorder : FriendZoneTheme.Colors.borderSubtle,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
        .padding(.bottom, 8)
    }

    private var sectionHeader: some View {
        HStack {
            Text(sectionTitle)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(2)

            Spacer()

            if selectedMode == .hangouts {
                Button {
                    isPresentingAdvancedFilters = true
                    FriendZoneHaptics.selection()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                        if viewModel.advancedFiltersActiveCount > 0 {
                            Text("\(viewModel.advancedFiltersActiveCount)")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        } else {
                            Text("Filters")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                        }
                    }
                    .foregroundColor(viewModel.hasAdvancedFilters ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(viewModel.hasAdvancedFilters ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surface)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(viewModel.hasAdvancedFilters ? FriendZoneTheme.Colors.primarySoftBorder : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
        .padding(.bottom, FriendZoneTheme.Spacing.sm)
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                ForEach(viewModel.weekDays, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: viewModel.selectedDay)
                    let hasItems = hasItems(for: day)
                    Button {
                        withAnimation(FriendZoneTheme.Motion.easeOutExpo) {
                            viewModel.selectedDay = day
                        }
                        FriendZoneHaptics.selection()
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayLabel(day))
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            Text(dateNumber(day))
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                            Circle()
                                .fill(isSelected ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.primary)
                                .frame(width: 4, height: 4)
                                .scaleEffect(animateDayDots && hasItems ? 1.2 : 1)
                                .opacity(hasItems ? 1 : 0)
                                .opacity(animateDayDots && hasItems ? 0.6 : 1)
                                .animation(
                                    hasItems
                                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                                        : .easeOut(duration: 0.1),
                                    value: animateDayDots
                                )
                        }
                        .foregroundColor(isSelected ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.textSecondary)
                        .frame(width: 42, height: 68)
                        .background(isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.surface)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(
                                    isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle,
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: isSelected ? FriendZoneTheme.Colors.primary.opacity(0.18) : Color.clear, radius: 8, x: 0, y: 4)
                        .scaleEffect(isSelected ? 1.02 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FriendZoneTheme.Spacing.md)
            .padding(.vertical, 3)
        }
        .padding(.bottom, 8)
        .onAppear {
            animateDayDots = true
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        HangoutCardSkeleton()
                    }
                }
                .padding(.horizontal, FriendZoneTheme.Spacing.md)
                .padding(.bottom, 28)
            }
        } else {
            switch selectedMode {
            case .hangouts:
                hangoutsContent
            case .events:
                eventsContent
            case .offers:
                offersContent
            }
        }
    }

    private var hangoutsContent: some View {
        let dayItems = viewModel.hangouts(on: viewModel.selectedDay)
        let listItems = dayItems.isEmpty ? Array(viewModel.futureHangouts.prefix(5)) : dayItems

        return Group {
            if viewModel.futureHangouts.isEmpty {
                VStack(spacing: FriendZoneTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(FriendZoneTheme.Colors.primarySoft)
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                    }

                    Text("No hangouts in your city yet")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Button("Create Hangout") {
                        isPresentingCreate = true
                        FriendZoneHaptics.selection()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(FriendZoneTheme.Spacing.md)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                        ForEach(listItems) { hangout in
                            let joinStatus = viewModel.joinStatus(for: hangout)
                            ZStack(alignment: .topTrailing) {
                                NavigationLink {
                                    HangoutDetailView(
                                        hangout: hangout,
                                        joinStatus: joinStatus,
                                        onRequestJoin: {
                                            viewModel.requestJoin(for: hangout)
                                            FriendZoneHaptics.success()
                                        },
                                        onCancelRequest: {
                                            viewModel.cancelJoinRequest(for: hangout)
                                            FriendZoneHaptics.selection()
                                        }
                                    )
                                } label: {
                                    HangoutCardView(hangout: hangout, now: now)
                                }
                                .buttonStyle(HangoutCardButtonStyle())
                                .simultaneousGesture(
                                    TapGesture().onEnded {
                                        FriendZoneHaptics.lightImpact()
                                    }
                                )

                                Button {
                                    selectedMenuHangout = hangout
                                    isShowingHangoutMenu = true
                                    FriendZoneHaptics.selection()
                                } label: {
                                    Image(systemName: "ellipsis.vertical")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                        .frame(width: 22, height: 22)
                                        .background(Color.black.opacity(0.02))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, HangoutCardMetrics.contentPadding)
                                .padding(.top, HangoutCardMetrics.contentPadding + 2)
                                .zIndex(2)
                            }
                        }
                    }
                    .padding(.horizontal, FriendZoneTheme.Spacing.md)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var eventsContent: some View {
        let dayItems = mockEvents.filter { calendar.isDate($0.startAt, inSameDayAs: viewModel.selectedDay) }
        let listItems = dayItems.isEmpty ? Array(mockEvents.prefix(5)) : dayItems

        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                ForEach(listItems) { event in
                    eventCard(event)
                }
            }
            .padding(.horizontal, FriendZoneTheme.Spacing.md)
            .padding(.bottom, 28)
        }
    }

    private var offersContent: some View {
        let dayItems = mockOffers.filter { calendar.isDate($0.validUntil, inSameDayAs: viewModel.selectedDay) }
        let listItems = dayItems.isEmpty ? mockOffers : dayItems

        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                ForEach(listItems) { offer in
                    offerCard(offer)
                }
            }
            .padding(.horizontal, FriendZoneTheme.Spacing.md)
            .padding(.bottom, 28)
        }
    }

    private func eventCard(_ event: DiscoveryEventItem) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#0E7490"))

                    Text("EVENT PASS")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.7)

                    Spacer()

                    Text(event.category.uppercased())
                        .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                        .foregroundColor(Color(hex: "#0E7490"))
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(Color(hex: "#0E7490").opacity(0.10))
                        .clipShape(Capsule())
                }

                Text(event.title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text("by \(event.venue)")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                Text("🗓 \(eventDayLabel(event.startAt)) · \(timeLabel(event.startAt))")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                Text("\(event.groups) hangouts forming")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                ForEach(0 ..< 14, id: \.self) { _ in
                    Circle()
                        .fill(Color(hex: "#0E7490").opacity(0.24))
                        .frame(width: 2.2, height: 2.2)
                }
            }
            .frame(width: 3)
            .padding(.horizontal, 8)

            VStack(spacing: 2) {
                Text(dayLabel(event.startAt))
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(0.6)

                Text(dateNumber(event.startAt))
                    .font(FriendZoneTheme.Typography.system(24, weight: .heavy))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(timeLabel(event.startAt))
                    .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                    .foregroundColor(Color(hex: "#0E7490"))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 64)
        }
        .padding(14)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#0E7490").opacity(0.24), lineWidth: 1.2)
        }
        .overlay {
            GeometryReader { proxy in
                let r: CGFloat = 8
                let y = proxy.size.height * 0.5
                ZStack {
                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: r * 2, height: r * 2)
                        .position(x: 0, y: y)
                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: r * 2, height: r * 2)
                        .position(x: proxy.size.width, y: y)
                }
            }
        }
    }

    private func offerCard(_ offer: DiscoveryOfferItem) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("VOUCHER")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(Color(hex: "#B45309"))
                        .padding(.horizontal, 8)
                        .frame(height: 18)
                        .background(Color(hex: "#F59E0B").opacity(0.14))
                        .clipShape(Capsule())

                    Text(offer.venue)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                    Spacer()
                }

                Text(offer.title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(offer.perk)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                Text("Valid until \(eventDayLabel(offer.validUntil))")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                ForEach(0 ..< 14, id: \.self) { _ in
                    Circle()
                        .fill(Color(hex: "#F59E0B").opacity(0.32))
                        .frame(width: 2.2, height: 2.2)
                }
            }
            .frame(width: 3)
            .padding(.horizontal, 8)

            VStack(spacing: 6) {
                Text(offerCouponCode(offer))
                    .font(FriendZoneTheme.Typography.system(18, weight: .heavy))
                    .foregroundColor(Color(hex: "#B45309"))

                Text("COUPON")
                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(0.6)

                Text(offer.spotsLeft > 0 ? "\(offer.spotsLeft) LEFT" : "FULL")
                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                    .foregroundColor(offer.spotsLeft > 0 ? Color(hex: "#B45309") : FriendZoneTheme.Colors.error)
            }
            .frame(width: 74)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFF8E6"), FriendZoneTheme.Colors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [6, 4]))
                .foregroundColor(Color(hex: "#F59E0B").opacity(0.58))
        }
        .overlay {
            GeometryReader { proxy in
                let r: CGFloat = 9
                let y = proxy.size.height * 0.5
                ZStack {
                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: r * 2, height: r * 2)
                        .position(x: 0, y: y)
                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: r * 2, height: r * 2)
                        .position(x: proxy.size.width, y: y)
                }
            }
        }
    }

    private func offerCouponCode(_ offer: DiscoveryOfferItem) -> String {
        let title = offer.title.uppercased()
        if title.contains("2X1") { return "2x1" }
        if title.contains("ROOFTOP") { return "VIP" }
        if title.contains("RAMEN") { return "LATE" }
        return "DEAL"
    }

    private var createFAB: some View {
        Button {
            isPresentingCreate = true
            FriendZoneHaptics.selection()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(FriendZoneTheme.Colors.primary)
                .clipShape(Circle())
                .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, 96)
    }

    private var sectionTitle: String {
        switch selectedMode {
        case .hangouts:
            let selectedDayItems = viewModel.hangouts(on: viewModel.selectedDay)
            return (selectedDayItems.isEmpty && !viewModel.futureHangouts.isEmpty) ? "UPCOMING HANGOUTS" : "HAPPENING TODAY"
        case .events:
            let selectedDayItems = mockEvents.filter { calendar.isDate($0.startAt, inSameDayAs: viewModel.selectedDay) }
            return (selectedDayItems.isEmpty && !mockEvents.isEmpty) ? "UPCOMING EVENTS" : "EVENTS TODAY"
        case .offers:
            return "OFFERS"
        }
    }

    private func hasItems(for day: Date) -> Bool {
        switch selectedMode {
        case .hangouts:
            return viewModel.hasHangouts(on: day)
        case .events:
            return mockEvents.contains(where: { calendar.isDate($0.startAt, inSameDayAs: day) })
        case .offers:
            return mockOffers.contains(where: { calendar.isDate($0.validUntil, inSameDayAs: day) })
        }
    }

    private func clockLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func dayLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: value).uppercased()
    }

    private func eventDayLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: value)
    }

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func dateNumber(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: value)
    }
}

private struct HangoutCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct HangoutCardView: View {
    let hangout: HangoutItem
    let now: Date

    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 0) {
            leftContent
                .padding(.leading, HangoutCardMetrics.contentPadding)
                .padding(.trailing, 9)
                .padding(.vertical, HangoutCardMetrics.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)

            perforationStrip
                .padding(.vertical, 12)

            rightStub
                .frame(width: HangoutCardMetrics.stubWidth)
                .padding(.leading, 8)
                .padding(.trailing, HangoutCardMetrics.contentPadding)
                .padding(.vertical, HangoutCardMetrics.contentPadding)
        }
        .frame(maxWidth: .infinity, minHeight: HangoutCardMetrics.minHeight)
        .background(FriendZoneTheme.Colors.surface)
        .mask(ticketClipMask)
        .overlay {
            RoundedRectangle(cornerRadius: HangoutCardMetrics.cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: FriendZoneTheme.BorderWidth.thin)
                .mask(ticketClipMask)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 14)
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(.spring(response: 0.44, dampingFraction: 0.86).delay(Double(hangout.id % 5) * 0.025)) {
                hasAppeared = true
            }
        }
    }

    private var leftContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ticketTopLabel
                .padding(.bottom, 8)

            if let coverUIImage {
                coverStrip(coverUIImage)
                    .padding(.bottom, 10)
            }

            Text(hangout.title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 5)

            Text(hangout.description)
                .font(FriendZoneTheme.Typography.system(11, weight: .regular))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineLimit(1)
                .padding(.bottom, 9)

            cityVenueRow
                .padding(.bottom, 9)

            hostInfoRow
                .padding(.bottom, 7)

            footerRow
        }
    }

    private func coverStrip(_ image: Image) -> some View {
        ZStack {
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.clear, Color.black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(height: 58)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var cityVenueRow: some View {
        Text("TBA")
            .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
    }

    private var ticketTopLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accentColor)

            Text("HANGOUT PASS")
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.8)
        }
    }

    private var perforationStrip: some View {
        VStack(spacing: 4) {
            ForEach(0 ..< 18, id: \.self) { _ in
                Circle()
                    .fill(FriendZoneTheme.Colors.borderSubtle.opacity(0.95))
                    .frame(width: 2.5, height: 2.5)
            }
        }
        .frame(width: 3)
    }

    private var rightStub: some View {
        VStack(spacing: 7) {
            Text(timeRemainingText(from: now, to: hangout.startAt) ?? "SOON")
                .font(FriendZoneTheme.Typography.system(17, weight: .heavy))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(accentColor.opacity(0.14))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(accentColor.opacity(0.28), lineWidth: 1)
                }

            Text(timeLabel(hangout.startAt))
                .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(shortDateLabel(hangout.startAt))
                .font(FriendZoneTheme.Typography.system(9, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(hangout.isFull ? "Full" : "\(hangout.spotsLeft) Left")
                .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                .foregroundColor(hangout.isFull ? FriendZoneTheme.Colors.error : accentColor)
                .padding(.top, 2)

            ticketBarcode

            Text(ticketCode)
                .font(FriendZoneTheme.Typography.system(8, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var ticketBarcode: some View {
        HStack(alignment: .bottom, spacing: 0.8) {
            ForEach(Array(barcodeBars.enumerated()), id: \.offset) { _, bar in
                Rectangle()
                    .fill(Color.black.opacity(bar.opacity))
                    .frame(width: bar.width, height: bar.height)
            }
        }
        .frame(height: 24, alignment: .bottom)
    }

    private var ticketClipMask: some View {
        RoundedRectangle(cornerRadius: HangoutCardMetrics.cornerRadius, style: .continuous)
            .fill(Color.white)
            .overlay {
                ticketPunchHoles
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    private var ticketPunchHoles: some View {
        GeometryReader { proxy in
            let sideRadius = HangoutCardMetrics.edgeScallopRadius
            let centerRadius = HangoutCardMetrics.notchRadius
            let centerX = proxy.size.width * 0.5
            let topInset: CGFloat = 14
            let bottomInset: CGFloat = 14
            let usableHeight = max(0, proxy.size.height - topInset - bottomInset)
            let step = usableHeight / CGFloat(max(1, HangoutCardMetrics.edgeScallopCount - 1))

            ZStack {
                ForEach(0 ..< HangoutCardMetrics.edgeScallopCount, id: \.self) { index in
                    let y = topInset + CGFloat(index) * step

                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: sideRadius * 2, height: sideRadius * 2)
                        .position(x: 0, y: y)

                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: sideRadius * 2, height: sideRadius * 2)
                        .position(x: proxy.size.width, y: y)
                }

                Circle()
                    .fill(FriendZoneTheme.Colors.background)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: centerX, y: 0)

                Circle()
                    .fill(FriendZoneTheme.Colors.background)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: centerX, y: proxy.size.height)
            }
        }
    }

    private var hostInfoRow: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor.opacity(0.38))
                .frame(width: 2)

            HStack(spacing: 4) {
                Text(hangout.hostName.lowercased() == "you" ? "👑" : "🎯")
                Text("Hosted by \(hangout.hostName)")
            }
            .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
            .foregroundColor(hangout.hostName.lowercased() == "you" ? accentColor : FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.sm, style: .continuous))
    }

    private var footerRow: some View {
        HStack(alignment: .center) {
            participantRow

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
    }

    private var participantRow: some View {
        Group {
            if hangout.participantNames.isEmpty {
                Text("No participants so far")
                    .font(FriendZoneTheme.Typography.system(9, weight: .regular))
                    .italic()
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            } else {
                HStack(spacing: -8) {
                    ForEach(Array(hangout.participantNames.prefix(3).enumerated()), id: \.offset) { _, name in
                        participantAvatar(name)
                    }
                    if hangout.participantNames.count > 3 {
                        Text("+\(hangout.participantNames.count - 3)")
                            .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(FriendZoneTheme.Colors.surface, lineWidth: 2)
                            }
                    }
                }
            }
        }
    }

    private func participantAvatar(_ name: String) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textInverse)
            .frame(width: 26, height: 26)
            .background(
                LinearGradient(
                    colors: [accentColor, FriendZoneTheme.Colors.primaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .overlay {
                Circle().stroke(FriendZoneTheme.Colors.surface, lineWidth: 2)
            }
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

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func shortDateLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: value).uppercased()
    }

    private var cityCode: String {
        let normalized = hangout.cityName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let knownCodes: [String: String] = [
            "munich": "MUC",
            "munchen": "MUC",
            "münchen": "MUC",
            "berlin": "BER",
            "madrid": "MAD",
            "barcelona": "BCN",
            "paris": "PAR",
            "london": "LON",
            "lisbon": "LIS",
            "rome": "ROM",
            "amsterdam": "AMS",
            "new york": "NYC",
            "los angeles": "LAX",
            "miami": "MIA"
        ]
        if let code = knownCodes[normalized] {
            return code
        }
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        if compact.isEmpty {
            return "CITY"
        }
        return String(compact.prefix(3)).uppercased()
    }

    private var coverUIImage: Image? {
        guard let data = hangout.coverImageData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private var ticketCode: String {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: hangout.startAt)
        let day = String(format: "%02d", components.day ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let year = String(components.year ?? 0)
        return "\(cityCode)-\(day)-\(month)-\(hangout.id)-\(year)"
    }

    private var barcodeBars: [(width: CGFloat, height: CGFloat, opacity: CGFloat)] {
        let base = "\(ticketCode)|\(hangout.startAt.timeIntervalSince1970)|\(hangout.hostName)"
        var result: [(width: CGFloat, height: CGFloat, opacity: CGFloat)] = []
        let widths: [CGFloat] = [0.8, 1.2, 1.6]

        // Start guard
        result.append((1.8, 24, 0.9))
        result.append((0.8, 18, 0.88))
        result.append((1.8, 24, 0.9))

        for (index, byte) in base.utf8.prefix(28).enumerated() {
            let value = Int(byte)
            let width = widths[value % widths.count]
            let height: CGFloat
            switch value % 5 {
            case 0: height = 24
            case 1: height = 22
            case 2: height = 20
            case 3: height = 23
            default: height = 21
            }
            let opacity: CGFloat = index.isMultiple(of: 7) ? 0.95 : 0.88
            result.append((width, height, opacity))

            if index == 13 {
                // Center guard
                result.append((1.8, 24, 0.9))
                result.append((0.8, 18, 0.88))
                result.append((1.8, 24, 0.9))
            }
        }

        // End guard
        result.append((1.8, 24, 0.9))
        result.append((0.8, 18, 0.88))
        result.append((1.8, 24, 0.9))

        while result.count < 40 {
            result.append((1.0, 20, 0.85))
        }
        return result
    }

    private var accentColor: Color {
        switch hangout.vibe {
        case .chill: return Color(hex: "#667EEA")
        case .drinks: return Color(hex: "#F59E0B")
        case .deepTalk: return Color(hex: "#8B5CF6")
        case .activity: return Color(hex: "#10B981")
        case .foodie: return Color(hex: "#EF4444")
        case .sporty: return Color(hex: "#0EA5E9")
        }
    }

}

private struct HangoutCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FriendZoneTheme.Colors.surfaceMuted)
                .frame(width: 150, height: 16)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FriendZoneTheme.Colors.surfaceMuted)
                .frame(height: 14)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FriendZoneTheme.Colors.surfaceMuted)
                .frame(height: 11)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FriendZoneTheme.Colors.surfaceMuted)
                .frame(width: 120, height: 22)
        }
        .padding(11)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }
}

private enum HangoutCardMetrics {
    static let contentPadding: CGFloat = 11
    static let cornerRadius: CGFloat = 16
    static let minHeight: CGFloat = 184
    static let stubWidth: CGFloat = 88
    static let notchRadius: CGFloat = 10
    static let edgeScallopRadius: CGFloat = 5.2
    static let edgeScallopCount: Int = 9
}

private struct NativeProfileView: View {
    let onClose: () -> Void
    @State private var showPastHangouts = true
    @State private var showCity = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 82, height: 82)
                        .overlay {
                            Text("S")
                                .font(FriendZoneTheme.Typography.system(32, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        }

                    Text("safaeralabs")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(showCity ? "Berlin, DE" : "City hidden")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    profileStatCard(title: "Attended", value: "37")
                    profileStatCard(title: "Hosted", value: "12")
                    profileStatCard(title: "Rating", value: "4.9")
                }

                VStack(spacing: 10) {
                    NavigationLink {
                        NativeEditProfileView()
                    } label: {
                        profileRowLabel(
                            icon: "pencil.circle.fill",
                            title: "Edit profile",
                            subtitle: "Name, bio, city and preferences"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NativeMessagesView()
                    } label: {
                        profileRowLabel(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Messages",
                            subtitle: "Recent conversations and requests"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NativeSettingsView(onClose: onClose)
                    } label: {
                        profileRowLabel(
                            icon: "gearshape.fill",
                            title: "Settings",
                            subtitle: "Privacy, account and notifications"
                        )
                    }
                    .buttonStyle(.plain)

                    profileToggleRow(
                        icon: "clock.arrow.circlepath",
                        title: "Show past hangouts",
                        subtitle: "Display history on your profile",
                        isOn: $showPastHangouts
                    )

                    profileToggleRow(
                        icon: "mappin.circle.fill",
                        title: "Show city",
                        subtitle: "Visible to people in matches and hangouts",
                        isOn: $showCity
                    )
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private func profileStatCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func profileRowLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func profileToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(FriendZoneTheme.Colors.primary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativeSettingsView: View {
    let onClose: () -> Void
    @State private var pushNotifications = true
    @State private var reminderNotifications = true
    @State private var soundEffects = true
    @State private var haptics = true
    @State private var privateAccount = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                settingsSection(
                    title: "Notifications",
                    rows: [
                        .toggle("Push notifications", "New matches and join requests", $pushNotifications),
                        .toggle("Reminders", "Upcoming hangouts and events", $reminderNotifications)
                    ]
                )

                settingsSection(
                    title: "Experience",
                    rows: [
                        .toggle("Sound effects", "UI interaction sounds", $soundEffects),
                        .toggle("Haptics", "Subtle vibration feedback", $haptics)
                    ]
                )

                settingsSection(
                    title: "Privacy",
                    rows: [
                        .toggle("Private account", "Only accepted people can see details", $privateAccount)
                    ]
                )

                VStack(spacing: 10) {
                    NavigationLink {
                        NativeHelpView()
                    } label: {
                        settingsNavRow(
                            icon: "questionmark.circle.fill",
                            title: "Help Center",
                            subtitle: "FAQs and how FriendZone works"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NativePrivacyView()
                    } label: {
                        settingsNavRow(
                            icon: "lock.shield.fill",
                            title: "Privacy Policy",
                            subtitle: "How we store and process your data"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NativeTermsView()
                    } label: {
                        settingsNavRow(
                            icon: "doc.text.fill",
                            title: "Terms of Service",
                            subtitle: "Rules and legal terms"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                } label: {
                    Text("Log out")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(FriendZoneTheme.Colors.error)
            }
            .padding(16)
            .padding(.bottom, 22)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private func settingsSection(title: String, rows: [SettingsRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            Text(row.subtitle)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        }
                        Spacer()
                        Toggle("", isOn: row.binding)
                            .labelsHidden()
                            .tint(FriendZoneTheme.Colors.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if row.id != rows.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        }
    }

    private func settingsNavRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativeNotificationsView: View {
    let onClose: () -> Void

    private let items: [NotificationItem] = [
        .init(id: 1, icon: "person.2.fill", tone: .primary, title: "New match forming", detail: "3 people are in for Coffee and Co-Work", time: "2m"),
        .init(id: 2, icon: "checkmark.seal.fill", tone: .success, title: "Join request approved", detail: "You are accepted in Street Photo Walk", time: "14m"),
        .init(id: 3, icon: "bell.badge.fill", tone: .warning, title: "Hangout starts soon", detail: "Sunset Rooftop Drinks starts in 30 min", time: "31m")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(toneColor(item.tone))
                            .frame(width: 34, height: 34)
                            .background(toneColor(item.tone).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            Text(item.detail)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        }

                        Spacer()

                        Text(item.time)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }
                    .padding(12)
                    .background(FriendZoneTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 22)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private func toneColor(_ tone: NotificationTone) -> Color {
        switch tone {
        case .primary: return FriendZoneTheme.Colors.primary
        case .success: return FriendZoneTheme.Colors.success
        case .warning: return FriendZoneTheme.Colors.warning
        }
    }
}

private struct NativePlansView: View {
    let onClose: () -> Void
    private let items = HangoutsMockData.sample().filter { $0.endAt > Date() }.sorted { $0.startAt < $1.startAt }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(items) { hangout in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(hangout.title)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(timeLabel(hangout.startAt))
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.primary)
                        }

                        Text(hangout.description)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(dayLabel(hangout.startAt))
                            Text("•")
                            Text(hangout.isJoined ? "Joined" : "Pending")
                            Text("•")
                            Text("\(hangout.spotsLeft) spots left")
                        }
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }
                    .padding(12)
                    .background(FriendZoneTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 22)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func dayLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: value)
    }
}

private struct NativeEditProfileView: View {
    @State private var username = "safaeralabs"
    @State private var displayName = "Safaera Labs"
    @State private var bio = "Building FriendZone iOS native experience."
    @State private var city = "Berlin"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                inputField("Username", text: $username)
                inputField("Display name", text: $displayName)
                inputField("City", text: $city)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Bio")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    TextEditor(text: $bio)
                        .font(.system(size: 15))
                        .frame(height: 120)
                        .padding(8)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }

                Button {
                } label: {
                    Text("Save changes")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func inputField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            TextField("", text: text)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
        }
    }
}

private struct NativeMessagesView: View {
    private let chats = [
        ("nina", "See you at the coffee sprint", "2m"),
        ("kai", "Rooftop plan still on?", "10m"),
        ("tina", "Great photos yesterday!", "42m"),
        ("leo", "Run group starts at 7", "1h")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(Array(chats.enumerated()), id: \.offset) { _, chat in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(FriendZoneTheme.Colors.primarySoft)
                            .frame(width: 38, height: 38)
                            .overlay {
                                Text(String(chat.0.prefix(1)).uppercased())
                                    .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                                    .foregroundColor(FriendZoneTheme.Colors.primary)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chat.0)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            Text(chat.1)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()
                        Text(chat.2)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }
                    .padding(12)
                    .background(FriendZoneTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                }
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativeHelpView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                faqItem("How do I join a hangout?", "Open any card and tap request. The host accepts participants.")
                faqItem("Why is location hidden?", "Location becomes visible only after acceptance for safety.")
                faqItem("How do I report someone?", "Use the ⋮ menu on cards or inside maps marker panel.")
                faqItem("Can I hide my profile details?", "Yes, in Settings > Privacy you can limit visibility.")
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faqItem(_ title: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(answer)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativePrivacyView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                legalBlock("Data we collect", "Account profile, activity interactions, and basic device diagnostics for performance.")
                legalBlock("Location usage", "Used to show nearby hangouts and maps. You can disable city visibility in profile controls.")
                legalBlock("Sharing", "We do not sell personal data. Limited sharing happens only to operate core features.")
                legalBlock("Control", "You can request data export and account deletion from Settings.")
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(body)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativeTermsView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                legalBlock("Respectful conduct", "Harassment, hate, and unsafe behavior are not allowed.")
                legalBlock("Real-world safety", "Meet in public places and follow local laws and venue rules.")
                legalBlock("User responsibility", "You are responsible for content and behavior on your account.")
                legalBlock("Enforcement", "Accounts may be restricted for serious or repeated violations.")
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(body)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct SettingsRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let binding: Binding<Bool>

    static func toggle(_ title: String, _ subtitle: String, _ binding: Binding<Bool>) -> SettingsRow {
        SettingsRow(title: title, subtitle: subtitle, binding: binding)
    }
}

private enum NotificationTone {
    case primary
    case success
    case warning
}

private struct NotificationItem: Identifiable {
    let id: Int
    let icon: String
    let tone: NotificationTone
    let title: String
    let detail: String
    let time: String
}

private struct NativeProfileHubView: View {
    let onClose: () -> Void

    private let vibes = [("☕", "Chill"), ("🍸", "Drinks"), ("💪", "Active"), ("🧠", "Deep Talk")]
    private let interests = ["Coffee", "Startups", "Music", "Food", "Photography", "Walking"]
    private let languages = ["EN", "ES", "DE"]
    private let moments = [Color(hex: "#6D28D9"), Color(hex: "#EC4899"), Color(hex: "#0EA5E9"), Color(hex: "#F97316"), Color(hex: "#10B981"), Color(hex: "#111827")]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                profileHero
                profileCard
                statsGrid
                quickActions
                chipsSection(title: "VIBES", items: vibes.map { "\($0.0) \($0.1)" })
                chipsSection(title: "INTERESTS", items: interests)
                chipsSection(title: "LANGUAGES", items: languages)
                momentsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private var profileHero: some View {
        HStack {
            Text("Your social ")
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            + Text("passport")
                .foregroundColor(FriendZoneTheme.Colors.primary)
        }
        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private var profileCard: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 92, height: 92)
                .overlay {
                    Text("S")
                        .font(FriendZoneTheme.Typography.system(34, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(FriendZoneTheme.Colors.surface)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.primary)
                        }
                }

            Text("Safaera Labs")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text("@safaeralabs")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            HStack(spacing: 8) {
                profileMetaChip("📍 Berlin")
                profileMetaChip("🎂 25")
            }

            HStack(spacing: 8) {
                NavigationLink {
                    NativeEditProfileView()
                } label: {
                    Text("✏️ Edit Profile")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
                        }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    NativeSettingsHubView(onClose: onClose)
                } label: {
                    Text("⚙️ Settings")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }

            Text("Building FriendZone iOS native experience.")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private var statsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            profileStat("🎉", "37", "ATTENDED")
            profileStat("🎯", "12", "HOSTED")
            profileStat("⭐", "4.9", "RATING")
            profileStat("👥", "128", "FOLLOWERS")
            profileStat("🤝", "204", "FOLLOWING")
        }
    }

    private var quickActions: some View {
        VStack(spacing: 10) {
            NavigationLink {
                NativeMessagesView()
            } label: {
                profileRow(icon: "bubble.left.and.bubble.right.fill", title: "Messages", subtitle: "Recent chats and requests")
            }
            .buttonStyle(.plain)

            NavigationLink {
                NativePlansHubView(onClose: onClose)
            } label: {
                profileRow(icon: "calendar", title: "My plans", subtitle: "Upcoming, hosting and past")
            }
            .buttonStyle(.plain)

            NavigationLink {
                NativeNotificationsHubView(onClose: onClose)
            } label: {
                profileRow(icon: "bell.fill", title: "Notifications", subtitle: "Unread updates and reminders")
            }
            .buttonStyle(.plain)
        }
    }

    private func profileMetaChip(_ title: String) -> some View {
        Text(title)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(FriendZoneTheme.Colors.surfaceMuted)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
    }

    private func profileStat(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Text(emoji)
                Text(value)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
            }
            Text(label)
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .tracking(0.6)
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func profileRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func chipsSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(1)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MOMENTS")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1)
                Spacer()
                Text("\(moments.count)/9")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(moments.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 98)
                }
            }
        }
    }
}

private struct NativeSettingsHubView: View {
    let onClose: () -> Void

    @State private var pushNotifications = true
    @State private var locationSharing = true
    @State private var showDistance = true
    @State private var privateAccount = true
    @State private var verificationNote = ""
    @State private var verificationStatus: SettingsVerificationState = .none

    private let hasCreatorRole = true
    private let isStaff = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerCard

                settingsSection(title: "Account") {
                    NavigationLink {
                        NativeChangePasswordHubView()
                    } label: {
                        settingsNavRow(icon: "lock.fill", title: "Change password", subtitle: "Update your password", showsChevron: true)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 58)

                    NavigationLink {
                        NativeEmailSettingsHubView()
                    } label: {
                        settingsNavRow(icon: "envelope.fill", title: "Email address", subtitle: "safaeralabs@example.com", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }

                settingsSection(title: "Verification") {
                    switch verificationStatus {
                    case .verified:
                        settingsStaticRow(icon: "checkmark.seal.fill", title: "Verified account", subtitle: "Your profile has a verification badge")
                    case .pending:
                        settingsStaticRow(icon: "hourglass.circle.fill", title: "Request pending", subtitle: "Your verification request is under review")
                    case .none:
                        VStack(alignment: .leading, spacing: 12) {
                            settingsStaticRow(icon: "sparkles", title: "Get verified", subtitle: "Apply for a verification badge on your profile")
                            TextEditor(text: $verificationNote)
                                .font(.system(size: 14))
                                .frame(height: 90)
                                .padding(10)
                                .background(FriendZoneTheme.Colors.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                                }
                            Button {
                                verificationStatus = .pending
                            } label: {
                                Text("Request verification")
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(FriendZoneTheme.Colors.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                    }
                }

                settingsSection(title: "Privacy") {
                    settingsToggleRow(icon: "location.fill", title: "Location sharing", subtitle: "Show your location to nearby users", isOn: $locationSharing)
                    Divider().padding(.leading, 58)
                    settingsToggleRow(icon: "arrow.left.and.right", title: "Show distance", subtitle: "Display distance on profile", isOn: $showDistance)
                    Divider().padding(.leading, 58)
                    settingsToggleRow(icon: "person.crop.circle.badge.xmark", title: "Private account", subtitle: "Only accepted people can see details", isOn: $privateAccount)
                    Divider().padding(.leading, 58)
                    NavigationLink {
                        NativeBlockedUsersHubView()
                    } label: {
                        settingsNavRow(icon: "nosign", title: "Blocked users", subtitle: "Manage blocked accounts", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }

                settingsSection(title: "Notifications") {
                    settingsToggleRow(icon: "bell.fill", title: "Push notifications", subtitle: "Get updates about hangouts", isOn: $pushNotifications)
                    Divider().padding(.leading, 58)
                    NavigationLink {
                        NativeNotificationPreferencesHubView()
                    } label: {
                        settingsNavRow(icon: "slider.horizontal.3", title: "Notification preferences", subtitle: "Customize what you receive", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }

                settingsSection(title: "Creator Program") {
                    if hasCreatorRole {
                        NavigationLink {
                            NativePlaceholderHubView(
                                title: "Creator Space",
                                message: "Manage your events, venues and offers."
                            )
                        } label: {
                            settingsNavRow(icon: "building.2.fill", title: "Creator space", subtitle: "Manage your creator dashboard", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 58)
                    }

                    NavigationLink {
                        NativePlaceholderHubView(
                            title: "Become a Creator",
                            message: "Apply as Event Creator or Venue Owner."
                        )
                    } label: {
                        settingsNavRow(icon: "rocket.fill", title: hasCreatorRole ? "Apply for more roles" : "Become a creator", subtitle: "Apply as Event Creator or Venue Owner", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }

                if isStaff {
                    settingsSection(title: "Admin") {
                        NavigationLink {
                            NativePlaceholderHubView(
                                title: "Role Requests",
                                message: "Review creator role applications."
                            )
                        } label: {
                            settingsNavRow(icon: "person.text.rectangle.fill", title: "Role requests", subtitle: "Review creator applications", showsChevron: true)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 58)

                        NavigationLink {
                            NativePlaceholderHubView(
                                title: "Verification Requests",
                                message: "Review user verification applications."
                            )
                        } label: {
                            settingsNavRow(icon: "checkmark.seal.fill", title: "Verification requests", subtitle: "Review user applications", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }

                settingsSection(title: "Support") {
                    NavigationLink {
                        NativeHelpView()
                    } label: {
                        settingsNavRow(icon: "questionmark.circle.fill", title: "Help center", subtitle: "Get help and FAQs", showsChevron: true)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 58)

                    NavigationLink {
                        NativeFeedbackHubView()
                    } label: {
                        settingsNavRow(icon: "bubble.left.fill", title: "Send feedback", subtitle: "Help us improve", showsChevron: true)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 58)

                    NavigationLink {
                        NativeReportProblemHubView()
                    } label: {
                        settingsNavRow(icon: "exclamationmark.triangle.fill", title: "Report a problem", subtitle: "Let us know about issues", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }

                settingsSection(title: "Legal") {
                    NavigationLink {
                        NativeTermsView()
                    } label: {
                        settingsNavRow(icon: "doc.text.fill", title: "Terms of service", subtitle: "Rules and legal terms", showsChevron: true)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 58)

                    NavigationLink {
                        NativePrivacyView()
                    } label: {
                        settingsNavRow(icon: "lock.shield.fill", title: "Privacy policy", subtitle: "How your data is handled", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }

                settingsSection(title: "About") {
                    VStack(spacing: 4) {
                        Text("FriendZone v1.0.0")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        Text("Copyright 2025 FriendZone Inc.")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }

                VStack(spacing: 10) {
                    Button("Log out") {}
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                        }
                        .buttonStyle(.plain)

                    Button("Delete account") {}
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTokens.Colors.errorStrong)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTokens.Colors.error.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTokens.Colors.error.opacity(0.24), lineWidth: 1.5)
                        }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 0) {
            Text("Your ")
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text("settings")
                .foregroundColor(FriendZoneTheme.Colors.primary)
        }
        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XL, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.5)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.90))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 2)
            }
            .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        }
    }

    private func settingsNavRow(icon: String, title: String, subtitle: String, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            iconWrap(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            Spacer()
            if showsChevron {
                Text("›")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func settingsStaticRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            iconWrap(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func settingsToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconWrap(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(FriendZoneTheme.Colors.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func iconWrap(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            .frame(width: 34, height: 34)
            .background(FriendZoneTheme.Colors.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
    }
}

private enum SettingsVerificationState {
    case none
    case pending
    case verified
}

private struct NativeNotificationsHubView: View {
    let onClose: () -> Void
    @State private var filter: HubNotificationFilter = .all
    @State private var items: [HubNotificationItem] = [
        HubNotificationItem(id: 1, title: "Join approved", message: "You were accepted in Coffee and Co-Work Sprint", timeAgo: "2m", icon: "checkmark.seal.fill", colorHex: "#10B981", isRead: false),
        HubNotificationItem(id: 2, title: "New join request", message: "Nora wants to join your Deep Talk Circle", timeAgo: "8m", icon: "person.2.fill", colorHex: "#8B5CF6", isRead: false),
        HubNotificationItem(id: 3, title: "Hangout starts soon", message: "Sunset Rooftop Drinks starts in 30 minutes", timeAgo: "31m", icon: "clock.fill", colorHex: "#F59E0B", isRead: true),
        HubNotificationItem(id: 4, title: "Ambition match", message: "A new weekly match aligns with your goals", timeAgo: "1h", icon: "sparkles", colorHex: "#3B82F6", isRead: true)
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabs
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(FriendZoneTheme.Colors.surface)

            if visibleItems.isEmpty {
                VStack(spacing: 10) {
                    Text("🔔")
                        .font(.system(size: 44))
                    Text(filter == .unread ? "You're all caught up!" : "No notifications yet")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text(filter == .unread ? "No unread notifications." : "We'll notify you when something happens.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 1) {
                        ForEach(visibleItems) { item in
                            notificationRow(item)
                        }
                    }
                    .background(FriendZoneTheme.Colors.surfaceMuted)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if unreadCount > 0 {
                    Button("Mark all read") {
                        for index in items.indices {
                            items[index].isRead = true
                        }
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }

    private var visibleItems: [HubNotificationItem] {
        switch filter {
        case .all:
            return items
        case .unread:
            return items.filter { !$0.isRead }
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            tabButton(title: "All", isActive: filter == .all, badge: nil) {
                filter = .all
            }
            tabButton(title: "Unread", isActive: filter == .unread, badge: unreadCount == 0 ? nil : "\(unreadCount)") {
                filter = .unread
            }
            Spacer()
        }
    }

    private func tabButton(title: String, isActive: Bool, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if let badge {
                    Text(badge)
                        .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(isActive ? Color.white.opacity(0.30) : FriendZoneTheme.Colors.error)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
            .foregroundColor(isActive ? .white : FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(isActive ? FriendZoneTheme.Colors.primary : Color.clear)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderDefault, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func notificationRow(_ item: HubNotificationItem) -> some View {
        Button {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].isRead = true
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color(hex: item.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: item.colorHex))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: item.isRead ? .medium : .semibold))
                        .foregroundColor(item.isRead ? FriendZoneTheme.Colors.textSecondary : FriendZoneTheme.Colors.textPrimary)
                    Text(item.message)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(item.timeAgo)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }

                Spacer(minLength: 0)

                if !item.isRead {
                    Circle()
                        .fill(FriendZoneTheme.Colors.primary)
                        .frame(width: 8, height: 8)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(item.isRead ? FriendZoneTheme.Colors.surface : Color(hex: "#FAFAFF"))
        }
        .buttonStyle(.plain)
    }
}

private enum HubNotificationFilter {
    case all
    case unread
}

private struct HubNotificationItem: Identifiable {
    let id: Int
    let title: String
    let message: String
    let timeAgo: String
    let icon: String
    let colorHex: String
    var isRead: Bool
}

private struct NativePlansHubView: View {
    let onClose: () -> Void
    @State private var selectedTab: PlansHubTab = .upcoming
    private let soloItems: [SoloPlanItem] = [
        SoloPlanItem(
            id: 8001,
            title: "Indie Cinema Night",
            startAt: Date().addingTimeInterval(60 * 60 * 36),
            venueName: "Kino Mitte",
            creatorName: "Event creator"
        ),
        SoloPlanItem(
            id: 8002,
            title: "Tech House Session",
            startAt: Date().addingTimeInterval(-60 * 60 * 50),
            venueName: "Neon Club",
            creatorName: "Event creator"
        )
    ]

    private var now: Date { Date() }

    private var allHangouts: [HangoutItem] {
        var items = HangoutsMockData.sample()
        if !items.contains(where: { $0.hostName.lowercased() == "you" }) {
            items.insert(
                HangoutItem(
                    id: 999,
                    sourceType: .hangout,
                    title: "Night Design Sprint",
                    description: "Co-create ideas and prototypes with other builders.",
                    vibe: .activity,
                    cityName: "Berlin",
                    locationName: "Prenzlauer Studio Loft",
                    hostName: "you",
                    startAt: now.addingTimeInterval(60 * 60 * 18),
                    endAt: now.addingTimeInterval(60 * 60 * 21),
                    capacity: 10,
                    approvedCount: 4,
                    isLive: false,
                    isMicro: false,
                    isJoined: true,
                    participantNames: ["Noa", "Lia", "Ben", "Mia"],
                    coverImageData: nil,
                    coverSeed: 10,
                    distanceKm: 2.1,
                    priceTier: .free
                ),
                at: 0
            )
        }
        return items
    }

    private var upcomingHangouts: [HangoutItem] {
        allHangouts
            .filter { $0.startAt > now && ($0.isJoined || $0.hostName.lowercased() == "you") }
            .sorted { $0.startAt < $1.startAt }
    }

    private var hostingHangouts: [HangoutItem] {
        allHangouts
            .filter { $0.startAt > now && $0.hostName.lowercased() == "you" }
            .sorted { $0.startAt < $1.startAt }
    }

    private var pastHangouts: [HangoutItem] {
        allHangouts
            .filter { $0.startAt <= now && ($0.isJoined || $0.hostName.lowercased() == "you") }
            .sorted { $0.startAt > $1.startAt }
    }

    private var upcomingSoloItems: [SoloPlanItem] {
        soloItems.filter { $0.startAt > now }.sorted { $0.startAt < $1.startAt }
    }

    private var pastSoloItems: [SoloPlanItem] {
        soloItems.filter { $0.startAt <= now }.sorted { $0.startAt > $1.startAt }
    }

    private var currentEntries: [PlansHubEntry] {
        switch selectedTab {
        case .upcoming:
            let entries = upcomingHangouts.map { PlansHubEntry.hangout($0) } + upcomingSoloItems.map { PlansHubEntry.solo($0) }
            return entries.sorted(by: { $0.date < $1.date })
        case .hosting:
            return hostingHangouts.map { PlansHubEntry.hangout($0) }.sorted(by: { $0.date < $1.date })
        case .past:
            let entries = pastHangouts.map { PlansHubEntry.hangout($0) } + pastSoloItems.map { PlansHubEntry.solo($0) }
            return entries.sorted(by: { $0.date > $1.date })
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                headerCard
                tabSwitch
                if currentEntries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(currentEntries.enumerated()), id: \.offset) { _, entry in
                            switch entry {
                            case let .hangout(hangout):
                                hangoutPlanCard(hangout)
                            case let .solo(event):
                                soloEventCard(event)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private var headerCard: some View {
        HStack {
            Text("My ")
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            + Text("Plans")
                .foregroundColor(FriendZoneTheme.Colors.primary)
        }
        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var tabSwitch: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.78))
                .overlay {
                    Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }

            GeometryReader { proxy in
                let innerWidth = max(0, proxy.size.width - 8)
                let tabWidth = innerWidth / 3
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary.opacity(0.16), FriendZoneTheme.Colors.primaryAccent.opacity(0.24)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: tabWidth, height: 34)
                    .overlay {
                        Capsule().stroke(FriendZoneTheme.Colors.primary.opacity(0.25), lineWidth: 1)
                    }
                    .offset(x: 4 + tabWidth * CGFloat(selectedTab.index), y: 4)
                    .animation(FriendZoneTheme.Motion.easeOutExpo, value: selectedTab)
            }

            HStack(spacing: 4) {
                planTabButton(.upcoming, count: upcomingHangouts.count + upcomingSoloItems.count)
                planTabButton(.hosting, count: hostingHangouts.count)
                planTabButton(.past, count: pastHangouts.count + pastSoloItems.count)
            }
            .padding(4)
        }
        .frame(height: 42)
    }

    private func planTabButton(_ tab: PlansHubTab, count: Int) -> some View {
        let active = selectedTab == tab
        return Button {
            selectedTab = tab
            FriendZoneHaptics.selection()
        } label: {
            HStack(spacing: 5) {
                Text(tab.title)
                if count > 0 {
                    Text("\(count)")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(active ? Color.white.opacity(0.3) : Color.black.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
            .foregroundColor(active ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary.opacity(0.10), FriendZoneTheme.Colors.primaryAccent.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay {
                    Text(selectedTab.icon)
                        .font(.system(size: 42))
                }
            Text(selectedTab.emptyTitle)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(selectedTab.emptyDescription)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button(selectedTab.emptyButtonTitle) {}
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                .padding(.horizontal, 26)
                .frame(height: 42)
                .background(
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
    }

    private func hangoutPlanCard(_ hangout: HangoutItem) -> some View {
        let happening = now >= hangout.startAt && now <= hangout.endAt
        let isPast = selectedTab == .past
        let isHost = hangout.hostName.lowercased() == "you"

        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(happening ? FriendZoneTheme.Colors.success : vibeColor(hangout.vibe))
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(vibeColor(hangout.vibe))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text(vibeEmoji(hangout.vibe))
                                .font(.system(size: 18))
                        }
                        .opacity(isPast ? 0.70 : 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hangout.title)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .lineLimit(1)

                        Text("\(dateLabel(hangout.startAt)) · \(timeLabel(hangout.startAt)) · \(hangout.locationDisplay)")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if happening {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(FriendZoneTheme.Colors.success)
                                .frame(width: 6, height: 6)
                            Text("NOW")
                        }
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.success)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(FriendZoneTheme.Colors.success.opacity(0.14))
                        .clipShape(Capsule())
                    } else {
                        Text(timeUntil(hangout.startAt, isPast: isPast))
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(isPast ? FriendZoneTheme.Colors.textTertiary : FriendZoneTheme.Colors.primary)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(isPast ? Color.black.opacity(0.05) : FriendZoneTheme.Colors.primarySoft)
                            .clipShape(Capsule())
                    }
                }
                .padding(.leading, 18)
                .padding(.trailing, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)

                Divider()
                    .padding(.leading, 18)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: isHost ? "sparkles" : "person.3.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(isHost ? "Hosting" : "Attending")
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                    .foregroundColor(isHost ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background((isHost ? FriendZoneTheme.Colors.primary : Color.black).opacity(isHost ? 0.08 : 0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("\(hangout.approvedCount)/\(hangout.capacity)")
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                    Spacer()

                    Button {} label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .frame(width: 26, height: 26)
                            .background(Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 18)
                .padding(.trailing, 12)
                .padding(.top, 7)
                .padding(.bottom, 10)
            }
        }
        .background(happening ? FriendZoneTheme.Colors.success.opacity(0.04) : FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(happening ? FriendZoneTheme.Colors.success.opacity(0.24) : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .opacity(isPast ? 0.88 : 1)
    }

    private func soloEventCard(_ event: SoloPlanItem) -> some View {
        let isPast = selectedTab == .past
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: "#0E7490"), Color(hex: "#06B6D4")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "#0E7490"), Color(hex: "#06B6D4")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Text("\(dateLabel(event.startAt)) · \(timeLabel(event.startAt)) · \(event.venueName)")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(timeUntil(event.startAt, isPast: isPast))
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(isPast ? FriendZoneTheme.Colors.textTertiary : FriendZoneTheme.Colors.primary)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(isPast ? Color.black.opacity(0.05) : FriendZoneTheme.Colors.primarySoft)
                        .clipShape(Capsule())
                }
                .padding(.leading, 18)
                .padding(.trailing, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)

                Divider()
                    .padding(.leading, 18)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text("Event · Solo")
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                    .foregroundColor(Color(hex: "#0F4C5C"))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Color(hex: "#0E7490").opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(event.creatorName)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                    Spacer()

                    Button {} label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .frame(width: 26, height: 26)
                            .background(Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 18)
                .padding(.trailing, 12)
                .padding(.top, 7)
                .padding(.bottom, 10)
            }
        }
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .opacity(isPast ? 0.88 : 1)
    }

    private func dateLabel(_ value: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: value)
        if target == today { return "Today" }
        if target == Calendar.current.date(byAdding: .day, value: 1, to: today) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: value)
    }

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func timeUntil(_ date: Date, isPast: Bool) -> String {
        if isPast {
            return shortDate(date)
        }
        let diff = Int(date.timeIntervalSince(now))
        if diff <= 0 { return shortDate(date) }
        let hours = diff / 3600
        if hours >= 24 { return "In \(hours / 24)d" }
        if hours > 0 { return "In \(hours)h" }
        let minutes = max(1, diff / 60)
        return "In \(minutes)m"
    }

    private func shortDate(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: value)
    }

    private func vibeColor(_ vibe: HangoutVibe) -> Color {
        switch vibe {
        case .chill: return Color(hex: "#667EEA")
        case .drinks: return Color(hex: "#FC5C65")
        case .deepTalk: return Color(hex: "#A55EEA")
        case .activity: return Color(hex: "#56AB2F")
        case .foodie: return Color(hex: "#D4A373")
        case .sporty: return Color(hex: "#26DE81")
        }
    }

    private func vibeEmoji(_ vibe: HangoutVibe) -> String {
        switch vibe {
        case .chill: return "😌"
        case .drinks: return "🍸"
        case .deepTalk: return "🗣️"
        case .activity: return "💪"
        case .foodie: return "🍽️"
        case .sporty: return "⚽"
        }
    }
}

private enum PlansHubEntry {
    case hangout(HangoutItem)
    case solo(SoloPlanItem)

    var date: Date {
        switch self {
        case let .hangout(item):
            return item.startAt
        case let .solo(item):
            return item.startAt
        }
    }
}

private struct SoloPlanItem {
    let id: Int
    let title: String
    let startAt: Date
    let venueName: String
    let creatorName: String
}

private enum PlansHubTab: CaseIterable {
    case upcoming
    case hosting
    case past

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .hosting: return "Hosting"
        case .past: return "Past"
        }
    }

    var icon: String {
        switch self {
        case .upcoming: return "📅"
        case .hosting: return "🎯"
        case .past: return "✨"
        }
    }

    var emptyTitle: String {
        switch self {
        case .upcoming: return "No upcoming plans"
        case .hosting: return "Not hosting anything yet"
        case .past: return "No past hangouts"
        }
    }

    var emptyDescription: String {
        switch self {
        case .upcoming: return "Browse Hangouts and join your next activity."
        case .hosting: return "Create your first hangout and bring people together."
        case .past: return "Join some hangouts to build your history."
        }
    }

    var emptyButtonTitle: String {
        switch self {
        case .hosting:
            return "Create Hangout"
        case .upcoming, .past:
            return "Explore Now"
        }
    }

    var index: Int {
        switch self {
        case .upcoming: return 0
        case .hosting: return 1
        case .past: return 2
        }
    }
}

private struct NativePlaceholderHubView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
            Text(message)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativeChangePasswordHubView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var showCurrent = false
    @State private var showNew = false
    @State private var showConfirm = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var didSave = false

    var body: some View {
        Group {
            if didSave {
                VStack(spacing: 12) {
                    Text("✅")
                        .font(.system(size: 56))
                    Text("Password updated")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("Your password was changed successfully.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Button("Back to Settings") {
                        dismiss()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .padding(.horizontal, 24)
                    .frame(height: 42)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 50)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(FriendZoneTheme.Colors.error.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(FriendZoneTheme.Colors.error.opacity(0.24), lineWidth: 1)
                                }
                        }

                        passwordField(
                            title: "Current Password",
                            placeholder: "Enter current password",
                            text: $current,
                            isVisible: $showCurrent
                        )

                        passwordField(
                            title: "New Password",
                            placeholder: "At least 8 characters",
                            text: $newPassword,
                            isVisible: $showNew
                        )

                        passwordField(
                            title: "Confirm New Password",
                            placeholder: "Repeat new password",
                            text: $confirm,
                            isVisible: $showConfirm
                        )

                        Button {
                            Task {
                                await submit()
                            }
                        } label: {
                            Text(isSaving ? "Saving..." : "Update Password")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(FriendZoneTheme.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.65 : 1)
                    }
                    .padding(16)
                }
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func passwordField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.5)

            HStack(spacing: 0) {
                Group {
                    if isVisible.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Spacer(minLength: 8)

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
            }
        }
    }

    private func submit() async {
        errorMessage = ""
        guard newPassword == confirm else {
            errorMessage = "New passwords do not match."
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = "New password must be at least 8 characters."
            return
        }

        isSaving = true
        try? await Task.sleep(nanoseconds: 600_000_000)
        isSaving = false
        didSave = true
    }
}

private struct NativeEmailSettingsHubView: View {
    @State private var currentEmail = "safaeralabs@example.com"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Email")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.5)
                    TextField("", text: $currentEmail)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .disabled(true)
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(FriendZoneTheme.Colors.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                        }
                }

                Text("Email address cannot be changed directly. If you need to update your email, contact support at support@friendzone.app.")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(FriendZoneTheme.Colors.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.primary.opacity(0.14), lineWidth: 1)
                    }
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Email Address")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativeBlockedUsersHubView: View {
    @State private var isLoading = true
    @State private var unblockingID: Int?
    @State private var users: [BlockedUserItem] = [
        BlockedUserItem(id: 1, username: "alex99", displayName: "Alex Rivera", accent: Color(hex: "#8B5CF6")),
        BlockedUserItem(id: 2, username: "nightowl", displayName: "Nora Lee", accent: Color(hex: "#06B6D4")),
        BlockedUserItem(id: 3, username: "quietmode", displayName: "Kai Martin", accent: Color(hex: "#F97316"))
    ]

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading blocked users...")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else if users.isEmpty {
                VStack(spacing: 8) {
                    Text("✕")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    Text("No blocked users")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("Users you block will not be able to see your profile or send you messages.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 0) {
                            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                                blockedRow(user)
                                if index < users.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            guard isLoading else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            isLoading = false
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func blockedRow(_ user: BlockedUserItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(user.accent.opacity(0.14))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(user.displayName.prefix(1)).uppercased())
                        .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                        .foregroundColor(user.accent)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(user.displayName)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text("@\(user.username)")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            Spacer()
            Button {
                guard unblockingID == nil else { return }
                unblockingID = user.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    users.removeAll { $0.id == user.id }
                    unblockingID = nil
                }
            } label: {
                Text(unblockingID == user.id ? "..." : "Unblock")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(FriendZoneTheme.Colors.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.primary.opacity(0.30), lineWidth: 1.5)
                    }
            }
            .buttonStyle(.plain)
            .disabled(unblockingID == user.id)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct NativeNotificationPreferencesHubView: View {
    @State private var hangoutInvites = true
    @State private var joinRequests = true
    @State private var messages = true
    @State private var eventUpdates = true
    @State private var newFollowers = false
    @State private var reminders = true
    @State private var didSave = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Notify me about")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    preferenceRow("Hangout Invitations", "When someone invites you to a hangout", isOn: $hangoutInvites)
                    Divider().padding(.leading, 16)
                    preferenceRow("Join Requests", "When someone requests to join your hangout", isOn: $joinRequests)
                    Divider().padding(.leading, 16)
                    preferenceRow("New Messages", "When you receive a message in a hangout chat", isOn: $messages)
                    Divider().padding(.leading, 16)
                    preferenceRow("Event Updates", "Changes to events you're attending", isOn: $eventUpdates)
                    Divider().padding(.leading, 16)
                    preferenceRow("New Followers", "When someone follows your profile", isOn: $newFollowers)
                    Divider().padding(.leading, 16)
                    preferenceRow("Reminders", "Reminders before your upcoming hangouts", isOn: $reminders)
                }
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }

                Button {
                    didSave = true
                } label: {
                    Text("Save Preferences")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                if didSave {
                    Text("Preferences saved")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func preferenceRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(FriendZoneTheme.Colors.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct NativeFeedbackHubView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var category = "General Feedback"
    @State private var feedback = ""
    @State private var sent = false
    @State private var loading = false

    private let categories = ["General Feedback", "Feature Request", "Bug Report", "Other"]

    var body: some View {
        Group {
            if sent {
                VStack(spacing: 12) {
                    Text("✅")
                        .font(.system(size: 56))
                    Text("Thanks for your feedback!")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("We read every message and use it to improve FriendZone.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Back to Settings") {
                        dismiss()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .padding(.horizontal, 24)
                    .frame(height: 42)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(0.5)
                            Picker("", selection: $category) {
                                ForEach(categories, id: \.self) { item in
                                    Text(item).tag(item)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Message")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(0.5)
                            TextEditor(text: $feedback)
                                .font(.system(size: 15))
                                .frame(height: 160)
                                .padding(8)
                                .background(FriendZoneTheme.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                                }
                        }

                        Button {
                            Task {
                                loading = true
                                try? await Task.sleep(nanoseconds: 600_000_000)
                                loading = false
                                sent = true
                            }
                        } label: {
                            Text(loading ? "Sending..." : "Send Feedback")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(FriendZoneTheme.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(loading || feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((loading || feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
                    }
                    .padding(16)
                }
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativeReportProblemHubView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reason = "Other"
    @State private var details = ""
    @State private var sent = false
    @State private var loading = false

    private let reasons = ["Spam", "Fake / Scam", "Harassment / Hate", "Inappropriate content", "Other"]

    var body: some View {
        Group {
            if sent {
                VStack(spacing: 12) {
                    Text("✅")
                        .font(.system(size: 56))
                    Text("Report submitted!")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("Our moderation team will review this report.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Button("Back") {
                        dismiss()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .padding(.horizontal, 24)
                    .frame(height: 42)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Problem Type")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(0.5)
                            Picker("", selection: $reason) {
                                ForEach(reasons, id: \.self) { item in
                                    Text(item).tag(item)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(0.5)
                            TextEditor(text: $details)
                                .font(.system(size: 15))
                                .frame(height: 160)
                                .padding(8)
                                .background(FriendZoneTheme.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                                }
                        }

                        Button {
                            Task {
                                loading = true
                                try? await Task.sleep(nanoseconds: 600_000_000)
                                loading = false
                                sent = true
                            }
                        } label: {
                            Text(loading ? "Submitting..." : "Submit Report")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(FriendZoneTheme.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(loading || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((loading || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
                    }
                    .padding(16)
                }
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Report a Problem")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BlockedUserItem: Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let accent: Color
}

#Preview {
    NavigationStack {
        HangoutsView()
    }
}
