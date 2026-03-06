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
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    hangoutsMapsStage
                }

                FriendZoneTabBar(selectedTab: $selectedTab)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(0, proxy.safeAreaInsets.bottom - 10))
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
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
                    .frame(width: pageWidth)

                    NavigationStack {
                        MapsOverlayView(
                            hangouts: mapHangouts,
                            selectedHangout: selectedMapHangout,
                            onCloseSelection: { selectedMapHangoutID = nil },
                            onLocateMe: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    mapRegion.center = userCoordinate
                                }
                            },
                            onOpenHangouts: {
                                withAnimation(FriendZoneTheme.Motion.easeOutExpo) {
                                    selectedTab = .hangouts
                                }
                            }
                        )
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .frame(width: pageWidth)
                }
                .offset(x: showingMaps ? -pageWidth : 0)
                .animation(FriendZoneTheme.Motion.easeOutExpo, value: selectedTab)
            }
            .clipped()
        }
    }

    private var selectedMapHangout: HangoutItem? {
        mapHangouts.first(where: { $0.id == selectedMapHangoutID })
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
    let onCloseSelection: () -> Void
    let onLocateMe: () -> Void
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

                Spacer()
            }

            if let selectedHangout {
                markerInfoCard(selectedHangout)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                }
            }
        }
        .background(Color.clear)
        .contentShape(Rectangle())
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
    }

    private func markerInfoCard(_ hangout: HangoutItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(vibeEmoji(hangout.vibe))
                    .font(.system(size: 20))
                    .frame(width: 42, height: 42)
                    .background(vibeColor(hangout.vibe))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(hangout.title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("\(timeLabel(hangout.startAt)) · \(hangout.spotsLeft > 0 ? "\(hangout.spotsLeft) spots left" : "Full")")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Spacer()

                Button(action: onCloseSelection) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
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
