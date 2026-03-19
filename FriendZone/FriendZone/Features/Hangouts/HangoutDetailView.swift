import SwiftUI
import UIKit
import MapKit

struct HangoutDetailView: View {
    @EnvironmentObject private var session: AppSessionStore
    let hangout: HangoutItem
    let onRequestJoin: () -> Void
    let onCancelRequest: () -> Void
    let onClose: (() -> Void)?
    let closeButtonSystemName: String

    @Environment(\.dismiss) private var dismiss

    @State private var localJoinStatus: HangoutJoinStatus
    @State private var isWaitlisted: Bool
    @State private var isCancelledByHost = false
    @State private var isShowingMoreMenu = false
    @State private var isShowingReportSent = false
    @State private var isShowingCancelHangoutConfirm = false
    @State private var selectedPublicProfile: PublicProfileData?
    @State private var selectedPage = 0
    @State private var selectedInfoPanel = 0
    @GestureState private var pageDragOffset: CGFloat = 0
    @GestureState private var infoPanelDragOffset: CGFloat = 0
    @State private var displayedParticipants: [DetailPerson]
    @State private var joinRequests: [DetailJoinRequest]
    @State private var detailMessages: [DetailChatMessage]
    @State private var detailMetadata: DetailMetadata
    @State private var composerText = ""
    @State private var actionFeedback: String?
    @State private var isPerformingNetworkAction = false
    @State private var shouldRenderLocationMap = false
    @State private var shouldRenderActivityPage = false
    @State private var resolvedLocationCoordinate: CLLocationCoordinate2D?
    @FocusState private var composerFocused: Bool

    init(
        hangout: HangoutItem,
        joinStatus: HangoutJoinStatus,
        onRequestJoin: @escaping () -> Void,
        onCancelRequest: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        closeButtonSystemName: String = "chevron.left"
    ) {
        self.hangout = hangout
        self.onRequestJoin = onRequestJoin
        self.onCancelRequest = onCancelRequest
        self.onClose = onClose
        self.closeButtonSystemName = closeButtonSystemName
        _localJoinStatus = State(initialValue: joinStatus)
        _isWaitlisted = State(initialValue: joinStatus == .requested && hangout.isFull)
        _displayedParticipants = State(initialValue: Self.initialParticipants(from: hangout))
        _joinRequests = State(initialValue: [])
        _detailMessages = State(initialValue: [])
        _detailMetadata = State(initialValue: DetailMetadata(hangout: hangout))
        _resolvedLocationCoordinate = State(initialValue: Self.initialCoordinate(from: hangout))
    }

