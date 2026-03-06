import SwiftUI
import MapKit

struct RootTabView: View {
    @State private var selectedTab: AppTab = .hangouts
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @State private var selectedMapHangoutID: Int?
    @State private var mapHangouts: [HangoutItem] = HangoutsMockData.sample()
    @State private var mapJoinStatuses: [Int: HangoutJoinStatus] = [:]
    @State private var mapDetailHangout: HangoutItem?
    @State private var isShowingMapReportAcknowledgement = false
    @State private var isShowingMapBlurLift = false
    @State private var mapTransitionToken = 0
    @State private var lastTabForTransition: AppTab = .hangouts

    private let userCoordinate = CLLocationCoordinate2D(latitude: 52.5176, longitude: 13.4095)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                FriendZoneTheme.background
                    .ignoresSafeArea()

                if selectedTab == .ambitions {
                    NavigationStack {
                        AmbitionsView()
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    hangoutsMapsStage
                }

                FriendZoneTabBar(selectedTab: $selectedTab)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(2, proxy.safeAreaInsets.bottom - 24))
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .fullScreenCover(item: $mapDetailHangout) { hangout in
                NavigationStack {
                    HangoutDetailView(
                        hangout: hangout,
                        joinStatus: mapJoinStatus(for: hangout),
                        onRequestJoin: {
                            mapJoinStatuses[hangout.id] = .requested
                        },
                        onCancelRequest: {
                            mapJoinStatuses[hangout.id] = HangoutJoinStatus.none
                        }
                    )
                }
                .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
            }
            .alert("Report sent", isPresented: $isShowingMapReportAcknowledgement) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thanks. We will review this hangout.")
            }
            .onChange(of: selectedTab) { current in
                if lastTabForTransition == .hangouts, current == .maps {
                    triggerMapBlurLift()
                }
                lastTabForTransition = current
            }
        }
    }

    private var hangoutsMapsStage: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width
            let showingMaps = selectedTab == .maps

            ZStack {
                PersistentDiscoveryMapView(
                    region: $mapRegion,
                    hangouts: mapHangouts,
                    userCoordinate: userCoordinate,
                    selectedHangoutID: $selectedMapHangoutID,
                    isInteractive: showingMaps
                )
                .ignoresSafeArea()

                mapBrandTint
                    .ignoresSafeArea()
                mapBrandPattern
                    .ignoresSafeArea()

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.28), Color.white.opacity(0.38)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                    .blur(radius: showingMaps ? 0 : 3)
                    .opacity(showingMaps ? 0 : 1)
                    .animation(.easeInOut(duration: 0.24), value: showingMaps)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    NavigationStack {
                        HangoutsView(
                            usesExternalBackdrop: true,
                            onRequestOpenMaps: {
                                withAnimation(FriendZoneTheme.Motion.easeOutExpo) {
                                    selectedTab = .maps
                                }
                            }
                        )
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .frame(width: pageWidth)

                    NavigationStack {
                        MapsOverlayView(
                            hangouts: mapHangouts,
                            selectedHangout: selectedMapHangout,
                            isActive: showingMaps,
                            onCloseSelection: { selectedMapHangoutID = nil },
                            onLocateMe: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    mapRegion.center = userCoordinate
                                }
                            },
                            onOpenDetail: { hangout in
                                FriendZoneHaptics.selection()
                                mapDetailHangout = hangout
                            },
                            onReportHangout: { _ in
                                FriendZoneHaptics.lightImpact()
                                isShowingMapReportAcknowledgement = true
                            },
                            onOpenHangouts: {
                                withAnimation(FriendZoneTheme.Motion.easeOutExpo) {
                                    selectedTab = .hangouts
                                }
                            }
                        )
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .frame(width: pageWidth)
                }
                .offset(x: showingMaps ? -pageWidth : 0)
                .animation(FriendZoneTheme.Motion.easeOutExpo, value: selectedTab)

                if showingMaps, isShowingMapBlurLift {
                    mapSeamlessBlurLift
                        .transition(.opacity)
                        .zIndex(4)
                }
            }
            .clipped()
        }
    }

    private var selectedMapHangout: HangoutItem? {
        mapHangouts.first(where: { $0.id == selectedMapHangoutID })
    }

    private func mapJoinStatus(for hangout: HangoutItem) -> HangoutJoinStatus {
        if let status = mapJoinStatuses[hangout.id] {
            return status
        }
        return hangout.isJoined ? .joined : .none
    }

    private var mapBrandTint: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.06), Color.clear, Color.black.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }

    private var mapBrandPattern: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let step: CGFloat = 24
                let dotRect = CGRect(x: 0, y: 0, width: 1.2, height: 1.2)
                for x in stride(from: 0 as CGFloat, to: size.width, by: step) {
                    for y in stride(from: 0 as CGFloat, to: size.height, by: step) {
                        context.opacity = 0.12
                        context.fill(
                            Path(ellipseIn: dotRect.offsetBy(dx: x, dy: y)),
                            with: .color(Color.black.opacity(0.22))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var mapSeamlessBlurLift: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.34), Color.white.opacity(0.44)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func triggerMapBlurLift() {
        mapTransitionToken += 1
        let currentToken = mapTransitionToken
        isShowingMapBlurLift = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard currentToken == mapTransitionToken else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                isShowingMapBlurLift = false
            }
        }
    }
}

#Preview {
    RootTabView()
}

