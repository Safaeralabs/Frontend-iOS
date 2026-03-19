import Combine
import CoreLocation
import MapKit
import SwiftUI

@MainActor
final class FriendZoneMapLocationModel: NSObject, ObservableObject {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isLocating = false

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestLocation() {
        handleAuthorization(manager.authorizationStatus, shouldRequestLocation: true)
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus, shouldRequestLocation: Bool) {
        authorizationStatus = status

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if shouldRequestLocation {
                isLocating = true
                manager.requestLocation()
            }
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            isLocating = false
        @unknown default:
            isLocating = false
        }
    }
}

extension FriendZoneMapLocationModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthorization(status, shouldRequestLocation: status == .authorizedAlways || status == .authorizedWhenInUse)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latestCoordinate = locations.last?.coordinate
        Task { @MainActor in
            self.coordinate = latestCoordinate
            self.isLocating = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLocating = false
        }
    }
}

struct FriendZoneMapCanvasView: View {
    @EnvironmentObject private var session: AppSessionStore

    @Binding var region: MKCoordinateRegion
    let hangouts: [HangoutItem]
    let hangoutCoordinates: [Int: CLLocationCoordinate2D]
    let events: [HangoutsView.DiscoveryEventItem]
    let eventCoordinates: [Int: CLLocationCoordinate2D]
    let offers: [HangoutsView.DiscoveryOfferItem]
    let offerCoordinates: [Int: CLLocationCoordinate2D]
    let userCoordinate: CLLocationCoordinate2D
    @Binding var selectedSelectionID: String?
    let isInteractive: Bool

    @State private var isPulseExpanded = false

    private var userInitials: String {
        if let first = session.currentProfile?.user?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty {
            return String(first.prefix(1)).uppercased()
        }
        if let first = session.currentUser?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty {
            return String(first.prefix(1)).uppercased()
        }
        if let username = session.currentUser?.username, !username.isEmpty {
            return String(username.prefix(1)).uppercased()
        }
        return "U"
    }

    private var markers: [FriendZoneMapMarker] {
        var items = [FriendZoneMapMarker.user(coordinate: userCoordinate)]
        items.append(contentsOf: clusteredHangoutMarkers())
        items.append(contentsOf: eventMarkers())
        items.append(contentsOf: offerMarkers())
        return items
    }