    var body: some View {
        GeometryReader { proxy in
            let pageHeight = proxy.size.height
            let topInset = proxy.safeAreaInsets.top

            ZStack {
                background

                VStack(spacing: 0) {
                    infoPage(topInset: topInset, pageHeight: pageHeight)
                        .frame(width: proxy.size.width, height: pageHeight)

                    Group {
                        if shouldRenderActivityPage || selectedPage == 1 {
                            activityPage(topInset: topInset, pageHeight: pageHeight)
                        } else {
                            Color.clear
                        }
                    }
                        .frame(width: proxy.size.width, height: pageHeight)
                }
                .offset(y: -CGFloat(selectedPage) * pageHeight + pageDragOffset)
                .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86), value: selectedPage)
                .gesture(
                    DragGesture(minimumDistance: 16)
                        .updating($pageDragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let threshold = pageHeight * 0.12
                            if value.translation.height < -threshold {
                                selectedPage = min(1, selectedPage + 1)
                            } else if value.translation.height > threshold {
                                selectedPage = max(0, selectedPage - 1)
                            }
                        }
                )
            }
            .overlay(alignment: .top) {
                topNav(topInset: topInset)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedPage) { page in
            if page == 1 {
                shouldRenderActivityPage = true
            }
        }
        .confirmationDialog("Hangout actions", isPresented: $isShowingMoreMenu, titleVisibility: .visible) {
            Button("Report Hangout", role: .destructive) {
                isShowingReportSent = true
            }
            if isHost, !isEnded {
                Button("Cancel Hangout", role: .destructive) {
                    isShowingCancelHangoutConfirm = true
                }
            }
            Button("Close", role: .cancel) {}
        }
        .alert("Report sent", isPresented: $isShowingReportSent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks. We will review this hangout.")
        }
        .alert("Cancel this hangout?", isPresented: $isShowingCancelHangoutConfirm) {
            Button("Keep", role: .cancel) {}
            Button("Cancel Hangout", role: .destructive) {
                Task { await cancelHangout() }
            }
        } message: {
            Text("Participants will be notified that this hangout was cancelled.")
        }
        .sheet(item: $selectedPublicProfile) { profile in
            NavigationStack {
                PublicProfileView(
                    profile: profile,
                    leadingText: "Public ",
                    highlightText: "profile",
                    subtitle: "From this hangout",
                    onClose: { selectedPublicProfile = nil }
                )
            }
            .background(FriendZoneTheme.Colors.background)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            await hydrateRemoteState()
        }
        .task {
            guard !shouldRenderLocationMap else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            shouldRenderLocationMap = true
        }
        .safeAreaInset(edge: .bottom) {
            if shouldPinPrimaryAction {
                persistentBottomActionBar
            }
        }
    }

    private var background: some View {
        FriendZoneTheme.background
            .ignoresSafeArea()
    }

    private func infoPage(topInset: CGFloat, pageHeight: CGFloat) -> some View {
        GeometryReader { proxy in
            let panels = HStack(spacing: 0) {
                generalInfoPanel(topInset: topInset)
                    .frame(width: proxy.size.width)

                if hasRequestsPanel {
                    requestsPanel(topInset: topInset)
                        .frame(width: proxy.size.width)
                }
            }
            .offset(x: -CGFloat(selectedInfoPanel) * proxy.size.width + infoPanelDragOffset)
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86), value: selectedInfoPanel)

            if hasRequestsPanel {
                panels
                    .simultaneousGesture(horizontalInfoPanelGesture(width: proxy.size.width))
            } else {
                panels
            }
        }
    }

    private func horizontalInfoPanelGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .updating($infoPanelDragOffset) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let threshold = width * 0.16
                if value.translation.width < -threshold {
                    selectedInfoPanel = 1
                } else if value.translation.width > threshold {
                    selectedInfoPanel = 0
                }
            }
    }

    private func generalInfoPanel(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            ticketCard
                .padding(.top, detailTopContentInset(topInset))

            peopleLocationCard
                .padding(.top, 8)

            if hasHangoutDetailsCard {
                hangoutDetailsCard
                    .padding(.top, 8)
            }

            if hasInviteDetailsCard {
                inviteDetailsCard
                    .padding(.top, 8)
            }

            if isEnded {
                statusBanner(
                    title: "This hangout ended",
                    message: "The activity panel stays available for context, but the hangout is closed."
                )
                .padding(.top, 12)
            } else if isCancelledByHost {
                statusBanner(
                    title: "Cancelled by host",
                    message: "Participants can no longer join this hangout."
                )
                .padding(.top, 12)
            }

            if let actionFeedback {
                statusBanner(
                    title: "Status",
                    message: actionFeedback
                )
                .padding(.top, 12)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                pageCue(
                    title: "Swipe up for activity",
                    subtitle: "Open the group chat",
                    direction: .up
                )

                if hasRequestsPanel {
                    pageCue(
                        title: "Swipe left for requests",
                        subtitle: "\(joinRequests.count) pending",
                        direction: .left
                    )
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func requestsPanel(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            joinRequestsCard
                .padding(.top, detailTopContentInset(topInset))

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                pageCue(
                    title: "Swipe right for info",
                    subtitle: "Back to the hangout",
                    direction: .right
                )

                pageCue(
                    title: "Swipe up for activity",
                    subtitle: "Open the group chat",
                    direction: .up
                )
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func activityPage(topInset: CGFloat, pageHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            activityHeader
                .padding(.top, detailTopContentInset(topInset))

            Group {
                if canOpenChat {
                    activityChatCard
                } else {
                    activityLockedCard
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: min(560, pageHeight * 0.74), maxHeight: min(760, pageHeight * 0.84))

            Spacer(minLength: 0)

            if !shouldPinPrimaryAction {
                primaryBottomAction
                    .padding(.bottom, 8)
            }

            pageCue(
                title: "Swipe down for hangout info",
                subtitle: "Back to the pass",
                direction: .down
            )
            .padding(.bottom, 12)
        }
        .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func topNav(topInset _: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: closeButtonSystemName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(FriendZoneTheme.Colors.surface.opacity(0.96))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
            }

            Spacer()

            Button {
                isShowingMoreMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(FriendZoneTheme.Colors.surface.opacity(0.96))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
            }
        }
        .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
        .padding(.top, FriendZoneTheme.Chrome.topOffset)
    }

    private func detailTopContentInset(_: CGFloat) -> CGFloat {
        FriendZoneTheme.Chrome.topOffset + 40 + FriendZoneTheme.Chrome.sectionGap
    }

    private var ticketCard: some View {
        DiscoverHangoutCardView(hangout: hangout)
    }

    private var hasHangoutDetailsCard: Bool {
        !trimmedHangoutDescription.isEmpty || !hangoutDetailItems.isEmpty || !detailLanguageLabels.isEmpty || !detailAudienceLabels.isEmpty
    }

    private var hangoutDetailsCard: some View {
        detailSectionCard(
            title: "Hangout details",
            compact: true
        ) {
            if !trimmedHangoutDescription.isEmpty {
                detailBodyCopy(trimmedHangoutDescription, compact: true)
            }

            detailFactGrid(items: hangoutDetailItems, compact: true)

            if !detailLanguageLabels.isEmpty {
                detailChipSection(title: "Languages", chips: detailLanguageLabels, compact: true)
            }

            if !detailAudienceLabels.isEmpty {
                detailChipSection(title: "Audience", chips: detailAudienceLabels, compact: true)
            }
        }
    }

    private var hasInviteDetailsCard: Bool {
        hostInviteCode != nil || hostInviteHint != nil
    }

    private var inviteDetailsCard: some View {
        detailSectionCard(
            title: "Invite details",
            subtitle: "Host-only entry information."
        ) {
            if let hostInviteCode {
                detailSecretRow(
                    title: "Invite code",
                    value: hostInviteCode,
                    caption: "Only visible to you as host."
                )
            }

            if let hostInviteHint {
                detailSecretRow(
                    title: "Invite hint",
                    value: hostInviteHint,
                    caption: "Use this to guide invited people without exposing the code."
                )
            }
        }
    }

    private func detailSectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        compact: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            VStack(alignment: .leading, spacing: compact ? 1 : 3) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(compact ? 12.5 : 14, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(FriendZoneTheme.Typography.system(compact ? 10 : 10.5, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .lineSpacing(1.4)
                }
            }

            content()
        }
        .padding(compact ? 8 : 12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func detailBodyCopy(_ text: String, compact: Bool = false) -> some View {
        Text(text)
            .font(FriendZoneTheme.Typography.system(compact ? 11 : 12, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .lineSpacing(compact ? 1.2 : 1.8)
            .lineLimit(compact ? 2 : nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailFactColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    private func detailFactGrid(items: [DetailFactItem], compact: Bool = false) -> some View {
        LazyVGrid(columns: detailFactColumns, alignment: .leading, spacing: compact ? 6 : 10) {
            ForEach(items) { item in
                detailFactTile(item, compact: compact)
            }
        }
    }

    private func detailFactTile(_ item: DetailFactItem, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(item.title.uppercased())
                .font(FriendZoneTheme.Typography.system(compact ? 8.5 : 9, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.6)

            Text(item.value)
                .font(FriendZoneTheme.Typography.system(compact ? 11 : 12, weight: .bold))
                .foregroundColor(item.accent)
                .lineLimit(1)

            Text(item.subtitle)
                .font(FriendZoneTheme.Typography.system(compact ? 9 : 10, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineSpacing(compact ? 1.0 : 1.3)
                .lineLimit(compact ? 1 : 3)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 50 : 72, alignment: .topLeading)
        .padding(compact ? 7 : 10)
        .background(FriendZoneTheme.Colors.surfaceElevated.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func detailChipSection(title: String, chips: [String], compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(compact ? 8.5 : 9, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.6)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 82 : 96), spacing: compact ? 5 : 8)], alignment: .leading, spacing: compact ? 5 : 8) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(FriendZoneTheme.Typography.system(compact ? 9.5 : 10.5, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .padding(.horizontal, compact ? 7 : 9)
                        .frame(height: compact ? 22 : 28)
                        .background(FriendZoneTheme.Colors.surfaceElevated.opacity(0.94))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }
            }
        }
    }

    private func detailSecretRow(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.6)

            Text(value)
                .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(caption)
                .font(FriendZoneTheme.Typography.system(10.5, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineSpacing(1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FriendZoneTheme.Colors.surfaceElevated.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var detailPerforationLine: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< 28, id: \.self) { _ in
                Capsule()
                    .fill(FriendZoneTheme.Colors.borderSubtle.opacity(0.95))
                    .frame(width: 6, height: 2)
            }
        }
    }

    private var detailTicketClipMask: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white)
            .overlay {
                detailTicketPunchHoles
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    private var detailTicketPunchHoles: some View {
        GeometryReader { proxy in
            let sideRadius: CGFloat = 7
            let centerRadius: CGFloat = 12
            let topInset: CGFloat = 18
            let bottomInset: CGFloat = 18
            let usableHeight = max(0, proxy.size.height - topInset - bottomInset)
            let step = usableHeight / 7

            ZStack {
                ForEach(0 ..< 8, id: \.self) { index in
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
                    .position(x: proxy.size.width * 0.5, y: 0)

                Circle()
                    .fill(FriendZoneTheme.Colors.background)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height)
            }
        }
    }

    private func ticketAccentPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(FriendZoneTheme.Typography.system(12, weight: .heavy))
            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(tint.opacity(0.26), lineWidth: 1)
            }
    }

    private func ticketMetaPill(_ title: String) -> some View {
        Text(title)
            .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(Color.black.opacity(0.035))
            .clipShape(Capsule())
    }

    private func statusBanner(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(message)
                .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var activityHeader: some View {
        Text("Hangout Activity")
            .font(FriendZoneTheme.Typography.system(19, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private var activityChatCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat")
                        .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(activeNowPeople.isEmpty ? FriendZoneTheme.Colors.textTertiary.opacity(0.35) : FriendZoneTheme.Colors.success)
                            .frame(width: 7, height: 7)
                        Text(activeNowSummary)
                            .lineLimit(1)
                    }
                        .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }

                Spacer(minLength: 0)

                Text(currentRole.title)
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(detailAccentColor)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(detailAccentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, activeNowPeople.isEmpty ? 12 : 8)

            if !activeNowPeople.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeNowPeople) { person in
                            onlinePersonPill(person)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .scrollDisabled(true)
                .allowsHitTesting(false)
            }

            ScrollView(showsIndicators: false) {
                if detailMessages.isEmpty {
                    emptyActivityState
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                } else {
                    VStack(spacing: 10) {
                        ForEach(detailMessages) { message in
                            activityMessageBubble(message)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }

            Divider()
                .overlay(FriendZoneTheme.Colors.borderSubtle)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message the group", text: $composerText, axis: .vertical)
                    .lineLimit(1 ... 3)
                    .font(FriendZoneTheme.Typography.system(13, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .focused($composerFocused)

                Button(action: sendActivityMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(detailAccentColor)
                        .clipShape(Circle())
                }
                .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPerformingNetworkAction)
                .opacity((composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPerformingNetworkAction) ? 0.45 : 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.65))
        }
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .frame(maxHeight: .infinity)
    }

    private func onlinePersonPill(_ person: DetailPerson) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                participantAvatar(for: person.initials, color: person.tint, size: 24)

                Circle()
                    .fill(FriendZoneTheme.Colors.success)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    }
                    .offset(x: 1, y: 1)
            }

            Text(person.firstName)
                .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(FriendZoneTheme.Colors.surfaceElevated)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func activityMessageBubble(_ message: DetailChatMessage) -> some View {
        let mine = message.isMine

        return HStack(alignment: .bottom, spacing: 8) {
            if mine { Spacer(minLength: 42) }

            if !mine {
                participantAvatar(for: message.initials, color: message.tint, size: 30)
            }

            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if !mine {
                    Text(message.author)
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }

                Text(message.text)
                    .font(FriendZoneTheme.Typography.system(13, weight: .medium))
                    .foregroundColor(mine ? .white : FriendZoneTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(mine ? detailAccentColor : Color.black.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(message.time)
                    .font(FriendZoneTheme.Typography.system(9, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            if !mine { Spacer(minLength: 20) }
            if mine {
                participantAvatar(for: "Y", color: detailAccentColor, size: 30)
            }
        }
    }

    private var emptyActivityState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            Text("No messages yet")
                .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text("The chat stays empty until someone sends the first message.")
                .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var activityLockedCard: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: isWaitlisted ? "clock.badge.exclamationmark.fill" : "person.badge.key.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(detailAccentColor)

            VStack(spacing: 6) {
                Text(isWaitlisted ? "You are on the waitlist" : "Activity is locked")
                    .font(FriendZoneTheme.Typography.system(19, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(isWaitlisted ? "The host will notify you if a place opens up." : "Once accepted, this section reveals the group chat and the final location.")
                    .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 18)
            }

            ticketMetaPill(localJoinStatus == .requested ? localJoinStatus.chipTitle : "REQUEST TO UNLOCK")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var peopleLocationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("People & Location")
                    .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Spacer(minLength: 0)

                Text("\(approvedParticipantsCount) here")
                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(displayedParticipants) { person in
                        compactParticipantPill(person)
                    }
                }
                .padding(.vertical, 1)
            }

            Divider()
                .overlay(FriendZoneTheme.Colors.borderSubtle)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Location")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                    Spacer(minLength: 0)

                    Text(isLocationHidden ? "Locked" : "Unlocked")
                        .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                        .foregroundColor(isLocationHidden ? FriendZoneTheme.Colors.textTertiary : detailAccentColor)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(
                            (isLocationHidden ? FriendZoneTheme.Colors.surfaceElevated : detailAccentColor.opacity(0.10))
                        )
                        .clipShape(Capsule())
                }

                detailLocationMapCard

                Text(locationStatusTitle)
                    .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(locationStatusSubtitle)
                    .font(FriendZoneTheme.Typography.system(9.5, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .lineSpacing(1.1)
                    .lineLimit(2)

                if !isLocationHidden, let displayedLocationAddress {
                    Text(displayedLocationAddress)
                        .font(FriendZoneTheme.Typography.system(9.5, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .lineSpacing(1.1)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func compactParticipantPill(_ person: DetailPerson) -> some View {
        Button {
            openPublicProfile(for: person)
        } label: {
            HStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    participantAvatar(for: person.initials, color: person.tint, size: 21)

                    if person.role == "Host" {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 12, height: 12)
                            .background(FriendZoneTheme.Colors.primary)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            }
                    } else if person.isConfirmed {
                        Circle()
                            .fill(person.tint)
                            .frame(width: 8, height: 8)
                            .overlay {
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            }
                    }
                }

                Text(person.firstName)
                    .font(FriendZoneTheme.Typography.system(9.5, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .frame(height: 30)
            .background(FriendZoneTheme.Colors.surfaceElevated.opacity(0.92))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailLocationMapCard: some View {
        if let coordinate = displayLocationCoordinate, shouldRenderLocationMap {
            Map(
                coordinateRegion: .constant(detailLocationRegion(for: coordinate)),
                interactionModes: [],
                annotationItems: [DetailLocationMarker(coordinate: coordinate)]
            ) { marker in
                MapAnnotation(coordinate: marker.coordinate) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isLocationHidden
                                    ? [Color(hex: "#6B7280"), Color(hex: "#9CA3AF")]
                                    : [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: isLocationHidden ? "lock.fill" : "mappin")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                }
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 6) {
                    Image(systemName: isLocationHidden ? "lock.fill" : "mappin")
                        .font(.system(size: 9, weight: .bold))
                    Text(isLocationHidden ? "Area only" : "Pinned spot")
                        .font(FriendZoneTheme.Typography.system(9, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
        } else if displayLocationCoordinate != nil {
            ZStack {
                LinearGradient(
                    colors: [
                        FriendZoneTheme.Colors.surfaceElevated,
                        FriendZoneTheme.Colors.surface,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: isLocationHidden ? "lock.square.fill" : "map.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isLocationHidden ? FriendZoneTheme.Colors.textTertiary : detailAccentColor)

                    Text(isLocationHidden ? "Loading area preview" : "Loading map preview")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#F3F4F6"), Color(hex: "#E5E7EB")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    Text("Map unavailable")
                        .font(FriendZoneTheme.Typography.system(10.5, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        }
    }

    private var joinRequestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Requests to Join")
                        .font(FriendZoneTheme.Typography.system(22, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text("Review who wants to join this hangout.")
                        .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                Text("\(joinRequests.count)")
                    .font(FriendZoneTheme.Typography.system(12, weight: .heavy))
                    .foregroundColor(detailAccentColor)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(detailAccentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(joinRequests) { request in
                        joinRequestRow(request)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .padding(18)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func joinRequestRow(_ request: DetailJoinRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                participantAvatar(for: request.initials, color: request.tint, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.displayName)
                        .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(request.headline)
                        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                    Text(request.note)
                        .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .lineSpacing(1.8)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                ticketMetaPill(request.city.uppercased())
                ticketMetaPill(request.arrivalHint.uppercased())
            }

            HStack(spacing: 10) {
                Button {
                    Task { await acceptJoinRequestRemote(request) }
                } label: {
                    Text("Accept")
                        .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(detailAccentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    Task { await declineJoinRequestRemote(request) }
                } label: {
                    Text("Decline")
                        .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.black.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(FriendZoneTheme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var primaryBottomAction: some View {
        Group {
            if isHost {
                bottomActionButton(
                    title: isEnded || isCancelledByHost ? "Hangout Closed" : "Cancel Hangout",
                    subtitle: isEnded || isCancelledByHost ? "This activity is no longer active." : "Close this hangout for everyone",
                    tint: isEnded || isCancelledByHost ? FriendZoneTheme.Colors.textTertiary : FriendZoneTheme.Colors.error,
                    isEnabled: !(isEnded || isCancelledByHost)
                ) {
                    isShowingCancelHangoutConfirm = true
                }
            } else if localJoinStatus == .joined {
                bottomActionButton(
                    title: "Leave Hangout",
                    subtitle: "You can re-request later if it stays open",
                    tint: FriendZoneTheme.Colors.error,
                    isEnabled: !isEnded
                ) {
                    Task { await leaveHangout() }
                }
            } else if localJoinStatus == .requested {
                bottomActionButton(
                    title: isWaitlisted ? "Leave Waitlist" : "Cancel Request",
                    subtitle: isWaitlisted ? "You will stop waiting for a free place" : "Withdraw your join request",
                    tint: FriendZoneTheme.Colors.textPrimary,
                    isEnabled: false
                ) {
                    actionFeedback = "Cancel request is not exposed by the backend yet."
                }
            } else {
                bottomActionButton(
                    title: hangout.isFull ? "Join Waitlist" : "Request to Join",
                    subtitle: hangout.isFull ? "You will be notified if a place opens" : "The host will review your request",
                    tint: detailAccentColor,
                    isEnabled: !(isEnded || isCancelledByHost)
                ) {
                    Task { await requestJoin() }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var persistentBottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(FriendZoneTheme.Colors.borderSubtle)

            HStack {
                primaryBottomAction
            }
            .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
        .background(FriendZoneTheme.Colors.background.opacity(0.94))
    }

    private func bottomActionButton(
        title: String,
        subtitle: String,
        tint: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(isEnabled ? .white : FriendZoneTheme.Colors.textInverse.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                LinearGradient(
                    colors: isEnabled ? [tint, tint.opacity(0.82)] : [Color.gray.opacity(0.45), Color.gray.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isEnabled)
    }

    private func pageCue(title: String, subtitle: String, direction: PageCueDirection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: direction.iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            VStack(spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(10, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(FriendZoneTheme.Colors.surface.opacity(0.88))
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func participantAvatar(for initials: String, color: Color, size: CGFloat) -> some View {
        Text(initials)
            .font(FriendZoneTheme.Typography.system(size * 0.34, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }

    private func sendActivityMessage() {
        guard !isPerformingNetworkAction else { return }
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await sendMessage(trimmed) }
    }

    private var subtitleText: String {
        switch hangout.sourceType {
        case .hangout:
            return "Community hangout"
        case .offer:
            return "Venue-based hangout"
        case .event:
            return "Event-based hangout"
        }
    }

    private var audienceSummary: String {
        if hangout.isMicro { return "MICRO" }
        if hangout.isLive { return "LIVE" }
        return "OPEN GROUP"
    }

    private var currentSessionUserID: Int? {
        session.currentUser?.id ?? session.currentProfile?.user?.id
    }

    private var isHost: Bool {
        hangout.isHosted(by: currentSessionUserID)
    }

    private var isEnded: Bool {
        hangout.endAt < Date()
    }

    private var isLocationHidden: Bool {
        !(isHost || localJoinStatus == .joined)
    }

    private var canOpenChat: Bool {
        isHost || localJoinStatus == .joined
    }

    private var shouldPinPrimaryAction: Bool {
        !isHost && localJoinStatus != .joined
    }

    private var hasRequestsPanel: Bool {
        isHost && !joinRequests.isEmpty && !isCancelledByHost
    }

    private var currentRole: DetailRole {
        if isHost { return .host }
        switch localJoinStatus {
        case .none: return .guest
        case .requested: return isWaitlisted ? .waitlisted : .pending
        case .joined: return .participant
        }
    }

    private var approvedParticipantsCount: Int {
        max(hangout.approvedCount, displayedParticipants.filter(\.isConfirmed).count)
    }

    private var detailCountdownText: String {
        if hangout.isLive { return "LIVE" }
        return timeRemainingText(from: Date(), to: hangout.startAt) ?? "SOON"
    }

    private var spotsLabel: String {
        hangout.isFull ? "Full" : "\(hangout.spotsLeft) spots left"
    }

    private var detailSpotsColor: Color {
        hangout.isFull ? FriendZoneTheme.Colors.error : detailAccentColor
    }

    private var durationLabel: String {
        let minutes = max(30, Int(hangout.endAt.timeIntervalSince(hangout.startAt) / 60))
        if minutes % 60 == 0 {
            return "\(minutes / 60)H"
        }
        return "\(minutes / 60)H \(minutes % 60)M"
    }

    private var detailAccentColor: Color {
        switch hangout.sourceType {
        case .hangout:
            return FriendZoneTheme.Colors.primary
        case .offer:
            return Color(hex: "#F18B4C")
        case .event:
            return Color(hex: "#FF4D6D")
        }
    }

    private var detailAccentHex: String {
        switch hangout.sourceType {
        case .hangout:
            return "#5C6BFF"
        case .offer:
            return "#F18B4C"
        case .event:
            return "#FF4D6D"
        }
    }

    private var coverUIImage: UIImage? {
        guard let data = hangout.coverImageData else { return nil }
        return UIImage(data: data)
    }

    private var activeNowPeople: [DetailPerson] {
        let cutoff = Date().addingTimeInterval(-20 * 60)
        var seen = Set<String>()
        let peopleByName = displayedParticipants.reduce(into: [String: DetailPerson]()) { partial, person in
            partial[normalizedPresenceName(person.displayName)] = person
        }

        return detailMessages
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .compactMap { message in
                guard let createdAt = message.createdAt, createdAt >= cutoff else { return nil }
                let key = normalizedPresenceName(message.author)
                guard !seen.contains(key) else { return nil }
                seen.insert(key)
                if let person = peopleByName[key] {
                    return person
                }
                return DetailPerson(
                    id: "active-\(key)",
                    userID: nil,
                    displayName: message.author,
                    role: "Active",
                    tint: message.tint,
                    hexColor: message.tintHex,
                    isConfirmed: true
                )
            }
    }

    private var activeNowSummary: String {
        let names = activeNowPeople.prefix(2).map(\.firstName)
        switch activeNowPeople.count {
        case 0:
            return "No one active now"
        case 1:
            return "\(names[0]) active now"
        case 2:
            return "\(names[0]) and \(names[1]) active"
        default:
            let remaining = activeNowPeople.count - 2
            return "\(names[0]), \(names[1]) +\(remaining) active"
        }
    }

    private var hangoutDetailItems: [DetailFactItem] {
        let groupValue = detailMetadata.isCapacityUnlimited == true ? "Unlimited" : "\(hangout.capacity) spots"
        let groupSubtitle: String
        if detailMetadata.isCapacityUnlimited == true {
            groupSubtitle = "\(approvedParticipantsCount) approved so far"
        } else if hangout.isFull {
            groupSubtitle = "\(approvedParticipantsCount) approved · currently full"
        } else {
            groupSubtitle = "\(approvedParticipantsCount) approved · \(hangout.spotsLeft) left"
        }

        let timingValue = detailMetadata.isTimeFlexible == true ? "Flexible" : "Fixed start"
        let timingSubtitle = detailMetadata.isTimeFlexible == true
            ? "Around \(timeOnlyLabel(hangout.startAt)) · \(dateOnlyLabel(hangout.startAt))"
            : "Starts \(timeOnlyLabel(hangout.startAt)) · \(dateOnlyLabel(hangout.startAt))"

        var items: [DetailFactItem] = [
            DetailFactItem(
                id: "capacity",
                title: "Capacity",
                value: groupValue,
                subtitle: groupSubtitle,
                accent: detailAccentColor
            ),
            DetailFactItem(
                id: "timing",
                title: "Timing",
                value: timingValue,
                subtitle: timingSubtitle,
                accent: FriendZoneTheme.Colors.textPrimary
            ),
        ]

        if let visibility = detailMetadata.visibility {
            items.append(
                DetailFactItem(
                    id: "visibility",
                    title: "Visibility",
                    value: visibility.detailTitle,
                    subtitle: visibilitySubtitle(for: visibility),
                    accent: detailAccentColor
                )
            )
        }

        if let allowWaitlist = detailMetadata.allowWaitlist, detailMetadata.visibility != .inviteOnly {
            items.append(
                DetailFactItem(
                    id: "waitlist",
                    title: "Waitlist",
                    value: allowWaitlist ? "Enabled" : "Off",
                    subtitle: allowWaitlist
                        ? "People can still queue if this fills up."
                        : "Requests close once capacity is reached.",
                    accent: allowWaitlist ? detailAccentColor : FriendZoneTheme.Colors.textPrimary
                )
            )
        }

        if let genderPreference = detailMetadata.genderPreference, genderPreference != .any {
            items.append(
                DetailFactItem(
                    id: "audience-filter",
                    title: "Audience",
                    value: genderPreference.detailTitle,
                    subtitle: "Selection preference chosen by the host.",
                    accent: detailAccentColor
                )
            )
        }

        return items
    }

    private var detailLanguageLabels: [String] {
        detailMetadata.languages.map(formattedDetailLanguageLabel)
    }

    private var detailAudienceLabels: [String] {
        detailMetadata.audienceTags.map(formattedDetailAudienceTag)
    }

    private func visibilitySubtitle(for visibility: HangoutVisibilityOption) -> String {
        switch visibility {
        case .public:
            return "Visible in discovery and joinable through requests."
        case .inviteOnly:
            return isHost
                ? "Entry is controlled through your invite flow."
                : "This hangout is reviewed by the host before details unlock."
        }
    }

    private var hostInviteCode: String? {
        guard isHost, detailMetadata.visibility == .inviteOnly else { return nil }
        let value = detailMetadata.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private var hostInviteHint: String? {
        guard isHost, detailMetadata.visibility == .inviteOnly else { return nil }
        let value = detailMetadata.inviteCodeHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private var displayedCityName: String {
        detailMetadata.cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? hangout.cityName
            : detailMetadata.cityName
    }

    private var displayedLocationName: String? {
        let value = (detailMetadata.locationName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var displayedLocationAddress: String? {
        let value = (detailMetadata.locationAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var locationStatusTitle: String {
        if isLocationHidden {
            return "Exact location hidden"
        }
        return displayedLocationName ?? displayedCityName
    }

    private var locationStatusSubtitle: String {
        if isLocationHidden {
            return "Unlocked once the host accepts you."
        }
        if (displayedLocationName ?? displayedCityName) == displayedCityName {
            return "Pinned for around \(timeOnlyLabel(hangout.startAt))."
        }
        return "\(displayedCityName) · Around \(timeOnlyLabel(hangout.startAt))"
    }

    private var trimmedHangoutDescription: String {
        hangout.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayLocationCoordinate: CLLocationCoordinate2D? {
        guard let resolvedLocationCoordinate = resolvedLocationCoordinate
            ?? validCoordinate(lat: detailMetadata.latitude, lng: detailMetadata.longitude)
        else { return nil }
        if isLocationHidden {
            return obfuscatedLocationCoordinate(resolvedLocationCoordinate)
        }
        return resolvedLocationCoordinate
    }

    private func detailLocationRegion(for coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: isLocationHidden ? 0.012 : 0.006,
                longitudeDelta: isLocationHidden ? 0.012 : 0.006
            )
        )
    }

    private func obfuscatedLocationCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let angle = Double((hangout.id * 73) % 360) * .pi / 180
        let radiusMeters = 220 + Double((hangout.id * 37) % 140)
        let latitudeOffset = (radiusMeters / 111_320.0) * cos(angle)
        let longitudeScale = max(1, 111_320.0 * cos(coordinate.latitude * .pi / 180))
        let longitudeOffset = (radiusMeters / longitudeScale) * sin(angle)
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latitudeOffset,
            longitude: coordinate.longitude + longitudeOffset
        )
    }

    private func validCoordinate(lat: Double?, lng: Double?) -> CLLocationCoordinate2D? {
        guard let lat, let lng, abs(lat) <= 90, abs(lng) <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private static func initialCoordinate(from hangout: HangoutItem) -> CLLocationCoordinate2D? {
        guard let lat = hangout.latitude, let lng = hangout.longitude, abs(lat) <= 90, abs(lng) <= 180 else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private func formattedDetailLanguageLabel(_ code: String) -> String {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "en": return "🇬🇧 EN"
        case "es": return "🇪🇸 ES"
        case "de": return "🇩🇪 DE"
        case "fr": return "🇫🇷 FR"
        case "it": return "🇮🇹 IT"
        case "ja": return "🇯🇵 JA"
        default:
            let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "🗣️ Open" : normalized.uppercased()
        }
    }

    private func formattedDetailAudienceTag(_ value: String) -> String {
        guard let tag = HangoutAudienceTagOption(rawValue: value) else {
            let normalized = value
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "Open crowd" : normalized.capitalized
        }
        return "\(tag.emoji) \(tag.title)"
    }

    private func canOpenPublicProfile(_ person: DetailPerson) -> Bool {
        if let userID = person.userID, let currentUserID = currentSessionUserID {
            return userID != currentUserID
        }
        return person.firstName.lowercased() != "you"
    }

    private func openPublicProfile(for person: DetailPerson) {
        guard canOpenPublicProfile(person) else { return }
        selectedPublicProfile = PublicProfileData(
            id: person.id,
            userID: person.userID,
            displayName: person.displayName,
            bio: person.role == "Host" ? "Usually hosts curated hangouts around \(displayedCityName)." : "",
            instagram: "",
            website: "",
            city: displayedCityName
        )
    }

    private func dateOnlyLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: date)
    }

    private func timeOnlyLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func shortDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).uppercased()
    }

    private func timeRemainingText(from now: Date, to target: Date) -> String? {
        let interval = target.timeIntervalSince(now)
        if interval <= 0 { return nil }

        let hours = Int(interval / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)

        if hours > 0 {
            return "\(hours)h"
        }
        return "\(max(1, minutes))m"
    }

    private static func initialParticipants(from hangout: HangoutItem) -> [DetailPerson] {
        var items: [DetailPerson] = []
        let baseColors = ["#5C6BFF", "#FF5E7E", "#22B8A2", "#F18B4C", "#8A5DFF", "#3C91E6"]

        items.append(
            DetailPerson(
                id: "host-\(hangout.id)",
                userID: hangout.hostUserID,
                displayName: hangout.hostName,
                role: "Host",
                tint: Color(hex: "#5C6BFF"),
                hexColor: "#5C6BFF",
                isConfirmed: true
            )
        )

        let visibleParticipants = hangout.participantNames.filter {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != hangout.hostName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        for (index, name) in visibleParticipants.enumerated() {
            items.append(
                DetailPerson(
                    id: "person-\(hangout.id)-\(index)",
                    userID: nil,
                    displayName: name,
                    role: "Member",
                    tint: Color(hex: baseColors[index % baseColors.count]),
                    hexColor: baseColors[index % baseColors.count],
                    isConfirmed: index < hangout.approvedCount
                )
            )
        }

        return items
    }

    @MainActor
    private func hydrateRemoteState() async {
        do {
            let remote = try await session.fetchHangoutDetail(id: hangout.id)
            applyRemoteHangout(remote)

            if canOpenChat {
                try? await loadMessages()
            }
        } catch {
            actionFeedback = nil
        }
    }

    @MainActor
    private func applyRemoteHangout(_ remote: HangoutFeedItem) {
        isCancelledByHost = remote.status.lowercased() == "cancelled"
        displayedParticipants = mapParticipants(from: remote)
        joinRequests = mapJoinRequests(from: remote)
        let updatedMetadata = detailMetadata.applying(remote: remote)
        detailMetadata = updatedMetadata
        resolvedLocationCoordinate = validCoordinate(lat: updatedMetadata.latitude, lng: updatedMetadata.longitude)
        if joinRequests.isEmpty {
            selectedInfoPanel = 0
        }

        let currentUserID = currentSessionUserID
        if remote.host == currentUserID {
            localJoinStatus = .joined
            isWaitlisted = false
            return
        }

        let isApproved = remote.participants.contains {
            $0.user == currentUserID && $0.status.lowercased() == "approved"
        }
        if isApproved {
            localJoinStatus = .joined
            isWaitlisted = false
            return
        }

        if let myRequest = remote.joinRequests.first(where: { $0.user == currentUserID }) {
            localJoinStatus = .requested
            isWaitlisted = myRequest.status.lowercased() == "waitlisted"
        }
    }

    private func mapParticipants(from remote: HangoutFeedItem) -> [DetailPerson] {
        var items: [DetailPerson] = [
            DetailPerson(
                id: "host-\(remote.host)",
                userID: remote.host,
                displayName: remote.host == currentSessionUserID ? "you" : remote.hostUsername,
                role: "Host",
                tint: Color(hex: "#5C6BFF"),
                hexColor: "#5C6BFF",
                isConfirmed: true
            )
        ]

        let colors = ["#FF5E7E", "#22B8A2", "#F18B4C", "#8A5DFF", "#3C91E6", "#5C6BFF"]
        let approved = remote.participants.filter {
            $0.status.lowercased() == "approved" && $0.user != remote.host
        }
        for (index, person) in approved.enumerated() {
            items.append(
                DetailPerson(
                    id: "participant-\(person.id)",
                    userID: person.user,
                    displayName: person.user == currentSessionUserID ? "You" : person.username,
                    role: "Member",
                    tint: Color(hex: colors[index % colors.count]),
                    hexColor: colors[index % colors.count],
                    isConfirmed: true
                )
            )
        }
        return items
    }

    private func mapJoinRequests(from remote: HangoutFeedItem) -> [DetailJoinRequest] {
        let colors = ["#FF5E7E", "#22B8A2", "#F18B4C", "#8A5DFF"]
        return remote.joinRequests
            .filter { $0.status.lowercased() == "pending" || $0.status.lowercased() == "waitlisted" }
            .enumerated()
            .map { index, request in
                let color = colors[index % colors.count]
                return DetailJoinRequest(
                    id: String(request.id),
                    displayName: request.user == currentSessionUserID ? "You" : request.userUsername,
                    headline: request.status.lowercased() == "waitlisted" ? "Currently on the waitlist" : "Wants to join this hangout",
                    note: request.message?.isEmpty == false ? request.message ?? "" : "No intro message yet.",
                    city: hangout.cityName,
                    arrivalHint: request.status.lowercased() == "waitlisted" ? "Waitlisted" : "Pending",
                    tint: Color(hex: color),
                    hexColor: color
                )
            }
    }

    @MainActor
    private func loadMessages() async throws {
        let messages = try await session.fetchHangoutMessages(hangoutID: hangout.id)
        detailMessages = messages.map { message in
            let color = message.userId == currentSessionUserID ? detailAccentColor : Color(hex: "#5C6BFF")
            let createdAt = parseServerDate(message.createdAt)
            return DetailChatMessage(
                author: message.userId == currentSessionUserID ? "You" : message.userUsername,
                initials: String((message.userUsername.first ?? "U")).uppercased(),
                text: message.message,
                time: relativeTimeLabel(from: message.createdAt),
                tint: color,
                tintHex: message.userId == currentSessionUserID ? detailAccentHex : "#5C6BFF",
                createdAt: createdAt,
                isMine: message.userId == currentSessionUserID
            )
        }
    }

    @MainActor
    private func requestJoin() async {
        guard !isPerformingNetworkAction else { return }
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }

        do {
            let result = try await session.requestJoinHangout(id: hangout.id)
            localJoinStatus = .requested
            isWaitlisted = result.status.lowercased() == "waitlisted"
            actionFeedback = isWaitlisted ? "You are on the waitlist." : "Join request sent."
            onRequestJoin()
            await hydrateRemoteState()
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    @MainActor
    private func leaveHangout() async {
        guard !isPerformingNetworkAction else { return }
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }

        do {
            try await session.leaveHangout(id: hangout.id)
            localJoinStatus = .none
            actionFeedback = "You left the hangout."
            await hydrateRemoteState()
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    @MainActor
    private func cancelHangout() async {
        guard !isPerformingNetworkAction else { return }
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }

        do {
            try await session.cancelHangout(id: hangout.id)
            isCancelledByHost = true
            actionFeedback = "Hangout cancelled successfully."
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    @MainActor
    private func sendMessage(_ trimmed: String) async {
        guard !isPerformingNetworkAction else { return }
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }

        do {
            let created = try await session.sendHangoutMessage(hangoutID: hangout.id, message: trimmed)
            detailMessages.append(
                DetailChatMessage(
                    author: "You",
                    initials: "Y",
                    text: created.message,
                    time: "now",
                    tint: detailAccentColor,
                    tintHex: detailAccentHex,
                    createdAt: Date(),
                    isMine: true
                )
            )
            composerText = ""
            composerFocused = false
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    @MainActor
    private func acceptJoinRequestRemote(_ request: DetailJoinRequest) async {
        guard !isPerformingNetworkAction, let requestID = Int(request.id) else { return }
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }

        do {
            let remote = try await session.approveJoinRequest(hangoutID: hangout.id, requestID: requestID)
            applyRemoteHangout(remote)
            try? await loadMessages()
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    @MainActor
    private func declineJoinRequestRemote(_ request: DetailJoinRequest) async {
        guard !isPerformingNetworkAction, let requestID = Int(request.id) else { return }
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }

        do {
            let remote = try await session.rejectJoinRequest(hangoutID: hangout.id, requestID: requestID)
            applyRemoteHangout(remote)
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    private func relativeTimeLabel(from raw: String) -> String {
        guard let date = parseServerDate(raw) else { return "now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func parseServerDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: raw) ?? {
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: raw)
        }()
    }

    private func normalizedPresenceName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private enum PageCueDirection {
    case up
    case down
    case left
    case right

    var iconName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }
}

private enum DetailRole {
    case guest
    case pending
    case waitlisted
    case participant
    case host

    var title: String {
        switch self {
        case .guest: return "Guest"
        case .pending: return "Pending"
        case .waitlisted: return "Waitlist"
        case .participant: return "Joined"
        case .host: return "Host"
        }
    }
}

private struct DetailFactItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let subtitle: String
    let accent: Color
}

private struct DetailMetadata {
    var cityName: String
    var locationName: String?
    var locationAddress: String?
    var latitude: Double?
    var longitude: Double?
    var isCapacityUnlimited: Bool?
    var visibility: HangoutVisibilityOption?
    var inviteCode: String?
    var inviteCodeHint: String?
    var allowWaitlist: Bool?
    var genderPreference: HangoutGenderPreference?
    var audienceTags: [String]
    var languages: [String]
    var isTimeFlexible: Bool?
    var sourceEventID: Int?
    var sourceOfferID: Int?
    var coverImageURL: String?

    init(hangout: HangoutItem) {
        cityName = hangout.cityName
        locationName = hangout.locationName
        locationAddress = hangout.locationAddress
        latitude = hangout.latitude
        longitude = hangout.longitude
        isCapacityUnlimited = hangout.isCapacityUnlimited
        visibility = hangout.visibility
        inviteCode = hangout.inviteCode
        inviteCodeHint = hangout.inviteCodeHint
        allowWaitlist = hangout.allowWaitlist
        genderPreference = hangout.genderPreference
        audienceTags = hangout.audienceTags
        languages = hangout.languages
        isTimeFlexible = hangout.isTimeFlexible
        sourceEventID = hangout.sourceEventID
        sourceOfferID = hangout.sourceOfferID
        coverImageURL = hangout.coverImageURL
    }

    func applying(remote: HangoutFeedItem) -> DetailMetadata {
        var copy = self
        if !remote.cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.cityName = remote.cityName
        }
        copy.locationName = remote.locationName ?? copy.locationName
        copy.locationAddress = remote.locationAddress ?? copy.locationAddress
        copy.latitude = remote.lat ?? copy.latitude
        copy.longitude = remote.lng ?? copy.longitude
        copy.isCapacityUnlimited = remote.isCapacityUnlimited ?? copy.isCapacityUnlimited
        copy.visibility = remote.visibility.flatMap(HangoutVisibilityOption.init(backendRawValue:)) ?? copy.visibility
        copy.inviteCode = remote.inviteCode ?? copy.inviteCode
        copy.inviteCodeHint = remote.inviteCodeHint ?? copy.inviteCodeHint
        copy.allowWaitlist = remote.allowWaitlist ?? copy.allowWaitlist
        copy.genderPreference = remote.genderPreference.flatMap(HangoutGenderPreference.init(backendRawValue:)) ?? copy.genderPreference
        copy.audienceTags = remote.audienceTags.isEmpty ? copy.audienceTags : remote.audienceTags
        copy.languages = remote.languages.isEmpty ? copy.languages : remote.languages
        copy.isTimeFlexible = remote.isTimeFlexible ?? copy.isTimeFlexible
        copy.sourceEventID = remote.sourceEventId ?? copy.sourceEventID
        copy.sourceOfferID = remote.sourceOfferId ?? copy.sourceOfferID
        copy.coverImageURL = remote.coverImageUrl ?? copy.coverImageURL
        return copy
    }
}

private struct DetailPerson: Identifiable, Equatable {
    let id: String
    let userID: Int?
    let displayName: String
    let role: String
    let tint: Color
    let hexColor: String
    let isConfirmed: Bool

    var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let value = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return value.isEmpty ? "?" : value.uppercased()
    }
}

private struct DetailChatMessage: Identifiable {
    let id = UUID()
    let author: String
    let initials: String
    let text: String
    let time: String
    let tint: Color
    let tintHex: String
    let createdAt: Date?
    let isMine: Bool
}

private struct DetailLocationMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private struct DetailJoinRequest: Identifiable {
    let id: String
    let displayName: String
    let headline: String
    let note: String
    let city: String
    let arrivalHint: String
    let tint: Color
    let hexColor: String

    var initials: String {
        let parts = displayName.split(separator: " ")
        let value = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return value.isEmpty ? "?" : value.uppercased()
    }

    var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }
}

struct HangoutDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HangoutDetailView(
                hangout: HangoutItem(
                    id: 301,
                    sourceType: .hangout,
                    title: "Sunset rooftop meetup",
                    description: "Easygoing evening with music, natural wine and a small curated crowd.",
                    vibe: .chill,
                    cityName: "Berlin",
                    locationName: "Rooftop bar",
                    hostUserID: 42,
                    hostName: "Nina",
                    startAt: Date().addingTimeInterval(60 * 60 * 5),
                    endAt: Date().addingTimeInterval(60 * 60 * 7),
                    capacity: 8,
                    approvedCount: 5,
                    isJoined: true,
                    participantNames: ["Sofia", "Luca", "Mara", "Daniel"],
                    coverImageData: nil,
                    coverSeed: 0,
                    distanceKm: 1.2,
                    priceTier: .budget
                ),
                joinStatus: .joined,
                onRequestJoin: {},
                onCancelRequest: {}
            )
        }
    }
}