private struct PersistentDiscoveryMapView: View {
    @Binding var region: MKCoordinateRegion
    let hangouts: [HangoutItem]
    let userCoordinate: CLLocationCoordinate2D
    @Binding var selectedHangoutID: Int?
    let isInteractive: Bool

    private var markers: [DiscoveryMapMarker] {
        var items = [DiscoveryMapMarker.user(coordinate: userCoordinate)]
        items.append(
            contentsOf: hangouts.map { hangout in
                DiscoveryMapMarker.hangout(
                    id: hangout.id,
                    coordinate: coordinate(for: hangout.id),
                    vibe: hangout.vibe,
                    isToday: Calendar.current.isDateInToday(hangout.startAt)
                )
            }
        )
        return items
    }

    var body: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: isInteractive ? [.all] : [],
            annotationItems: markers
        ) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                switch marker.kind {
                case .user:
                    userMarker
                case let .hangout(id, vibe, isToday):
                    Button {
                        selectedHangoutID = (selectedHangoutID == id) ? nil : id
                    } label: {
                        hangoutMarker(vibe: vibe, isToday: isToday)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var userMarker: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1F2937"), Color(hex: "#111827")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Text("U")
                        .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 3)
                }
                .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 4)

            Circle()
                .fill(Color(hex: "#30D158"))
                .frame(width: 12, height: 12)
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 2)
                }
        }
    }

    private func hangoutMarker(vibe: HangoutVibe, isToday: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(vibeColor(vibe))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(vibeEmoji(vibe))
                        .font(.system(size: 18))
                }
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 3)
                }
                .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 3)

            if isToday {
                Circle()
                    .fill(Color(hex: "#FF3B30"))
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle().stroke(Color.white, lineWidth: 2)
                    }
            }
        }
    }

    private func coordinate(for id: Int) -> CLLocationCoordinate2D {
        let seed = Double((id % 9) + 1)
        return CLLocationCoordinate2D(
            latitude: 52.52 + (seed * 0.005) - 0.02,
            longitude: 13.40 + (seed * 0.006) - 0.02
        )
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

private struct MapsOverlayView: View {
    let hangouts: [HangoutItem]
    let selectedHangout: HangoutItem?
    let isActive: Bool
    let onCloseSelection: () -> Void
    let onLocateMe: () -> Void
    let onOpenDetail: (HangoutItem) -> Void
    let onReportHangout: (HangoutItem) -> Void
    let onOpenHangouts: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explore nearby")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("\(hangouts.count) hangouts")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(FriendZoneTheme.Colors.primarySoft)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
                .opacity(isActive ? 1 : 0.0)
                .offset(y: isActive ? 0 : -8)
                .animation(.easeOut(duration: 0.24), value: isActive)

                Spacer()
            }

            if let selectedHangout {
                markerInfoPanel(selectedHangout)
                    .padding(.horizontal, 16)
                    .padding(.top, 104)
                    .padding(.bottom, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .opacity(isActive ? 1 : 0.0)
                    .offset(y: isActive ? 0 : -6)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: onLocateMe) {
                        Image(systemName: "location")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#0F172A"), Color(hex: "#1F2937")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.bottom, 96)
                    .opacity(isActive ? 1 : 0)
                    .offset(y: isActive ? 0 : 12)
                    .animation(.easeOut(duration: 0.24), value: isActive)
                }
            }
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .allowsHitTesting(isActive)
        .animation(.easeOut(duration: 0.24), value: isActive)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    let deltaX = value.translation.width
                    let deltaY = value.translation.height
                    let isHorizontal = abs(deltaX) > abs(deltaY) * 1.2
                    if isHorizontal, deltaX > 45 {
                        onOpenHangouts()
                    }
                }
        )
        .animation(.easeOut(duration: 0.2), value: selectedHangout?.id)
    }

    private func markerInfoPanel(_ hangout: HangoutItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(vibeEmoji(hangout.vibe))
                    .font(.system(size: 20))
                    .frame(width: 42, height: 42)
                    .background(vibeColor(hangout.vibe))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(hangout.title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("\(timeLabel(hangout.startAt)) · \(hangout.spotsLeft > 0 ? "\(hangout.spotsLeft) left" : "Full")")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                        if Calendar.current.isDateInToday(hangout.startAt) {
                            Text("TODAY")
                                .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .frame(height: 16)
                                .background(Color(hex: "#FF3B30"))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer(minLength: 0)

                Button(action: onCloseSelection) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button {
                    onOpenDetail(hangout)
                } label: {
                    Text("View details")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onReportHangout(hangout)
                } label: {
                    Text("Report")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(FriendZoneTheme.Colors.error.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.error.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
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

private struct DiscoveryMapMarker: Identifiable {
    enum Kind {
        case user
        case hangout(id: Int, vibe: HangoutVibe, isToday: Bool)
    }

    let id: Int
    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    static func user(coordinate: CLLocationCoordinate2D) -> DiscoveryMapMarker {
        DiscoveryMapMarker(id: -1, coordinate: coordinate, kind: .user)
    }

    static func hangout(id: Int, coordinate: CLLocationCoordinate2D, vibe: HangoutVibe, isToday: Bool) -> DiscoveryMapMarker {
        DiscoveryMapMarker(id: id, coordinate: coordinate, kind: .hangout(id: id, vibe: vibe, isToday: isToday))
    }
}
