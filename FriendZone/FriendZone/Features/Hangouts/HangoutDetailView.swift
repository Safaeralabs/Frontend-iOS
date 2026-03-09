import SwiftUI
import UIKit

struct HangoutDetailView: View {
    let hangout: HangoutItem
    let onRequestJoin: () -> Void
    let onCancelRequest: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var localJoinStatus: HangoutJoinStatus
    @State private var isWaitlisted: Bool
    @State private var isCancelledByHost = false
    @State private var isShowingMoreMenu = false
    @State private var isShowingReportSent = false
    @State private var isShowingCancelHangoutConfirm = false
    @State private var selectedPublicProfile: NativePublicProfileDescriptor?
    @State private var selectedPage = 0
    @State private var selectedInfoPanel = 0
    @GestureState private var pageDragOffset: CGFloat = 0
    @GestureState private var infoPanelDragOffset: CGFloat = 0
    @State private var displayedParticipants: [DetailPerson]
    @State private var joinRequests: [DetailJoinRequest]
    @State private var detailMessages: [DetailChatMessage]
    @State private var composerText = ""
    @FocusState private var composerFocused: Bool

    init(
        hangout: HangoutItem,
        joinStatus: HangoutJoinStatus,
        onRequestJoin: @escaping () -> Void,
        onCancelRequest: @escaping () -> Void
    ) {
        self.hangout = hangout
        self.onRequestJoin = onRequestJoin
        self.onCancelRequest = onCancelRequest
        _localJoinStatus = State(initialValue: joinStatus)
        _isWaitlisted = State(initialValue: joinStatus == .requested && hangout.isFull)
        _displayedParticipants = State(initialValue: Self.seedParticipants(from: hangout))
        _joinRequests = State(initialValue: Self.seedJoinRequests(from: hangout))
        _detailMessages = State(initialValue: Self.seedActivityMessages(from: hangout))
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

                    activityPage(topInset: topInset, pageHeight: pageHeight)
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
                isCancelledByHost = true
            }
        } message: {
            Text("Participants will be notified that this hangout was cancelled.")
        }
        .sheet(item: $selectedPublicProfile) { profile in
            NavigationStack {
                NativePublicProfileHubView(
                    profile: profile,
                    onClose: { selectedPublicProfile = nil }
                )
            }
            .background(FriendZoneTheme.Colors.background)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: "#F5F4FB"),
                Color(hex: "#FAFAFD"),
                Color(hex: "#F2F3F8")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                .padding(.top, topInset + 2)

            peopleLocationCard
                .padding(.top, 10)

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
        .padding(.horizontal, 20)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func requestsPanel(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            joinRequestsCard
                .padding(.top, topInset + 2)

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
        .padding(.horizontal, 20)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func activityPage(topInset: CGFloat, pageHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            activityHeader
                .padding(.top, topInset + 2)

            Group {
                if canOpenChat {
                    activityChatCard
                } else {
                    activityLockedCard
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: min(500, pageHeight * 0.68), maxHeight: min(640, pageHeight * 0.76))

            Spacer(minLength: 0)

            primaryBottomAction
                .padding(.bottom, 8)

            pageCue(
                title: "Swipe down for hangout info",
                subtitle: "Back to the pass",
                direction: .down
            )
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func topNav(topInset: CGFloat) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
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
        .padding(.horizontal, 20)
        .padding(.top, topInset + 2)
    }

    private var ticketCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if let coverUIImage {
                    Image(uiImage: coverUIImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.26), lineWidth: 1)
                        }
                        .padding(.bottom, 14)
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(subtitleText.uppercased())
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .tracking(0.8)

                        Text(hangout.title)
                            .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .lineLimit(3)

                        Text(hangout.description)
                            .font(FriendZoneTheme.Typography.system(12, weight: .regular))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .lineSpacing(2)
                            .lineLimit(4)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 8) {
                        ticketAccentPill(detailCountdownText, tint: detailAccentColor)

                        Text(timeOnlyLabel(hangout.startAt))
                            .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                        Text(shortDateLabel(hangout.startAt))
                            .font(FriendZoneTheme.Typography.system(9, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                HStack(spacing: 8) {
                    ticketMetaPill(dateOnlyLabel(hangout.startAt).uppercased())
                    ticketMetaPill(durationLabel)
                    ticketMetaPill(audienceSummary.uppercased())
                }
                .padding(.top, 14)

                HStack(spacing: 8) {
                    ticketMetaPill(isLocationHidden ? "LOCATION TBA" : hangout.locationDisplay.uppercased())
                    ticketMetaPill("LANG EN")
                }
                .padding(.top, 8)

                hostStrip
                    .padding(.top, 14)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            detailPerforationLine
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("People")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.7)

                    Text("\(approvedParticipantsCount)/\(hangout.capacity)")
                        .font(FriendZoneTheme.Typography.system(22, weight: .heavy))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(spotsLabel)
                        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                        .foregroundColor(detailSpotsColor)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Host")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.7)

                    Text(hangout.hostName)
                        .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(isLocationHidden ? "Location unlocks after acceptance" : hangout.locationDisplay)
                        .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(FriendZoneTheme.Colors.surface)
        .mask(detailTicketClipMask)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                .mask(detailTicketClipMask)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
        .frame(maxWidth: 392)
    }

    private var hostStrip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(detailAccentColor.opacity(0.16))
                .frame(width: 30, height: 30)
                .overlay {
                    Text(String(hangout.hostName.prefix(1)).uppercased())
                        .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                        .foregroundColor(detailAccentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(isHost ? "You are hosting" : "Hosted by \(hangout.hostName)")
                    .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(isHost ? "Manage requests and activity from the next section." : "Community-led small group hangout.")
                    .font(FriendZoneTheme.Typography.system(10, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        .background(FriendZoneTheme.Colors.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var activityHeader: some View {
        VStack(spacing: 4) {
            Text("Hangout Activity")
                .font(FriendZoneTheme.Typography.system(20, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(canOpenChat ? "Live group chat" : "Activity unlocks once the host accepts you")
                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var activityChatCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat")
                        .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text("\(detailMessages.count) messages")
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
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(detailMessages) { message in
                        activityMessageBubble(message)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
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
                .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.65))
        }
        .background(FriendZoneTheme.Colors.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .frame(maxHeight: .infinity)
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
        .background(FriendZoneTheme.Colors.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var peopleLocationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("People & Location")
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Spacer(minLength: 0)

                Text("\(displayedParticipants.count) total")
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayedParticipants) { person in
                        Button {
                            openPublicProfile(for: person)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    participantAvatar(for: person.initials, color: person.tint, size: 44)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(person.firstName)
                                            .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                            .lineLimit(1)

                                        Text(person.role)
                                            .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)
                                }

                                Text(person.isConfirmed ? "Confirmed" : "Pending")
                                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                                    .foregroundColor(person.isConfirmed ? person.tint : FriendZoneTheme.Colors.textTertiary)
                                    .padding(.horizontal, 8)
                                    .frame(height: 24)
                                    .background(
                                        (person.isConfirmed ? person.tint.opacity(0.12) : Color.black.opacity(0.05))
                                    )
                                    .clipShape(Capsule())
                            }
                            .padding(12)
                            .frame(width: 148, alignment: .leading)
                            .background(FriendZoneTheme.Colors.surfaceElevated.opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()
                .overlay(FriendZoneTheme.Colors.borderSubtle)

            VStack(alignment: .leading, spacing: 6) {
                Text("Location")
                    .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                Text(locationStatusTitle)
                    .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(locationStatusSubtitle)
                    .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .lineSpacing(1.8)
            }
        }
        .padding(16)
        .background(FriendZoneTheme.Colors.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
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
        .background(FriendZoneTheme.Colors.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
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
                    acceptJoinRequest(request)
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
                    declineJoinRequest(request)
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
        .background(FriendZoneTheme.Colors.surfaceElevated.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                    localJoinStatus = .none
                }
            } else if localJoinStatus == .requested {
                bottomActionButton(
                    title: isWaitlisted ? "Leave Waitlist" : "Cancel Request",
                    subtitle: isWaitlisted ? "You will stop waiting for a free place" : "Withdraw your join request",
                    tint: FriendZoneTheme.Colors.textPrimary,
                    isEnabled: !isEnded
                ) {
                    isWaitlisted = false
                    localJoinStatus = .none
                    onCancelRequest()
                }
            } else {
                bottomActionButton(
                    title: hangout.isFull ? "Join Waitlist" : "Request to Join",
                    subtitle: hangout.isFull ? "You will be notified if a place opens" : "The host will review your request",
                    tint: detailAccentColor,
                    isEnabled: !(isEnded || isCancelledByHost)
                ) {
                    localJoinStatus = .requested
                    isWaitlisted = hangout.isFull
                    onRequestJoin()
                }
            }
        }
        .frame(maxWidth: .infinity)
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        detailMessages.append(
            DetailChatMessage(
                author: "You",
                initials: "Y",
                text: trimmed,
                time: "now",
                tint: detailAccentColor,
                isMine: true
            )
        )
        composerText = ""
        composerFocused = false
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

    private var isHost: Bool {
        hangout.hostName.lowercased() == "you"
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
        timeRemainingText(from: Date(), to: hangout.startAt) ?? "SOON"
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

    private var coverUIImage: UIImage? {
        guard let data = hangout.coverImageData else { return nil }
        return UIImage(data: data)
    }

    private var locationStatusTitle: String {
        if isLocationHidden {
            return "Exact location hidden"
        }
        return hangout.locationDisplay
    }

    private var locationStatusSubtitle: String {
        if isLocationHidden {
            return "The host shares the final meeting point once your request is accepted."
        }
        return "\(hangout.cityName) · Meet there around \(timeOnlyLabel(hangout.startAt))"
    }

    private func canOpenPublicProfile(_ person: DetailPerson) -> Bool {
        person.firstName.lowercased() != "you"
    }

    private func openPublicProfile(for person: DetailPerson) {
        guard canOpenPublicProfile(person) else { return }
        selectedPublicProfile = NativePublicProfileDescriptor(
            id: person.id,
            displayName: person.displayName,
            roleLabel: person.role,
            city: hangout.cityName,
            bio: person.role == "Host" ? "Creates intimate social plans around \(hangout.cityName)." : "Usually joins small curated plans, dinners and micro-events.",
            accentHex: person.hexColor
        )
    }

    private func acceptJoinRequest(_ request: DetailJoinRequest) {
        joinRequests.removeAll { $0.id == request.id }
        displayedParticipants.append(
            DetailPerson(
                id: request.id,
                displayName: request.displayName,
                role: "Member",
                tint: request.tint,
                hexColor: request.hexColor,
                isConfirmed: true
            )
        )
        detailMessages.insert(
            DetailChatMessage(
                author: hangout.hostName,
                initials: String(hangout.hostName.prefix(1)).uppercased(),
                text: "\(request.firstName) just joined the hangout.",
                time: "now",
                tint: detailAccentColor,
                isMine: false
            ),
            at: 0
        )
        if joinRequests.isEmpty {
            selectedInfoPanel = 0
        }
    }

    private func declineJoinRequest(_ request: DetailJoinRequest) {
        joinRequests.removeAll { $0.id == request.id }
        if joinRequests.isEmpty {
            selectedInfoPanel = 0
        }
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

    private static func seedParticipants(from hangout: HangoutItem) -> [DetailPerson] {
        var items: [DetailPerson] = []
        let baseColors = ["#5C6BFF", "#FF5E7E", "#22B8A2", "#F18B4C", "#8A5DFF", "#3C91E6"]

        items.append(
            DetailPerson(
                id: "host-\(hangout.id)",
                displayName: hangout.hostName,
                role: "Host",
                tint: Color(hex: "#5C6BFF"),
                hexColor: "#5C6BFF",
                isConfirmed: true
            )
        )

        for (index, name) in hangout.participantNames.enumerated() {
            items.append(
                DetailPerson(
                    id: "person-\(hangout.id)-\(index)",
                    displayName: name,
                    role: "Member",
                    tint: Color(hex: baseColors[index % baseColors.count]),
                    hexColor: baseColors[index % baseColors.count],
                    isConfirmed: index < hangout.approvedCount
                )
            )
        }

        if items.count < 6 {
            let extras = ["Sofia", "Daniel", "Mara", "Luca"]
            for (index, name) in extras.prefix(6 - items.count).enumerated() {
                let color = baseColors[(index + items.count) % baseColors.count]
                items.append(
                    DetailPerson(
                        id: "extra-\(hangout.id)-\(index)",
                        displayName: name,
                        role: "Member",
                        tint: Color(hex: color),
                        hexColor: color,
                        isConfirmed: true
                    )
                )
            }
        }

        return items
    }

    private static func seedActivityMessages(from hangout: HangoutItem) -> [DetailChatMessage] {
        [
            DetailChatMessage(author: hangout.hostName, initials: String(hangout.hostName.prefix(1)).uppercased(), text: "See you all at \(hangout.startAt.formatted(date: .omitted, time: .shortened)).", time: "2m", tint: Color(hex: "#5C6BFF"), isMine: false),
            DetailChatMessage(author: "Mara", initials: "M", text: "I can arrive a bit earlier if needed.", time: "2m", tint: Color(hex: "#FF5E7E"), isMine: false),
            DetailChatMessage(author: "Luca", initials: "L", text: "Perfect. I will head there after work.", time: "1m", tint: Color(hex: "#22B8A2"), isMine: false),
            DetailChatMessage(author: "You", initials: "Y", text: "Great, I am in.", time: "1m", tint: Color(hex: "#5C6BFF"), isMine: true),
            DetailChatMessage(author: hangout.hostName, initials: String(hangout.hostName.prefix(1)).uppercased(), text: "Final spot details are in the location card below.", time: "now", tint: Color(hex: "#5C6BFF"), isMine: false)
        ]
    }

    private static func seedJoinRequests(from hangout: HangoutItem) -> [DetailJoinRequest] {
        guard hangout.hostName.lowercased() == "you" else { return [] }

        return [
            DetailJoinRequest(
                id: "request-\(hangout.id)-1",
                displayName: "Mia Flores",
                headline: "Enjoys intimate dinners and rooftop plans",
                note: "I am nearby and can arrive on time. Happy to bring one more friend if needed.",
                city: hangout.cityName,
                arrivalHint: "On time",
                tint: Color(hex: "#FF5E7E"),
                hexColor: "#FF5E7E"
            ),
            DetailJoinRequest(
                id: "request-\(hangout.id)-2",
                displayName: "Jonas Weber",
                headline: "Usually joins artsy social plans",
                note: "Looking for a calm group tonight. This one looks like my vibe.",
                city: hangout.cityName,
                arrivalHint: "10 min away",
                tint: Color(hex: "#22B8A2"),
                hexColor: "#22B8A2"
            )
        ]
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

private struct DetailPerson: Identifiable, Equatable {
    let id: String
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
    let isMine: Bool
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

private struct NativePublicProfileDescriptor: Identifiable {
    let id: String
    let displayName: String
    let roleLabel: String
    let city: String
    let bio: String
    let accentHex: String
}

private struct NativePublicProfileHubView: View {
    let profile: NativePublicProfileDescriptor
    let onClose: () -> Void

    var body: some View {
        ZStack {
            FriendZoneTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Button("Done") {
                        onClose()
                    }
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
                }

                Circle()
                    .fill(Color(hex: profile.accentHex).opacity(0.16))
                    .frame(width: 94, height: 94)
                    .overlay {
                        Text(String(profile.displayName.prefix(1)).uppercased())
                            .font(FriendZoneTheme.Typography.system(34, weight: .heavy))
                            .foregroundColor(Color(hex: profile.accentHex))
                    }

                VStack(spacing: 6) {
                    Text(profile.displayName)
                        .font(FriendZoneTheme.Typography.system(28, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text("\(profile.roleLabel) · \(profile.city)")
                        .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Text(profile.bio)
                    .font(FriendZoneTheme.Typography.system(14, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 18)

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .toolbar(.hidden, for: .navigationBar)
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
                    hostName: "Nina",
                    startAt: Date().addingTimeInterval(60 * 60 * 5),
                    endAt: Date().addingTimeInterval(60 * 60 * 7),
                    capacity: 8,
                    approvedCount: 5,
                    isLive: false,
                    isMicro: true,
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