    var body: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: isInteractive ? [.all] : [],
            annotationItems: markers
        ) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                annotationView(for: marker)
            }
        }
        .onAppear {
            guard !isPulseExpanded else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                isPulseExpanded = true
            }
        }
        .onChange(of: selectedSelectionID) { selectionID in
            guard let selectionID else { return }
            centerMap(on: coordinate(for: selectionID))
        }
    }

    @ViewBuilder
    private func annotationView(for marker: FriendZoneMapMarker) -> some View {
        switch marker.kind {
        case .user:
            userMarker
        case let .hangout(id, vibe, isToday, isApproximate):
            Button {
                setSelection("hangout-\(id)")
            } label: {
                hangoutPin(vibe: vibe, isToday: isToday, isSelected: selectedSelectionID == "hangout-\(id)", isApproximate: isApproximate)
            }
            .buttonStyle(.plain)
        case let .event(id, category):
            Button {
                setSelection("event-\(id)")
            } label: {
                eventPin(category: category, isSelected: selectedSelectionID == "event-\(id)")
            }
            .buttonStyle(.plain)
        case let .offer(id, isHot):
            Button {
                setSelection("offer-\(id)")
            } label: {
                offerPin(isHot: isHot, isSelected: selectedSelectionID == "offer-\(id)")
            }
            .buttonStyle(.plain)
        case let .cluster(count, vibe, isToday, hangoutIDs, hasApproximateMembers):
            Button {
                FriendZoneHaptics.lightImpact()
                if region.span.latitudeDelta > 0.012 || region.span.longitudeDelta > 0.012 {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        region.center = marker.coordinate
                        region.span = MKCoordinateSpan(
                            latitudeDelta: max(0.007, region.span.latitudeDelta * 0.48),
                            longitudeDelta: max(0.007, region.span.longitudeDelta * 0.48)
                        )
                    }
                } else if let firstID = hangoutIDs.first {
                    setSelection("hangout-\(firstID)")
                }
            } label: {
                clusterPin(count: count, vibe: vibe, isToday: isToday, hasApproximateMembers: hasApproximateMembers)
            }
            .buttonStyle(.plain)
        }
    }

    private var userMarker: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#0F172A").opacity(0.16), lineWidth: 2)
                .frame(width: 58, height: 58)
                .scaleEffect(isPulseExpanded ? 1.24 : 0.92)
                .opacity(isPulseExpanded ? 0 : 0.65)

            mapTail(fill: LinearGradient(
                colors: [Color(hex: "#1F2937"), Color(hex: "#0F172A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#374151"), Color(hex: "#111827")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 2.5)
                }
                .overlay {
                    Text(userInitials)
                        .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(FriendZoneTheme.Colors.success)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle().stroke(Color.white, lineWidth: 2)
                        }
                }
                .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
        }
        .frame(width: 72, height: 78)
    }

    private func hangoutPin(vibe: HangoutVibe, isToday: Bool, isSelected: Bool, isApproximate: Bool) -> some View {
        let gradient = LinearGradient(
            colors: [friendZoneMapVibeColor(vibe), friendZoneMapVibeColor(vibe).opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return ZStack {
            if isApproximate {
                Circle()
                    .stroke(friendZoneMapVibeColor(vibe).opacity(isSelected ? 0.34 : 0.22), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .frame(width: isSelected ? 68 : 60, height: isSelected ? 68 : 60)
            }

            if isSelected {
                Circle()
                    .fill(friendZoneMapVibeColor(vibe).opacity(0.16))
                    .frame(width: 60, height: 60)
            }

            mapTail(fill: gradient)

            Circle()
                .fill(gradient)
                .frame(width: isSelected ? 50 : 44, height: isSelected ? 50 : 44)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 2.5)
                }
                .overlay {
                    Text(friendZoneMapVibeEmoji(vibe))
                        .font(.system(size: isSelected ? 22 : 19))
                }
                .shadow(color: friendZoneMapVibeColor(vibe).opacity(isSelected ? 0.42 : 0.28), radius: 12, x: 0, y: 6)
                .overlay(alignment: .topTrailing) {
                    if isToday {
                        Circle()
                            .fill(FriendZoneTheme.Colors.error)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle().stroke(Color.white, lineWidth: 2)
                            }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isApproximate {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(friendZoneMapVibeColor(vibe))
                            }
                    }
                }
        }
        .frame(width: 72, height: 78)
        .scaleEffect(isSelected ? 1.08 : 1)
    }

    private func eventPin(category: String, isSelected: Bool) -> some View {
        let accent = Color(hex: "#0E7490")

        return ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 60, height: 60)
            }

            mapTail(fill: LinearGradient(
                colors: [accent, accent.opacity(0.74)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))

            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, Color(hex: "#155E75")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isSelected ? 50 : 44, height: isSelected ? 50 : 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 2.5)
                }
                .overlay {
                    Image(systemName: eventSymbol(for: category))
                        .font(.system(size: isSelected ? 17 : 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: accent.opacity(0.26), radius: 10, x: 0, y: 5)
        }
        .frame(width: 72, height: 78)
        .scaleEffect(isSelected ? 1.08 : 1)
    }

    private func offerPin(isHot: Bool, isSelected: Bool) -> some View {
        let accent = Color(hex: "#B45309")

        return ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 60, height: 60)
            }

            mapTail(fill: LinearGradient(
                colors: [Color(hex: "#F59E0B"), accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))

            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#F59E0B"), accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isSelected ? 50 : 44, height: isSelected ? 50 : 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 2.5)
                }
                .overlay {
                    Image(systemName: "tag.fill")
                        .font(.system(size: isSelected ? 16 : 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay(alignment: .topTrailing) {
                    if isHot {
                        Circle()
                            .fill(FriendZoneTheme.Colors.error)
                            .frame(width: 11, height: 11)
                            .overlay {
                                Circle().stroke(Color.white, lineWidth: 2)
                            }
                    }
                }
                .shadow(color: accent.opacity(0.26), radius: 10, x: 0, y: 5)
        }
        .frame(width: 72, height: 78)
        .scaleEffect(isSelected ? 1.08 : 1)
    }

    private func clusterPin(count: Int, vibe: HangoutVibe, isToday: Bool, hasApproximateMembers: Bool) -> some View {
        let accent = friendZoneMapVibeColor(vibe)

        return ZStack {
            if hasApproximateMembers {
                Circle()
                    .stroke(accent.opacity(0.22), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .frame(width: 70, height: 70)
            }

            mapTail(fill: LinearGradient(
                colors: [Color(hex: "#111827"), Color(hex: "#374151")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#111827"), Color(hex: "#374151")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 2.5)
                }
                .overlay {
                    Text("\(count)")
                        .font(FriendZoneTheme.Typography.system(15, weight: .heavy))
                        .foregroundColor(.white)
                }
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Text(friendZoneMapVibeEmoji(vibe))
                            .font(.system(size: 11))
                            .padding(4)
                            .background(Color.white.opacity(0.96))
                            .clipShape(Circle())
                            .offset(x: 6, y: -4)

                        if isToday {
                            Circle()
                                .fill(accent)
                                .frame(width: 10, height: 10)
                                .overlay {
                                    Circle().stroke(Color.white, lineWidth: 2)
                                }
                                .offset(x: 10, y: -18)
                        }
                    }
                }
                .shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 5)
        }
        .frame(width: 72, height: 78)
    }

    private func mapTail(fill: LinearGradient) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(fill)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(45))
            .offset(y: 20)
    }

    private func setSelection(_ selectionID: String) {
        if selectedSelectionID == selectionID {
            selectedSelectionID = nil
            return
        }

        selectedSelectionID = selectionID
        centerMap(on: coordinate(for: selectionID))
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.26)) {
            region = MKCoordinateRegion(center: coordinate, span: region.span)
        }
    }

    private func coordinate(for selectionID: String) -> CLLocationCoordinate2D {
        if selectionID.hasPrefix("hangout-"),
           let id = Int(selectionID.replacingOccurrences(of: "hangout-", with: "")),
           let coordinate = hangoutCoordinates[id] {
            return coordinate
        }
        if selectionID.hasPrefix("event-"),
           let id = Int(selectionID.replacingOccurrences(of: "event-", with: "")),
           let coordinate = eventCoordinates[id] {
            return coordinate
        }
        if selectionID.hasPrefix("offer-"),
           let id = Int(selectionID.replacingOccurrences(of: "offer-", with: "")),
           let coordinate = offerCoordinates[id] {
            return coordinate
        }
        return userCoordinate
    }

    private func clusteredHangoutMarkers() -> [FriendZoneMapMarker] {
        struct Point {
            let hangout: HangoutItem
            let coordinate: CLLocationCoordinate2D
        }

        var buckets: [String: [Point]] = [:]
        let latCell = max(0.004, region.span.latitudeDelta / 7.5)
        let lonCell = max(0.004, region.span.longitudeDelta / 7.5)

        let points = hangouts.compactMap { hangout -> Point? in
            guard let coordinate = hangoutCoordinates[hangout.id] else { return nil }
            return Point(hangout: hangout, coordinate: coordinate)
        }

        for point in points {
            let latIndex = Int(floor(point.coordinate.latitude / latCell))
            let lonIndex = Int(floor(point.coordinate.longitude / lonCell))
            buckets["\(latIndex)_\(lonIndex)", default: []].append(point)
        }

        var markers: [FriendZoneMapMarker] = []

        for (bucketID, bucket) in buckets {
            let sorted = bucket.sorted { $0.hangout.startAt < $1.hangout.startAt }
            if sorted.count == 1, let single = sorted.first {
                markers.append(
                    .hangout(
                        id: single.hangout.id,
                        coordinate: single.coordinate,
                        vibe: single.hangout.vibe,
                        isToday: Calendar.current.isDateInToday(single.hangout.startAt),
                        isApproximate: !single.hangout.hasUnlockedLocation
                    )
                )
                continue
            }

            let avgLat = sorted.map(\.coordinate.latitude).reduce(0, +) / Double(sorted.count)
            let avgLon = sorted.map(\.coordinate.longitude).reduce(0, +) / Double(sorted.count)
            let lead = sorted[0].hangout
            let ids = sorted.map { $0.hangout.id }
            let anyToday = sorted.contains { Calendar.current.isDateInToday($0.hangout.startAt) }
            let hasApproximateMembers = sorted.contains { !$0.hangout.hasUnlockedLocation }

            markers.append(
                .cluster(
                    id: bucketID,
                    coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    count: sorted.count,
                    vibe: lead.vibe,
                    isToday: anyToday,
                    hangoutIDs: ids,
                    hasApproximateMembers: hasApproximateMembers
                )
            )
        }

        return markers
    }

    private func eventMarkers() -> [FriendZoneMapMarker] {
        events.compactMap { event in
            guard let coordinate = eventCoordinates[event.id] else { return nil }
            return .event(id: event.id, coordinate: coordinate, category: event.category)
        }
    }

    private func offerMarkers() -> [FriendZoneMapMarker] {
        let now = Date()
        return offers.compactMap { offer in
            guard let coordinate = offerCoordinates[offer.id] else { return nil }
            return .offer(
                id: offer.id,
                coordinate: coordinate,
                isHot: offer.validUntil.timeIntervalSince(now) < 60 * 60 * 12
            )
        }
    }
}

