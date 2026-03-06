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
    @State private var isShowingChatNotice = false

    @State private var displayedParticipants: [DetailPerson]
    @State private var pendingJoinRequests: [DetailJoinRequest]
    @State private var waitlistMembers: [DetailPerson]
    @State private var currentRequestIndex = 0
    @State private var requestTransitionDirection: RequestTransitionDirection = .pass

    init(
        hangout: HangoutItem,
        joinStatus: HangoutJoinStatus,
        onRequestJoin: @escaping () -> Void,
        onCancelRequest: @escaping () -> Void
    ) {
        self.hangout = hangout
        self.onRequestJoin = onRequestJoin
        self.onCancelRequest = onCancelRequest

        let hostMode = hangout.hostName.lowercased() == "you"

        _localJoinStatus = State(initialValue: joinStatus)
        _isWaitlisted = State(initialValue: joinStatus == .requested && hangout.isFull)
        _displayedParticipants = State(initialValue: Self.seedParticipants(from: hangout))
        _pendingJoinRequests = State(initialValue: Self.seedPendingRequests(from: hangout, enabled: hostMode))
        _waitlistMembers = State(initialValue: Self.seedWaitlist(from: hangout, enabled: hostMode))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: "#F3F4FA")
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection

                        if isEnded {
                            endedBanner
                        }

                        locationSection

                        if isHost && !isEnded {
                            joinRequestsSection
                        }

                        participantsSection

                        if isHost && !waitlistMembers.isEmpty {
                            waitlistSection
                        }

                        if !canOpenChat && !isEnded && !isHost {
                            lockedChatMessage
                        }

                        if currentRole == .pending && !isEnded && !isHost {
                            pendingMessage
                        } else if currentRole == .waitlisted && !isEnded && !isHost {
                            waitlistedMessage
                        }
                    }
                    .padding(.top, max(72, proxy.safeAreaInsets.top + 58))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 180)
                    .frame(maxWidth: 448)
                    .frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .top) {
                topNav(topInset: proxy.safeAreaInsets.top)
            }
            .overlay(alignment: .bottom) {
                bottomFloatingLayer
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Hangout actions",
            isPresented: $isShowingMoreMenu,
            titleVisibility: .visible
        ) {
            Button("Report Hangout", role: .destructive) {
                isShowingReportSent = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Report sent", isPresented: $isShowingReportSent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks. We will review this hangout.")
        }
        .alert("Chat coming soon", isPresented: $isShowingChatNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Native group chat will be connected in a next step.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                detailTicketTopLabel
                    .padding(.bottom, 10)

                if let coverUIImage {
                    coverUIImage
                        .resizable()
                        .scaledToFill()
                        .frame(height: 172)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        }
                        .padding(.bottom, 12)
                }

                Text(hangout.title)
                    .font(FriendZoneTheme.Typography.system(28, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 7)

                Text(subtitleText)
                    .font(FriendZoneTheme.Typography.system(13, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .padding(.bottom, 10)

                Text(hangout.description)
                    .font(FriendZoneTheme.Typography.system(13, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .lineSpacing(1.2)
                    .lineLimit(3)
                    .padding(.bottom, 10)

                Text("TBA")
                    .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .padding(.bottom, 10)

                HStack(spacing: 4) {
                    Image(systemName: isHost ? "crown.fill" : "scope")
                        .font(.system(size: 11, weight: .bold))
                    Text("Hosted by \(hangout.hostName)")
                }
                .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                .foregroundColor(isHost ? detailAccentColor : FriendZoneTheme.Colors.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)

            detailPerforationLine
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Text(detailCountdownText)
                        .font(FriendZoneTheme.Typography.system(15, weight: .heavy))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(detailAccentColor.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(detailAccentColor.opacity(0.28), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(timeOnlyLabel(hangout.startAt))
                            .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                        Text(shortDateLabel(hangout.startAt))
                            .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }

                    Spacer(minLength: 0)

                    Text(detailSpotsText)
                        .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                        .foregroundColor(detailSpotsColor)
                }

                detailTicketBarcode
                    .frame(height: 24, alignment: .bottom)

                Text(detailTicketCode)
                    .font(FriendZoneTheme.Typography.system(9, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(0.7)

                HStack(spacing: 8) {
                    detailMetaPill("LANG EN")
                    detailMetaPill("CAP \(approvedParticipantsCount)/\(hangout.capacity)")
                    detailMetaPill("DUR \(detailDurationLabel)")
                }
                .padding(.top, 2)

                Text(audienceSummary.uppercased())
                    .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(FriendZoneTheme.Colors.surface)
        .mask(detailTicketClipMask)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                .mask(detailTicketClipMask)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    private var detailTicketTopLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(detailAccentColor)

            Text("HANGOUT PASS")
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.8)
        }
    }

    private var detailPerforationLine: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 52, id: \.self) { _ in
                Circle()
                    .fill(FriendZoneTheme.Colors.borderSubtle.opacity(0.95))
                    .frame(width: 2.3, height: 2.3)
            }
        }
    }

    private var detailTicketBarcode: some View {
        HStack(alignment: .bottom, spacing: 0.8) {
            ForEach(Array(detailBarcodeBars.enumerated()), id: \.offset) { _, bar in
                Rectangle()
                    .fill(Color.black.opacity(bar.opacity))
                    .frame(width: bar.width, height: bar.height)
            }
        }
        .frame(height: 24, alignment: .bottom)
    }

    private func detailMetaPill(_ text: String) -> some View {
        Text(text)
            .font(FriendZoneTheme.Typography.system(9, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(Color.black.opacity(0.05))
            .clipShape(Capsule())
    }

    private var detailTicketClipMask: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white)
            .overlay {
                detailTicketPunchHoles
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    private var detailTicketPunchHoles: some View {
        GeometryReader { proxy in
            let sideRadius: CGFloat = 4.8
            let centerRadius: CGFloat = 10
            let centerX = proxy.size.width * 0.5
            let topInset: CGFloat = 16
            let bottomInset: CGFloat = 16
            let count = 10
            let usableHeight = max(0, proxy.size.height - topInset - bottomInset)
            let step = usableHeight / CGFloat(max(1, count - 1))

            ZStack {
                ForEach(0 ..< count, id: \.self) { index in
                    let y = topInset + CGFloat(index) * step

                    Circle()
                        .fill(Color.black)
                        .frame(width: sideRadius * 2, height: sideRadius * 2)
                        .position(x: 0, y: y)

                    Circle()
                        .fill(Color.black)
                        .frame(width: sideRadius * 2, height: sideRadius * 2)
                        .position(x: proxy.size.width, y: y)
                }

                Circle()
                    .fill(Color.black)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: centerX, y: 0)

                Circle()
                    .fill(Color.black)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: centerX, y: proxy.size.height)
            }
        }
    }

    private var endedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.error)

            Text(isCancelledByHost ? "This hangout has been cancelled" : "This hangout has ended")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.error)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.09), Color.red.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        }
    }

    private var infoGridSection: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                infoCard(title: "DATE", value: dateOnlyLabel(hangout.startAt), icon: "calendar")
                infoCard(title: "TIME", value: timeOnlyLabel(hangout.startAt), icon: "clock")
                infoCard(title: "CAPACITY", value: capacityLabel, icon: "person.2")
                infoCard(title: "LANGUAGE", value: "EN", icon: "globe")
            }

            infoWideCard(title: "THE VIBE", value: hangout.vibe.title, icon: "sparkles")
            infoWideCard(title: "AUDIENCE", value: audienceSummary, icon: "line.3.horizontal.decrease.circle")
        }
    }

    private var locationSection: some View {
        Group {
            if isLocationHidden {
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }

                    Text("Location Hidden")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text("Revealed after your request is approved")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("LOCATION")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .tracking(1.2)

                        Text(hangout.locationDisplay)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
            }
        }
    }

    private var hostSection: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(String(hangout.hostName.prefix(1)).uppercased())
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    }

                Circle()
                    .fill(FriendZoneTheme.Colors.success)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle().stroke(Color.white, lineWidth: 2)
                    }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(hangout.hostName)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    if isHost {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                    }
                }

                Text("\(max(1, hangout.id % 12 + 3)) hangouts hosted")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            Text("Profile")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ABOUT THIS PLAN")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(1.2)

            Text(hangout.description)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .regular))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineSpacing(2)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var joinRequestsSection: some View {
        if let request = currentPendingRequest {
            VStack(alignment: .leading, spacing: 8) {
                Text("JOIN REQUESTS (\(pendingJoinRequests.count))")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1.2)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        participantAvatar(request.username)
                            .onTapGesture {
                                FriendZoneHaptics.selection()
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.username)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                .lineLimit(1)

                            Text("@\(request.username.lowercased())")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        }

                        Spacer(minLength: 0)

                        Text("PENDING")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(FriendZoneTheme.Colors.surfaceMuted)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                            }
                    }

                    if let message = request.message {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MESSAGE")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(1.1)

                            Text("\"\(message)\"")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .regular))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                .lineLimit(2)
                        }
                        .padding(.top, 14)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(FriendZoneTheme.Colors.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                        .padding(.top, 14)
                    }

                    HStack {
                        Text("\(currentRequestIndex + 1) of \(pendingJoinRequests.count)")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            Button {
                                handleRejectCurrentRequest()
                            } label: {
                                Text("Pass")
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                    .frame(minWidth: 94)
                                    .frame(height: 38)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)

                            Button {
                                handleApproveCurrentRequest()
                            } label: {
                                Text("Welcome")
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                    .frame(minWidth: 94)
                                    .frame(height: 38)
                                    .background(FriendZoneTheme.Colors.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 14)
                }
                .id(request.id)
                .transition(requestCardTransition)
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            }
        }
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PARTICIPANTS (\(displayedParticipants.count))")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(1.2)

            VStack(spacing: 6) {
                ForEach(displayedParticipants) { person in
                    HStack(spacing: 10) {
                        participantAvatar(person.name)

                        Text(person.name)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if person.isHost {
                            Text("HOST")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                .padding(.horizontal, 8)
                                .frame(height: 20)
                                .background(
                                    LinearGradient(
                                        colors: [FriendZoneTheme.Colors.warning, FriendZoneTheme.Colors.warning.opacity(0.75)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        } else if isHost && !isEnded {
                            Button {
                                removeParticipant(person)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(FriendZoneTheme.Colors.error)
                                    .frame(width: 26, height: 26)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle().stroke(Color.red.opacity(0.32), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                }
            }
        }
    }

    private var waitlistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("WAITLIST (\(waitlistMembers.count))")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1.2)

                Text("Auto-promoted when spots open")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            VStack(spacing: 6) {
                ForEach(waitlistMembers) { person in
                    HStack(spacing: 10) {
                        participantAvatar(person.name)

                        Text(person.name)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text("WAITLIST")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.warning)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(Color(hex: "#F59E0B").opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(hex: "#F59E0B").opacity(0.30), lineWidth: 1)
                            }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                }
            }
        }
    }

    private var lockedChatMessage: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .bold))
            Text("Chat available after you're accepted")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
        }
        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FriendZoneTheme.Colors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                .stroke(FriendZoneTheme.Colors.primary.opacity(0.20), lineWidth: 1)
        }
    }

    private var pendingMessage: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 14, weight: .bold))
            Text("Your request is pending approval")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
        }
        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#F59E0B").opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                .stroke(Color(hex: "#F59E0B").opacity(0.32), lineWidth: 1)
        }
    }

    private var waitlistedMessage: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 14, weight: .bold))
            Text("You're on the waitlist. We'll notify you if a spot opens.")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
        }
        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#F59E0B").opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous)
                .stroke(Color(hex: "#F59E0B").opacity(0.25), lineWidth: 1)
        }
    }

    private func topNav(topInset: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#F3F4FA"), Color(hex: "#F3F4FA").opacity(0.92), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100 + topInset)
            .allowsHitTesting(false)

            HStack {
                navButton(icon: "chevron.left") {
                    dismiss()
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    ShareLink(item: shareURL) {
                        navButtonLabel(icon: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)

                    navButton(icon: "ellipsis") {
                        isShowingMoreMenu = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, max(8, topInset + 2))
            .frame(maxWidth: 448)
            .frame(maxWidth: .infinity)
        }
    }

    private var bottomFloatingLayer: some View {
        ZStack(alignment: .bottomTrailing) {
            actionButton

            if canOpenChat {
                Button {
                    isShowingChatNotice = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(width: 56, height: 56)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(Circle())
                        .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.35), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 106)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isEnded {
            EmptyView()
        } else {
            switch currentRole {
            case .guest:
                Button {
                    onRequestJoin()
                    localJoinStatus = .requested
                    isWaitlisted = isCapacityFullForRequest
                } label: {
                    HStack(spacing: 8) {
                        Text(hangout.sourceType == .offer ? "Join Offer" : "Join Circle")
                        Image(systemName: "arrow.right")
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(Capsule())
                    .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 106)
                .frame(maxWidth: 448)
                .frame(maxWidth: .infinity)
            case .pending:
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                    Text("Request Sent")
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(FriendZoneTheme.Colors.textTertiary)
                .clipShape(Capsule())
                .padding(.horizontal, 24)
                .padding(.bottom, 106)
                .frame(maxWidth: 448)
                .frame(maxWidth: .infinity)
            case .waitlisted:
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("On Waitlist")
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(FriendZoneTheme.Colors.textTertiary)
                .clipShape(Capsule())
                .padding(.horizontal, 24)
                .padding(.bottom, 106)
                .frame(maxWidth: 448)
                .frame(maxWidth: .infinity)
            case .participant:
                Button {
                    onCancelRequest()
                    localJoinStatus = .none
                    isWaitlisted = false
                } label: {
                    Text("Leave Hangout")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(FriendZoneTheme.Colors.error.opacity(0.35), lineWidth: 1.6)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 106)
                .frame(maxWidth: 448)
                .frame(maxWidth: .infinity)
            case .host:
                Button {
                    isCancelledByHost = true
                } label: {
                    Text("Cancel Hangout")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(FriendZoneTheme.Colors.error.opacity(0.35), lineWidth: 1.6)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 106)
                .frame(maxWidth: 448)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            navButtonLabel(icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func navButtonLabel(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            .frame(width: 40, height: 40)
            .background(Color.white)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
    }

    private func infoCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)

            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(1.1)

            Text(value)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.primary.opacity(0.20), lineWidth: 1)
        }
    }

    private func infoWideCard(title: String, value: String, icon: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1.1)

                Text(value)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            }

            Spacer(minLength: 0)

            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.primary.opacity(0.20), lineWidth: 1)
        }
    }

    private func participantAvatar(_ name: String) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textInverse)
            .frame(width: 36, height: 36)
            .background(
                LinearGradient(
                    colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }

    private func handleApproveCurrentRequest() {
        guard let request = currentPendingRequest else { return }
        requestTransitionDirection = .welcome
        removeCurrentPendingRequest(animated: true)

        let approvedPerson = DetailPerson(id: request.userID, name: request.username, isHost: false)

        if approvedParticipantsCount < hangout.capacity {
            displayedParticipants.append(approvedPerson)
        } else {
            waitlistMembers.append(approvedPerson)
        }
    }

    private func handleRejectCurrentRequest() {
        requestTransitionDirection = .pass
        removeCurrentPendingRequest(animated: true)
    }

    private func removeCurrentPendingRequest(animated: Bool) {
        guard !pendingJoinRequests.isEmpty else { return }
        let mutate = {
            pendingJoinRequests.remove(at: currentRequestIndex)
            if pendingJoinRequests.isEmpty {
                currentRequestIndex = 0
            } else {
                currentRequestIndex = min(currentRequestIndex, pendingJoinRequests.count - 1)
            }
        }

        if animated {
            withAnimation(FriendZoneTheme.Motion.easeOutExpo) {
                mutate()
            }
        } else {
            mutate()
        }
    }

    private func removeParticipant(_ person: DetailPerson) {
        guard !person.isHost else { return }
        guard let index = displayedParticipants.firstIndex(where: { $0.id == person.id }) else { return }

        displayedParticipants.remove(at: index)

        if !waitlistMembers.isEmpty, approvedParticipantsCount < hangout.capacity {
            let promoted = waitlistMembers.removeFirst()
            displayedParticipants.append(DetailPerson(id: promoted.id, name: promoted.name, isHost: false))
        }
    }

    private var subtitleText: String {
        if isHost {
            return "You are managing this hangout"
        }
        if hangout.sourceType == .offer {
            return "Venue offer ticket"
        }
        if hangout.sourceType == .event {
            return "Event-based hangout"
        }
        return "Community hangout ticket"
    }

    private var audienceSummary: String {
        switch hangout.sourceType {
        case .hangout: return "Open to everyone"
        case .event: return "Event community"
        case .offer: return "Venue community"
        }
    }

    private var isHost: Bool {
        hangout.hostName.lowercased() == "you"
    }

    private var isEnded: Bool {
        isCancelledByHost || hangout.endAt <= Date()
    }

    private var isLocationHidden: Bool {
        !isHost && localJoinStatus != .joined
    }

    private var canOpenChat: Bool {
        !isEnded && (currentRole == .participant || currentRole == .host)
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
        displayedParticipants.filter { !$0.isHost }.count
    }

    private var capacityLabel: String {
        let left = max(0, hangout.capacity - approvedParticipantsCount)
        if left == 0 {
            return "\(approvedParticipantsCount) / \(hangout.capacity) (Full)"
        }
        return "\(approvedParticipantsCount) / \(hangout.capacity) (\(left) left)"
    }

    private var isCapacityFullForRequest: Bool {
        approvedParticipantsCount >= hangout.capacity
    }

    private var currentPendingRequest: DetailJoinRequest? {
        guard !pendingJoinRequests.isEmpty else { return nil }
        guard currentRequestIndex < pendingJoinRequests.count else { return nil }
        return pendingJoinRequests[currentRequestIndex]
    }

    private var shareURL: URL {
        URL(string: "https://friendzone.app/hangout/\(hangout.id)")!
    }

    private var requestCardTransition: AnyTransition {
        switch requestTransitionDirection {
        case .pass:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .welcome:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private func dateOnlyLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: value)
    }

    private func timeOnlyLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func shortDateLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: value).uppercased()
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

    private var detailCountdownText: String {
        timeRemainingText(from: Date(), to: hangout.startAt) ?? "SOON"
    }

    private var detailSpotsText: String {
        let left = max(0, hangout.capacity - approvedParticipantsCount)
        return left == 0 ? "Full" : "\(left) Left"
    }

    private var detailSpotsColor: Color {
        detailSpotsText == "Full" ? FriendZoneTheme.Colors.error : detailAccentColor
    }

    private var detailTicketCode: String {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: hangout.startAt)
        let day = String(format: "%02d", components.day ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let year = String(components.year ?? 0)
        return "\(cityCode)-\(day)-\(month)-\(hangout.id)-\(year)"
    }

    private var detailDurationLabel: String {
        let hours = max(1, Int(round(hangout.endAt.timeIntervalSince(hangout.startAt) / 3600)))
        return "\(hours)h"
    }

    private var detailBarcodeBars: [(width: CGFloat, height: CGFloat, opacity: CGFloat)] {
        let base = "\(detailTicketCode)|\(hangout.startAt.timeIntervalSince1970)|\(hangout.hostName)"
        var result: [(width: CGFloat, height: CGFloat, opacity: CGFloat)] = []
        let widths: [CGFloat] = [0.8, 1.2, 1.6]

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
                result.append((1.8, 24, 0.9))
                result.append((0.8, 18, 0.88))
                result.append((1.8, 24, 0.9))
            }
        }

        result.append((1.8, 24, 0.9))
        result.append((0.8, 18, 0.88))
        result.append((1.8, 24, 0.9))

        while result.count < 40 {
            result.append((1.0, 20, 0.85))
        }
        return result
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

    private var detailAccentColor: Color {
        switch hangout.vibe {
        case .chill: return Color(hex: "#667EEA")
        case .drinks: return Color(hex: "#F59E0B")
        case .deepTalk: return Color(hex: "#8B5CF6")
        case .activity: return Color(hex: "#10B981")
        case .foodie: return Color(hex: "#EF4444")
        case .sporty: return Color(hex: "#0EA5E9")
        }
    }

    private var coverUIImage: Image? {
        guard let data = hangout.coverImageData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private static func seedParticipants(from hangout: HangoutItem) -> [DetailPerson] {
        let host = DetailPerson(id: hangout.id * 1000, name: hangout.hostName, isHost: true)

        let guests = hangout.participantNames
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare(hangout.hostName) != .orderedSame }
            .enumerated()
            .map { offset, name in
                DetailPerson(id: hangout.id * 1000 + offset + 1, name: name, isHost: false)
            }

        return [host] + guests
    }

    private static func seedPendingRequests(from hangout: HangoutItem, enabled: Bool) -> [DetailJoinRequest] {
        guard enabled else { return [] }

        let pool: [(String, String)] = [
            ("Milo", "I'd love to join for good vibes and easy conversation."),
            ("Aisha", "Can I join? I'm nearby and free now."),
            ("Rene", "First time here, this looks exactly my vibe."),
            ("Cam", "Down to join if there is still a spot left.")
        ]

        let count = min(3, max(1, hangout.spotsLeft + (hangout.isFull ? 2 : 0)))
        let start = hangout.id % pool.count

        return (0 ..< count).map { index in
            let item = pool[(start + index) % pool.count]
            return DetailJoinRequest(
                id: hangout.id * 10 + index,
                userID: hangout.id * 100 + index,
                username: item.0,
                message: item.1
            )
        }
    }

    private static func seedWaitlist(from hangout: HangoutItem, enabled: Bool) -> [DetailPerson] {
        guard enabled else { return [] }

        let pool = ["Niko", "Clara", "Yara", "Theo", "Mina"]
        let baseCount = hangout.isFull ? 2 : 1
        let count = min(baseCount, pool.count)
        let start = (hangout.id + 2) % pool.count

        return (0 ..< count).map { index in
            let name = pool[(start + index) % pool.count]
            return DetailPerson(id: hangout.id * 200 + index, name: name, isHost: false)
        }
    }
}

private enum DetailRole {
    case guest
    case pending
    case waitlisted
    case participant
    case host
}

private enum RequestTransitionDirection {
    case pass
    case welcome
}

private struct DetailPerson: Identifiable, Equatable {
    let id: Int
    let name: String
    let isHost: Bool
}

private struct DetailJoinRequest: Identifiable {
    let id: Int
    let userID: Int
    let username: String
    let message: String?
}

#Preview {
    NavigationStack {
        HangoutDetailView(
            hangout: HangoutsMockData.sample().first!,
            joinStatus: .none,
            onRequestJoin: {},
            onCancelRequest: {}
        )
    }
}