struct FriendZoneMapChromeView: View {
    let selectedItem: SelectedMapDiscoveryItem?
    let openingDetailHangoutID: Int?
    let openingDetailSelectionID: String?
    let isActive: Bool
    let cityLabel: String
    let isTravelModeActive: Bool
    let plansCount: Int
    let isLocatingUser: Bool
    let isUsingPreciseLocation: Bool
    let onOpenTravelMode: () -> Void
    let onCloseSelection: () -> Void
    let onLocateMe: () -> Void
    let onOpenHangoutDetail: (HangoutItem) -> Void
    let onOpenEventDetail: (HangoutsView.DiscoveryEventItem) -> Void
    let onOpenOfferDetail: (HangoutsView.DiscoveryOfferItem) -> Void
    let onReportSelection: (SelectedMapDiscoveryItem) -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(0, proxy.safeAreaInsets.top)
            let bottomInset = max(0, proxy.safeAreaInsets.bottom)

            ZStack(alignment: .top) {
                mapBrandTint
                    .ignoresSafeArea()

                mapBrandPattern
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    topChrome(topInset: topInset)

                    if let selectedItem {
                        selectedItemCard(selectedItem)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(isActive)
                .opacity(isActive ? 1 : 0)
                .offset(y: isActive ? 0 : -8)
                .animation(.easeOut(duration: 0.24), value: isActive)

                if plansCount == 0 && !isLocatingUser {
                    emptyOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 36)
                        .allowsHitTesting(false)
                        .opacity(isActive ? 1 : 0)
                        .animation(.easeOut(duration: 0.24), value: isActive)
                }

                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        Button(action: onLocateMe) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Circle()
                                            .stroke(FriendZoneTheme.Colors.primary.opacity(0.18), lineWidth: 1)
                                    }

                                if isLocatingUser {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(FriendZoneTheme.Colors.primary)
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(FriendZoneTheme.Colors.primary)
                                }
                            }
                            .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(selectedItem == nil ? 94 : 208, bottomInset + 74))
                    .opacity(isActive ? 1 : 0)
                    .offset(y: isActive ? 0 : 12)
                    .animation(.easeOut(duration: 0.24), value: isActive)
                }
            }
        }
    }

    private func topChrome(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    (
                    Text("Explore ")
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        + Text("nearby")
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                    )
                    .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                    .lineLimit(1)

                    Text(isTravelModeActive ? "Travel mode is guiding this map." : "Plans around your area.")
                        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                countBadge
            }

            HStack(spacing: 8) {
                ActiveCityStatusButton(action: onOpenTravelMode)
            }

            if isLocatingUser {
                HStack(spacing: 8) {
                    infoChip(icon: "scope", text: "Locating")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 2)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.md)
    }

    private var countBadge: some View {
        HStack(spacing: 8) {
            Text("\(plansCount)")
                .font(FriendZoneTheme.Typography.system(19, weight: .heavy))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(plansCount == 1 ? "HANGOUT" : "HANGOUTS")
                .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.6)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.9), Color.white.opacity(0.74)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func selectedItemCard(_ item: SelectedMapDiscoveryItem) -> some View {
        switch item {
        case let .hangout(hangout):
            selectedCard(
                accent: friendZoneMapVibeColor(hangout.vibe),
                leading: AnyView(
                    selectedBubble(
                        background: LinearGradient(
                            colors: [friendZoneMapVibeColor(hangout.vibe), friendZoneMapVibeColor(hangout.vibe).opacity(0.74)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        content: AnyView(
                            Text(friendZoneMapVibeEmoji(hangout.vibe))
                                .font(.system(size: 24))
                        )
                    )
                ),
                eyebrow: hangout.publicLocationDisplay.uppercased(),
                title: hangout.title,
                subtitle: "Hosted by \(hangout.hostName)",
                chips: [
                    ("clock.fill", selectedTimeLabel(hangout.startAt)),
                    ("person.2.fill", hangout.spotsLeft > 0 ? "\(hangout.spotsLeft) left" : "Full"),
                    ("figure.walk", hangout.distanceLabel)
                ] + (!hangout.hasUnlockedLocation ? [("lock.fill", "AREA ONLY")] : [])
                  + (Calendar.current.isDateInToday(hangout.startAt) ? [("sparkles", "TODAY")] : []),
                primaryTitle: "Open pass",
                isOpeningDetail: openingDetailHangoutID == hangout.id,
                onPrimary: { onOpenHangoutDetail(hangout) },
                onReport: { onReportSelection(.hangout(hangout)) }
            )
        case let .event(event):
            selectedCard(
                accent: Color(hex: "#0E7490"),
                leading: AnyView(
                    selectedBubble(
                        background: LinearGradient(
                            colors: [Color(hex: "#0E7490"), Color(hex: "#155E75")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        content: AnyView(
                            Image(systemName: eventSymbol(for: event.category))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        )
                    )
                ),
                eyebrow: event.category.uppercased(),
                title: event.title,
                subtitle: event.venue,
                chips: [
                    ("calendar", selectedDateLabel(event.startAt)),
                    ("clock.fill", selectedTimeLabel(event.startAt)),
                    ("person.3.fill", "\(event.groups) groups")
                ],
                primaryTitle: "Open event",
                isOpeningDetail: openingDetailSelectionID == item.id,
                onPrimary: { onOpenEventDetail(event) },
                onReport: { onReportSelection(.event(event)) }
            )
        case let .offer(offer):
            selectedCard(
                accent: Color(hex: "#B45309"),
                leading: AnyView(
                    selectedBubble(
                        background: LinearGradient(
                            colors: [Color(hex: "#F59E0B"), Color(hex: "#B45309")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        content: AnyView(
                            Image(systemName: "tag.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                        )
                    )
                ),
                eyebrow: "VOUCHER",
                title: offer.title,
                subtitle: offer.venue,
                chips: [
                    ("gift.fill", offer.perk),
                    ("clock.badge", "Until \(selectedDateLabel(offer.validUntil))"),
                    ("ticket.fill", offer.spotsLeft > 0 ? "\(offer.spotsLeft) left" : "Full")
                ],
                primaryTitle: "Open offer",
                isOpeningDetail: openingDetailSelectionID == item.id,
                onPrimary: { onOpenOfferDetail(offer) },
                onReport: { onReportSelection(.offer(offer)) }
            )
        }
    }

    private func selectedCard(
        accent: Color,
        leading: AnyView,
        eyebrow: String,
        title: String,
        subtitle: String,
        chips: [(String, String)],
        primaryTitle: String,
        isOpeningDetail: Bool,
        onPrimary: @escaping () -> Void,
        onReport: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                leading

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(accent)
                        .lineLimit(1)

                    Text(title)
                        .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button(action: onCloseSelection) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        chipPill(icon: chip.0, text: chip.1, accent: accent)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollDisabled(true)
            .allowsHitTesting(false)

            HStack(spacing: 8) {
                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isOpeningDetail)

                Button(action: onReport) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .frame(width: 40, height: 40)
                        .background(FriendZoneTheme.Colors.error.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.error.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isOpeningDetail)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.md)
        .scaleEffect(isOpeningDetail ? 0.97 : 1)
        .opacity(isOpeningDetail ? 0.36 : 1)
        .blur(radius: isOpeningDetail ? 1.8 : 0)
        .animation(.easeInOut(duration: 0.16), value: isOpeningDetail)
    }

    private func selectedBubble(background: LinearGradient, content: AnyView) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(background)
            .frame(width: 58, height: 58)
            .overlay { content }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            }
    }

    private func infoChip(icon: String, text: String, isAccent: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(isAccent ? .white : FriendZoneTheme.Colors.textSecondary)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(isAccent ? FriendZoneTheme.Colors.primary : Color.white.opacity(0.78))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(
                    isAccent ? FriendZoneTheme.Colors.primary.opacity(0.18) : FriendZoneTheme.Colors.borderSubtle,
                    lineWidth: 1
                )
        }
    }

    private func chipPill(icon: String, text: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(accent.opacity(0.10))
        .clipShape(Capsule())
    }

    private var emptyOverlay: some View {
        VStack(spacing: 10) {
            Text("🗺️")
                .font(.system(size: 28))

            Text("No plans with coordinates yet")
                .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text("As soon as hangouts or events include a real location, they will appear here as pins.")
                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1.6)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.md)
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
                let primaryStep: CGFloat = 24
                let secondaryStep: CGFloat = 34
                let dotRect = CGRect(x: 0, y: 0, width: 1.2, height: 1.2)
                let secondaryRect = CGRect(x: 0, y: 0, width: 1.1, height: 1.1)

                for x in stride(from: 0 as CGFloat, to: size.width, by: primaryStep) {
                    for y in stride(from: 0 as CGFloat, to: size.height, by: primaryStep) {
                        context.opacity = 0.08
                        context.fill(
                            Path(ellipseIn: dotRect.offsetBy(dx: x, dy: y)),
                            with: .color(Color.black.opacity(0.18))
                        )
                    }
                }

                for x in stride(from: 12 as CGFloat, to: size.width, by: secondaryStep) {
                    for y in stride(from: 10 as CGFloat, to: size.height, by: secondaryStep) {
                        context.opacity = 0.08
                        context.fill(
                            Path(ellipseIn: secondaryRect.offsetBy(dx: x, dy: y)),
                            with: .color(Color.white.opacity(0.24))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FriendZoneMapMarker: Identifiable {
    enum Kind {
        case user
        case hangout(id: Int, vibe: HangoutVibe, isToday: Bool, isApproximate: Bool)
        case event(id: Int, category: String)
        case offer(id: Int, isHot: Bool)
        case cluster(count: Int, vibe: HangoutVibe, isToday: Bool, hangoutIDs: [Int], hasApproximateMembers: Bool)
    }

    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    static func user(coordinate: CLLocationCoordinate2D) -> FriendZoneMapMarker {
        FriendZoneMapMarker(id: "user", coordinate: coordinate, kind: .user)
    }

    static func hangout(id: Int, coordinate: CLLocationCoordinate2D, vibe: HangoutVibe, isToday: Bool, isApproximate: Bool) -> FriendZoneMapMarker {
        FriendZoneMapMarker(id: "hangout-\(id)", coordinate: coordinate, kind: .hangout(id: id, vibe: vibe, isToday: isToday, isApproximate: isApproximate))
    }

    static func event(id: Int, coordinate: CLLocationCoordinate2D, category: String) -> FriendZoneMapMarker {
        FriendZoneMapMarker(id: "event-\(id)", coordinate: coordinate, kind: .event(id: id, category: category))
    }

    static func offer(id: Int, coordinate: CLLocationCoordinate2D, isHot: Bool) -> FriendZoneMapMarker {
        FriendZoneMapMarker(id: "offer-\(id)", coordinate: coordinate, kind: .offer(id: id, isHot: isHot))
    }

    static func cluster(
        id: String,
        coordinate: CLLocationCoordinate2D,
        count: Int,
        vibe: HangoutVibe,
        isToday: Bool,
        hangoutIDs: [Int],
        hasApproximateMembers: Bool
    ) -> FriendZoneMapMarker {
        FriendZoneMapMarker(
            id: id,
            coordinate: coordinate,
            kind: .cluster(count: count, vibe: vibe, isToday: isToday, hangoutIDs: hangoutIDs, hasApproximateMembers: hasApproximateMembers)
        )
    }
}

private func friendZoneMapVibeColor(_ vibe: HangoutVibe) -> Color {
    vibe.accentColor
}

private func friendZoneMapVibeEmoji(_ vibe: HangoutVibe) -> String {
    vibe.emoji
}

private func eventSymbol(for category: String) -> String {
    switch category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "music", "party":
        return "music.mic"
    case "networking", "tech":
        return "person.3.fill"
    case "culture", "art":
        return "paintpalette.fill"
    case "food":
        return "fork.knife"
    case "sports", "sport":
        return "figure.run"
    default:
        return "calendar"
    }
}

private func selectedDateLabel(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, MMM d"
    return formatter.string(from: value)
}

private func selectedTimeLabel(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: value)
}
