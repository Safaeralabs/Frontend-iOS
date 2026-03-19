import Combine
import SwiftUI
import MapKit
import UIKit

struct RootTabView: View {
    @EnvironmentObject private var session: AppSessionStore
    @State private var selectedTab: AppTab = .hangouts
    @StateObject private var mapLocation = FriendZoneMapLocationModel()
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @State private var selectedMapSelectionID: String?
    @State private var mapHangouts: [HangoutItem] = []
    @State private var mapHangoutCoordinates: [Int: CLLocationCoordinate2D] = [:]
    @State private var mapEvents: [HangoutsView.DiscoveryEventItem] = []
    @State private var mapEventCoordinates: [Int: CLLocationCoordinate2D] = [:]
    @State private var mapOffers: [HangoutsView.DiscoveryOfferItem] = []
    @State private var mapOfferCoordinates: [Int: CLLocationCoordinate2D] = [:]
    @State private var mapJoinStatuses: [Int: HangoutJoinStatus] = [:]
    @State private var mapDetailHangout: HangoutItem?
    @State private var mapEventDetail: HangoutsView.DiscoveryEventItem?
    @State private var mapOfferDetail: HangoutsView.DiscoveryOfferItem?
    @State private var mapPublicProfileRequest: MapPublicProfileRequest?
    @State private var isPresentingMapCreate = false
    @State private var pendingMapHangoutSource: HangoutSourceType = .hangout
    @State private var pendingMapHangoutSourceLabel: String?
    @State private var pendingMapHangoutSourceEventID: Int?
    @State private var pendingMapHangoutSourceOfferID: Int?
    @State private var shouldRefreshMapHangoutsAfterCreate = false
    @State private var isShowingMapReportAcknowledgement = false
    @State private var isPresentingTravelMode = false
    @State private var isShowingMapBlurLift = false
    @State private var mapTransitionToken = 0
    @State private var lastTabForTransition: AppTab = .hangouts
    @State private var hasRestoredMapViewport = false
    @State private var openingMapDetailHangoutID: Int?
    @State private var openingMapDetailSelectionID: String?
    @State private var shouldCenterOnNextPreciseLocation = false
    @State private var isCenteredOnPreciseLocation = false

    @AppStorage("fz.maps.center.lat") private var storedMapCenterLat: Double = 0
    @AppStorage("fz.maps.center.lon") private var storedMapCenterLon: Double = 0
    @AppStorage("fz.maps.span.latDelta") private var storedMapSpanLatDelta: Double = 0.08
    @AppStorage("fz.maps.span.lonDelta") private var storedMapSpanLonDelta: Double = 0.08

    @State private var userCoordinate = CLLocationCoordinate2D(latitude: 52.5176, longitude: 13.4095)

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
                        .ignoresSafeArea(.container, edges: .top)
                }

                FriendZoneTabBar(selectedTab: $selectedTab)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(2, proxy.safeAreaInsets.bottom - 24))
            }
            .ignoresSafeArea(.container, edges: [.bottom])
            .fullScreenCover(item: $mapDetailHangout, onDismiss: {
                openingMapDetailHangoutID = nil
                openingMapDetailSelectionID = nil
            }) { hangout in
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
            .fullScreenCover(item: $mapEventDetail, onDismiss: {
                openingMapDetailSelectionID = nil
            }) { event in
                NavigationStack {
                    NativeEventDetailView(
                        event: event,
                        creatorProfile: event.creatorProfile,
                        onClose: { mapEventDetail = nil },
                        onJoinSoloSuccess: { mapEventDetail = nil },
                        onCreateHangout: {
                            mapEventDetail = nil
                            selectedTab = .hangouts
                            pendingMapHangoutSource = .event
                            pendingMapHangoutSourceLabel = event.title
                            pendingMapHangoutSourceEventID = event.id
                            pendingMapHangoutSourceOfferID = nil
                            isPresentingMapCreate = true
                        },
                        onShowCreatorProfile: {
                            mapPublicProfileRequest = MapPublicProfileRequest(
                                profile: PublicProfileData(draft: event.creatorProfile),
                                leadingText: "Event ",
                                highlightText: "creator",
                                subtitle: nil
                            )
                        }
                    )
                }
                .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
            }
            .fullScreenCover(item: $mapOfferDetail, onDismiss: {
                openingMapDetailSelectionID = nil
            }) { offer in
                NavigationStack {
                    NativeOfferDetailView(
                        offer: offer,
                        venueProfile: offer.venueProfile,
                        onClose: { mapOfferDetail = nil },
                        onJoinSolo: { mapOfferDetail = nil },
                        onCreateHangout: {
                            mapOfferDetail = nil
                            selectedTab = .hangouts
                            pendingMapHangoutSource = .offer
                            pendingMapHangoutSourceLabel = offer.title
                            pendingMapHangoutSourceEventID = nil
                            pendingMapHangoutSourceOfferID = offer.id
                            isPresentingMapCreate = true
                        },
                        onShowVenueProfile: {
                            mapPublicProfileRequest = MapPublicProfileRequest(
                                profile: PublicProfileData(draft: offer.venueProfile),
                                leadingText: "Venue ",
                                highlightText: "profile",
                                subtitle: nil
                            )
                        }
                    )
                }
                .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
            }
            .fullScreenCover(isPresented: $isPresentingMapCreate) {
                CreateHangoutView(
                    onCancel: { isPresentingMapCreate = false },
                    onCreated: { _ in
                        shouldRefreshMapHangoutsAfterCreate = true
                    },
                    initialDraft: CreateHangoutDraft(
                        cityName: session.activeCityName ?? "",
                        cityPlaceID: session.activeCityPlaceId ?? "",
                        sourceType: pendingMapHangoutSource,
                        sourceLabel: pendingMapHangoutSourceLabel,
                        sourceEventID: pendingMapHangoutSourceEventID,
                        sourceOfferID: pendingMapHangoutSourceOfferID
                    )
                )
                .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
            }
            .onChange(of: isPresentingMapCreate) { isPresented in
                guard !isPresented, shouldRefreshMapHangoutsAfterCreate else { return }
                shouldRefreshMapHangoutsAfterCreate = false
                Task {
                    await loadMapHangouts()
                }
            }
            .sheet(item: $mapPublicProfileRequest) { request in
                NavigationStack {
                    PublicProfileView(
                        profile: request.profile,
                        leadingText: request.leadingText,
                        highlightText: request.highlightText,
                        subtitle: request.subtitle
                    ) {
                        mapPublicProfileRequest = nil
                    }
                }
                .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
            }
            .sheet(isPresented: $isPresentingTravelMode) {
                TravelModeSheet()
                    .environmentObject(session)
            }
            .alert("Report sent", isPresented: $isShowingMapReportAcknowledgement) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thanks. We will review this hangout.")
            }
            .onChange(of: selectedTab) { current in
                if current == .maps, lastTabForTransition != .maps {
                    triggerMapBlurLift()
                    Task { await loadMapDiscoveryData() }
                }
                lastTabForTransition = current
            }
            .onAppear {
                guard !hasRestoredMapViewport else { return }
                hasRestoredMapViewport = true
                centerMapOnRegisteredHome()
                Task { await loadMapDiscoveryData() }
            }
            .onChange(of: session.currentProfile?.activeCityPlaceId) { _ in
                centerMapOnRegisteredHome()
                Task { await loadMapDiscoveryData() }
            }
            .onReceive(mapLocation.$coordinate) { coordinate in
                guard let coordinate else { return }
                userCoordinate = coordinate
                guard shouldCenterOnNextPreciseLocation else { return }
                shouldCenterOnNextPreciseLocation = false
                isCenteredOnPreciseLocation = true
                focusMap(on: coordinate, span: preciseUserMapSpan)
            }
            .onChange(of: mapRegion.center.latitude) { _ in
                persistMapViewport()
            }
            .onChange(of: mapRegion.center.longitude) { _ in
                persistMapViewport()
            }
            .onChange(of: mapRegion.span.latitudeDelta) { _ in
                persistMapViewport()
            }
            .onChange(of: mapRegion.span.longitudeDelta) { _ in
                persistMapViewport()
            }
        }
    }

    private var hangoutsMapsStage: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width
            let showingMaps = selectedTab == .maps

            ZStack {
                FriendZoneMapCanvasView(
                    region: $mapRegion,
                    hangouts: mapHangouts,
                    hangoutCoordinates: mapHangoutCoordinates,
                    events: mapEvents,
                    eventCoordinates: mapEventCoordinates,
                    offers: mapOffers,
                    offerCoordinates: mapOfferCoordinates,
                    userCoordinate: userCoordinate,
                    selectedSelectionID: $selectedMapSelectionID,
                    isInteractive: showingMaps
                )
                .ignoresSafeArea()

                mapBrandTint
                    .opacity(showingMaps ? 0 : 1)
                    .ignoresSafeArea()
                mapBrandPattern
                    .opacity(showingMaps ? 0 : 1)
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

                    FriendZoneMapChromeView(
                        selectedItem: selectedMapItem,
                        openingDetailHangoutID: openingMapDetailHangoutID,
                        openingDetailSelectionID: openingMapDetailSelectionID,
                        isActive: showingMaps,
                        cityLabel: mapCityLabel,
                        isTravelModeActive: session.isTravelModeActive,
                        plansCount: mapHangouts.count + mapEvents.count + mapOffers.count,
                        isLocatingUser: mapLocation.isLocating,
                        isUsingPreciseLocation: isCenteredOnPreciseLocation,
                        onOpenTravelMode: {
                            isPresentingTravelMode = true
                        },
                        onCloseSelection: {
                            selectedMapSelectionID = nil
                            openingMapDetailHangoutID = nil
                            openingMapDetailSelectionID = nil
                        },
                        onLocateMe: {
                            if let preciseCoordinate = mapLocation.coordinate {
                                userCoordinate = preciseCoordinate
                                isCenteredOnPreciseLocation = true
                                focusMap(on: preciseCoordinate, span: preciseUserMapSpan)
                            } else {
                                shouldCenterOnNextPreciseLocation = true
                                mapLocation.requestLocation()
                            }
                        },
                        onOpenHangoutDetail: { hangout in
                            FriendZoneHaptics.selection()
                            openingMapDetailHangoutID = hangout.id
                            openingMapDetailSelectionID = "hangout-\(hangout.id)"
                            let openingID = hangout.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                guard openingMapDetailHangoutID == openingID else { return }
                                mapDetailHangout = hangout
                                openingMapDetailHangoutID = nil
                                openingMapDetailSelectionID = nil
                            }
                        },
                        onOpenEventDetail: { event in
                            FriendZoneHaptics.selection()
                            openingMapDetailSelectionID = "event-\(event.id)"
                            let openingID = event.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                guard openingMapDetailSelectionID == "event-\(openingID)" else { return }
                                mapEventDetail = event
                                openingMapDetailSelectionID = nil
                            }
                        },
                        onOpenOfferDetail: { offer in
                            FriendZoneHaptics.selection()
                            openingMapDetailSelectionID = "offer-\(offer.id)"
                            let openingID = offer.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                guard openingMapDetailSelectionID == "offer-\(openingID)" else { return }
                                mapOfferDetail = offer
                                openingMapDetailSelectionID = nil
                            }
                        },
                        onReportSelection: { _ in
                            FriendZoneHaptics.lightImpact()
                            isShowingMapReportAcknowledgement = true
                        }
                    )
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

    private var selectedMapItem: SelectedMapDiscoveryItem? {
        guard let selectedMapSelectionID else { return nil }
        if
            selectedMapSelectionID.hasPrefix("hangout-"),
            let id = Int(selectedMapSelectionID.replacingOccurrences(of: "hangout-", with: "")),
            let hangout = mapHangouts.first(where: { $0.id == id })
        {
            return .hangout(hangout)
        }
        if
            selectedMapSelectionID.hasPrefix("event-"),
            let id = Int(selectedMapSelectionID.replacingOccurrences(of: "event-", with: "")),
            let event = mapEvents.first(where: { $0.id == id })
        {
            return .event(event)
        }
        if
            selectedMapSelectionID.hasPrefix("offer-"),
            let id = Int(selectedMapSelectionID.replacingOccurrences(of: "offer-", with: "")),
            let offer = mapOffers.first(where: { $0.id == id })
        {
            return .offer(offer)
        }
        return nil
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

    @MainActor
    private func loadMapDiscoveryData() async {
        async let hangoutsLoad: Void = loadMapHangouts()
        async let eventsLoad: Void = loadMapEvents()
        async let offersLoad: Void = loadMapOffers()
        _ = await (hangoutsLoad, eventsLoad, offersLoad)
    }

    @MainActor
    private func loadMapHangouts() async {
        do {
            let items = try await session.fetchHangouts(
                cityPlaceId: session.activeCityPlaceId
            )
            let now = Date()
            let currentUserID = session.currentUser?.id ?? session.currentProfile?.user?.id
            let mapped = items.compactMap { item -> HangoutItem? in
                guard
                    let startAt = parseServerDate(item.startAt),
                    let endAt = parseServerDate(item.endAt)
                else {
                    return nil
                }

                let participantNames = item.participants
                    .filter { $0.status.lowercased() == "approved" && $0.user != item.host }
                    .map(\.username)
                let isJoined = item.participants.contains {
                    $0.user == currentUserID && $0.status.lowercased() == "approved"
                }

                return HangoutItem(
                    id: item.id,
                    sourceType: mapSourceType(item.sourceType),
                    title: item.title,
                    description: item.description,
                    vibe: mapVibe(item.vibe),
                    cityName: item.cityName,
                    locationName: item.locationName,
                    locationAddress: item.locationAddress,
                    latitude: item.lat,
                    longitude: item.lng,
                    hostUserID: item.host,
                    hostName: item.host == currentUserID ? "you" : item.hostUsername,
                    startAt: startAt,
                    endAt: endAt,
                    capacity: item.capacity,
                    isCapacityUnlimited: item.isCapacityUnlimited,
                    approvedCount: item.approvedParticipantsCount ?? max(1, participantNames.count + 1),
                    isJoined: isJoined || item.host == currentUserID,
                    participantNames: participantNames,
                    coverImageData: nil,
                    coverImageURL: item.coverImageUrl,
                    coverSeed: item.id,
                    distanceKm: 1.2,
                    priceTier: .free,
                    visibility: item.visibility.flatMap(HangoutVisibilityOption.init(backendRawValue:)),
                    inviteCode: item.inviteCode,
                    inviteCodeHint: item.inviteCodeHint,
                    allowWaitlist: item.allowWaitlist,
                    genderPreference: item.genderPreference.flatMap(HangoutGenderPreference.init(backendRawValue:)),
                    audienceTags: item.audienceTags,
                    languages: item.languages,
                    isTimeFlexible: item.isTimeFlexible,
                    sourceEventID: item.sourceEventId,
                    sourceOfferID: item.sourceOfferId
                )
            }
            let activeMapped = mapped.filter { $0.endAt > now }
            let activeIDs = Set(activeMapped.map(\.id))

            let coordinatePairs = items.compactMap { item -> (Int, CLLocationCoordinate2D)? in
                guard activeIDs.contains(item.id) else { return nil }
                guard let exactCoordinate = validCoordinate(lat: item.lat, lng: item.lng) else {
                    return nil
                }
                let isJoined = item.host == currentUserID || item.participants.contains {
                    $0.user == currentUserID && $0.status.lowercased() == "approved"
                }
                let displayCoordinate = isJoined
                    ? exactCoordinate
                    : obfuscatedHangoutCoordinate(exactCoordinate, hangoutID: item.id)
                return (item.id, displayCoordinate)
            }
            let visibleIDs = Set(coordinatePairs.map { $0.0 })
            mapHangouts = activeMapped
                .filter { visibleIDs.contains($0.id) }
                .sorted { $0.startAt < $1.startAt }
            mapHangoutCoordinates = Dictionary(uniqueKeysWithValues: coordinatePairs)
            mapJoinStatuses = Dictionary(
                uniqueKeysWithValues: mapHangouts.map { item in
                    (item.id, item.isJoined ? .joined : .none)
                }
            )
        } catch {
            mapHangouts = []
            mapHangoutCoordinates = [:]
            mapJoinStatuses = [:]
        }
    }

    @MainActor
    private func loadMapEvents() async {
        do {
            let items = try await session.fetchUpcomingEvents(cityPlaceId: session.activeCityPlaceId)
            let mapped = items.compactMap(mapDiscoveryEvent)
            let coordinatePairs = items.compactMap { item -> (Int, CLLocationCoordinate2D)? in
                guard
                    mapped.contains(where: { $0.id == item.id }),
                    let coordinate = validCoordinate(lat: item.lat, lng: item.lng)
                else {
                    return nil
                }
                return (item.id, coordinate)
            }
            let visibleIDs = Set(coordinatePairs.map { $0.0 })
            mapEvents = mapped
                .filter { visibleIDs.contains($0.id) }
                .sorted { $0.startAt < $1.startAt }
            mapEventCoordinates = Dictionary(uniqueKeysWithValues: coordinatePairs)
        } catch {
            mapEvents = []
            mapEventCoordinates = [:]
        }
    }

    @MainActor
    private func loadMapOffers() async {
        do {
            let items = try await session.fetchActiveOffers(cityPlaceId: session.activeCityPlaceId)
            mapOffers = []
            mapOfferCoordinates = [:]
        } catch {
            mapOffers = []
            mapOfferCoordinates = [:]
        }
    }

    private func mapDiscoveryEvent(_ item: DiscoveryEventFeedItem) -> HangoutsView.DiscoveryEventItem? {
        guard let startAt = parseServerDate(item.startAt) else { return nil }
        let venue = item.venueName ?? item.city ?? "Event venue"
        let displayName = item.creatorDisplayName ?? item.creatorUsername ?? "Event creator"
        return HangoutsView.DiscoveryEventItem(
            id: item.id,
            title: item.title,
            venue: venue,
            startAt: startAt,
            groups: max(item.hangoutsCount ?? 0, 1),
            category: item.category ?? "Event",
            creatorProfile: CreatorProfileDraft(
                userID: item.creator,
                displayName: displayName,
                username: item.creatorUsername,
                bio: "\(venue) · \(item.category ?? "Event")",
                instagram: item.creatorUsername ?? "",
                website: "",
                city: item.city ?? "Berlin",
                avatarURL: item.creatorAvatarUrl
            ),
            photoMoments: item.primaryImageUrl == nil ? [] : [
                HangoutsView.EventPhotoMoment(
                    id: item.id,
                    title: "Event moment",
                    subtitle: venue,
                    symbol: "photo",
                    palette: [Color(hex: "#171717"), Color(hex: "#525252"), Color(hex: "#A3A3A3")]
                )
            ]
        )
    }

    private func mapDiscoveryOffer(_ item: DiscoveryOfferFeedItem) -> HangoutsView.DiscoveryOfferItem? {
        guard let validUntil = parseServerDate(item.validUntil) else { return nil }
        return HangoutsView.DiscoveryOfferItem(
            id: item.id,
            title: item.title,
            venue: item.venueName ?? "Venue",
            perk: item.perk,
            validUntil: validUntil,
            spotsLeft: max(item.spotsRemaining ?? 0, 0),
            venueProfile: CreatorProfileDraft(
                userID: item.owner,
                displayName: item.venueName ?? (item.ownerUsername ?? "Venue"),
                username: item.ownerUsername,
                bio: item.description ?? "Venue offer available through FriendZone.",
                instagram: item.ownerUsername ?? "",
                website: "",
                city: session.activeCityName ?? "Berlin"
            )
        )
    }

    private func parseServerDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    private func mapSourceType(_ raw: String) -> HangoutSourceType {
        switch raw.lowercased() {
        case "event":
            return .event
        case "offer":
            return .offer
        default:
            return .hangout
        }
    }

    private func mapVibe(_ raw: String) -> HangoutVibe {
        HangoutVibe(backendRawValue: raw) ?? .chill
    }

    private func validCoordinate(lat: Double?, lng: Double?) -> CLLocationCoordinate2D? {
        guard let lat, let lng, abs(lat) <= 90, abs(lng) <= 180 else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private func obfuscatedHangoutCoordinate(_ coordinate: CLLocationCoordinate2D, hangoutID: Int) -> CLLocationCoordinate2D {
        let angle = Double((hangoutID * 73) % 360) * .pi / 180
        let radiusMeters = 220 + Double((hangoutID * 37) % 140)
        let latitudeOffset = (radiusMeters / 111_320.0) * cos(angle)
        let longitudeScale = max(1, 111_320.0 * cos(coordinate.latitude * .pi / 180))
        let longitudeOffset = (radiusMeters / longitudeScale) * sin(angle)
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latitudeOffset,
            longitude: coordinate.longitude + longitudeOffset
        )
    }

    private func geocodeCityCenter(_ cityName: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(cityName) { placemarks, _ in
            DispatchQueue.main.async {
                let coordinate = placemarks?.first?.location?.coordinate
                    ?? CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
                userCoordinate = coordinate
                isCenteredOnPreciseLocation = false
                focusMap(on: coordinate, span: cityFallbackMapSpan)
            }
        }
    }

    private var mapCityLabel: String {
        let city = session.activeCityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return city.isEmpty ? "Your area" : city
    }

    private func centerMapOnRegisteredHome() {
        let cityName = session.activeCityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        isCenteredOnPreciseLocation = false

        if !cityName.isEmpty {
            geocodeCityCenter(cityName)
        } else if hasStoredMapViewport {
            restoreStoredMapViewport()
        }
    }

    private var hasStoredMapViewport: Bool {
        storedMapCenterLat != 0 || storedMapCenterLon != 0
    }

    private var preciseUserMapSpan: MKCoordinateSpan {
        MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
    }

    private var cityFallbackMapSpan: MKCoordinateSpan {
        MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    }

    private func focusMap(on coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            mapRegion = MKCoordinateRegion(center: coordinate, span: span)
        }
    }

    private func restoreStoredMapViewport() {
        let restoredLat = min(90, max(-90, storedMapCenterLat))
        let restoredLon = min(180, max(-180, storedMapCenterLon))
        let coordinate = CLLocationCoordinate2D(latitude: restoredLat, longitude: restoredLon)
        userCoordinate = coordinate
        isCenteredOnPreciseLocation = false
        focusMap(on: coordinate, span: MKCoordinateSpan(
            latitudeDelta: min(80, max(0.002, storedMapSpanLatDelta)),
            longitudeDelta: min(80, max(0.002, storedMapSpanLonDelta))
        ))
    }

    private func persistMapViewport() {
        let lat = mapRegion.center.latitude
        let lon = mapRegion.center.longitude
        let latDelta = mapRegion.span.latitudeDelta
        let lonDelta = mapRegion.span.longitudeDelta

        guard lat.isFinite, lon.isFinite, latDelta.isFinite, lonDelta.isFinite else {
            return
        }

        storedMapCenterLat = min(90, max(-90, lat))
        storedMapCenterLon = min(180, max(-180, lon))
        storedMapSpanLatDelta = min(80, max(0.002, latDelta))
        storedMapSpanLonDelta = min(80, max(0.002, lonDelta))
    }
}

#if DEBUG
struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}
#endif

private struct PersistentDiscoveryMapView: View {
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

    private var userInitials: String {
        if let first = session.currentProfile?.user?.firstName?.prefix(1), !first.isEmpty {
            return first.uppercased()
        }
        if let first = session.currentUser?.firstName?.prefix(1), !first.isEmpty {
            return first.uppercased()
        }
        return String(session.currentUser?.username.prefix(1).uppercased() ?? "?")
    }

    private var markers: [DiscoveryMapMarker] {
        var items = [DiscoveryMapMarker.user(coordinate: userCoordinate)]
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
                switch marker.kind {
                case .user:
                    userMarker
                case let .hangout(id, vibe, isToday):
                    Button {
                        setSelection("hangout-\(id)")
                    } label: {
                        hangoutMarker(vibe: vibe, isToday: isToday)
                    }
                    .buttonStyle(.plain)
                case let .event(id, category):
                    Button {
                        setSelection("event-\(id)")
                    } label: {
                        eventMarker(category: category)
                    }
                    .buttonStyle(.plain)
                case let .offer(id, isHot):
                    Button {
                        setSelection("offer-\(id)")
                    } label: {
                        offerMarker(isHot: isHot)
                    }
                    .buttonStyle(.plain)
                case let .cluster(count, vibe, isToday, hangoutIDs):
                    Button {
                        FriendZoneHaptics.lightImpact()
                        if region.span.latitudeDelta > 0.012 || region.span.longitudeDelta > 0.012 {
                            withAnimation(.easeInOut(duration: 0.24)) {
                                region.center = marker.coordinate
                                region.span = MKCoordinateSpan(
                                    latitudeDelta: max(0.008, region.span.latitudeDelta * 0.52),
                                    longitudeDelta: max(0.008, region.span.longitudeDelta * 0.52)
                                )
                            }
                        } else if let firstID = hangoutIDs.first {
                            setSelection("hangout-\(firstID)")
                        }
                    } label: {
                        clusterMarker(count: count, vibe: vibe, isToday: isToday)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: selectedSelectionID) { id in
            guard let id else { return }
            centerMap(on: coordinate(for: id))
        }
    }

    private var userMarker: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1F2937"), Color(hex: "#111827")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 11, height: 11)
                .rotationEffect(.degrees(45))
                .offset(y: 5)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#374151"), Color(hex: "#111827")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Text(userInitials)
                        .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 2.5)
                }
                .shadow(color: Color.black.opacity(0.32), radius: 10, x: 0, y: 4)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(hex: "#30D158"))
                        .frame(width: 12, height: 12)
                        .overlay { Circle().stroke(Color.white, lineWidth: 2) }
                }
        }
    }

    private func hangoutMarker(vibe: HangoutVibe, isToday: Bool) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [vibeColor(vibe), vibeColor(vibe).opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 11, height: 11)
                .rotationEffect(.degrees(45))
                .offset(y: 5)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [vibeColor(vibe).opacity(0.95), vibeColor(vibe).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay {
                    Text(vibeEmoji(vibe))
                        .font(.system(size: 20))
                }
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 2.5)
                }
                .shadow(color: vibeColor(vibe).opacity(0.45), radius: 8, x: 0, y: 3)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                .overlay(alignment: .topTrailing) {
                    if isToday {
                        Circle()
                            .fill(Color(hex: "#FF3B30"))
                            .frame(width: 11, height: 11)
                            .overlay { Circle().stroke(Color.white, lineWidth: 2) }
                    }
                }
        }
    }

    private func clusterMarker(count: Int, vibe: HangoutVibe, isToday: Bool) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1F2937"), Color(hex: "#374151")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 11, height: 11)
                .rotationEffect(.degrees(45))
                .offset(y: 5)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1F2937"), Color(hex: "#374151")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Text("\(count)")
                        .font(FriendZoneTheme.Typography.system(15, weight: .heavy))
                        .foregroundColor(.white)
                }
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 2.5)
                }
                .shadow(color: Color.black.opacity(0.32), radius: 10, x: 0, y: 4)
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Text(vibeEmoji(vibe))
                            .font(.system(size: 11))
                            .padding(3)
                            .background(Color.white.opacity(0.92))
                            .clipShape(Circle())
                            .offset(x: 6, y: -4)
                        if isToday {
                            Circle()
                                .fill(Color(hex: "#FF3B30"))
                                .frame(width: 10, height: 10)
                                .overlay { Circle().stroke(Color.white, lineWidth: 2) }
                                .offset(x: 10, y: -18)
                        }
                    }
                }
        }
    }

    private func eventMarker(category: String) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#0E7490"), Color(hex: "#155E75")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: eventSymbol(for: category))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white, lineWidth: 3)
                }
                .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 3)

            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 14, height: 14)
                .overlay {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(Color(hex: "#0E7490"))
                }
                .offset(x: 6, y: -6)
        }
    }

    private func offerMarker(isHot: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#F59E0B"), Color(hex: "#B45309")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white, lineWidth: 3)
                }
                .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 3)

            if isHot {
                Circle()
                    .fill(Color(hex: "#FF3B30"))
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle().stroke(Color.white, lineWidth: 2)
                    }
                    .offset(x: 8, y: -6)
            }
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

    private func setSelection(_ selectionID: String) {
        if selectedSelectionID == selectionID {
            selectedSelectionID = nil
            return
        }

        selectedSelectionID = selectionID
        centerMap(on: coordinate(for: selectionID))
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.22)) {
            region = MKCoordinateRegion(center: coordinate, span: region.span)
        }
    }

    private func clusteredHangoutMarkers() -> [DiscoveryMapMarker] {
        struct Point {
            let hangout: HangoutItem
            let coordinate: CLLocationCoordinate2D
        }

        var buckets: [String: [Point]] = [:]
        let latCell = max(0.004, region.span.latitudeDelta / 8)
        let lonCell = max(0.004, region.span.longitudeDelta / 8)

        let points = hangouts.map { hangout in
            Point(
                hangout: hangout,
                coordinate: hangoutCoordinates[hangout.id] ?? userCoordinate
            )
        }

        for point in points {
            let latIndex = Int(floor(point.coordinate.latitude / latCell))
            let lonIndex = Int(floor(point.coordinate.longitude / lonCell))
            let key = "\(latIndex)_\(lonIndex)"
            buckets[key, default: []].append(point)
        }

        var markers: [DiscoveryMapMarker] = []

        for bucket in buckets.values {
            let sorted = bucket.sorted { $0.hangout.startAt < $1.hangout.startAt }
            if sorted.count == 1, let single = sorted.first {
                markers.append(
                    DiscoveryMapMarker.hangout(
                        id: single.hangout.id,
                        coordinate: single.coordinate,
                        vibe: single.hangout.vibe,
                        isToday: Calendar.current.isDateInToday(single.hangout.startAt)
                    )
                )
                continue
            }

            let avgLat = sorted.map(\.coordinate.latitude).reduce(0, +) / Double(sorted.count)
            let avgLon = sorted.map(\.coordinate.longitude).reduce(0, +) / Double(sorted.count)
            let lead = sorted[0].hangout
            let ids = sorted.map { $0.hangout.id }
            let anyToday = sorted.contains(where: { Calendar.current.isDateInToday($0.hangout.startAt) })

            markers.append(
                DiscoveryMapMarker.cluster(
                    id: -abs(ids.reduce(0, +) + sorted.count * 97),
                    coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    count: sorted.count,
                    vibe: lead.vibe,
                    isToday: anyToday,
                    hangoutIDs: ids
                )
            )
        }

        return markers
    }

    private func eventMarkers() -> [DiscoveryMapMarker] {
        events.compactMap { event in
            guard let coordinate = eventCoordinates[event.id] else { return nil }
            return .event(
                id: event.id,
                coordinate: coordinate,
                category: event.category
            )
        }
    }

    private func offerMarkers() -> [DiscoveryMapMarker] {
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

    private func vibeColor(_ vibe: HangoutVibe) -> Color {
        vibe.accentColor
    }

    private func vibeEmoji(_ vibe: HangoutVibe) -> String {
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
}

private struct MapsOverlayView: View {
    let hangouts: [HangoutItem]
    let selectedItem: SelectedMapDiscoveryItem?
    let openingDetailHangoutID: Int?
    let openingDetailSelectionID: String?
    let isActive: Bool
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
            ZStack(alignment: .bottom) {
                mapsHeader(topInset: topInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(isActive)
                .opacity(isActive ? 1 : 0.0)
                .offset(y: isActive ? 0 : -8)
                .animation(.easeOut(duration: 0.24), value: isActive)

                if let selectedItem {
                    markerMiniPreview(selectedItem)
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(90, bottomInset + 72))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .opacity(isActive ? 1 : 0.0)
                        .offset(y: isActive ? 0 : 18)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: onLocateMe) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(FriendZoneTheme.Colors.primary)
                                .frame(width: 48, height: 48)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .stroke(FriendZoneTheme.Colors.primary.opacity(0.25), lineWidth: 1)
                                }
                                .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.bottom, max(selectedItem == nil ? 96 : 188, bottomInset + 74))
                        .opacity(isActive ? 1 : 0)
                        .offset(y: isActive ? 0 : 12)
                        .animation(.easeOut(duration: 0.24), value: isActive)
                    }
                }
            }
            .background(Color.clear)
            .animation(.easeOut(duration: 0.24), value: isActive)
            .animation(.easeOut(duration: 0.2), value: selectedItem?.id)
        }
    }

    private func mapsHeader(topInset: CGFloat) -> some View {
        FriendZoneModuleHeader(
            leadingText: "Explore ",
            highlightText: "Maps",
            topInset: topInset,
            horizontalPadding: FriendZoneTheme.Chrome.horizontalInset
        )
        .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
    }

    @ViewBuilder
    private func markerMiniPreview(_ item: SelectedMapDiscoveryItem) -> some View {
        switch item {
        case let .hangout(hangout):
            hangoutMiniPreview(
                hangout,
                isOpeningDetail: openingDetailHangoutID == hangout.id
            )
        case let .event(event):
            eventMiniPreview(
                event,
                isOpeningDetail: openingDetailSelectionID == item.id
            )
        case let .offer(offer):
            offerMiniPreview(
                offer,
                isOpeningDetail: openingDetailSelectionID == item.id
            )
        }
    }

    private func hangoutMiniPreview(_ hangout: HangoutItem, isOpeningDetail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                previewThumbnail(hangout)

                VStack(alignment: .leading, spacing: 4) {
                    Text(hangout.publicLocationDisplay.uppercased())
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .lineLimit(1)

                Text(hangout.title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .lineLimit(2)

                    Text("Hosted by \(hangout.hostName)")
                        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button(action: onCloseSelection) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    mapMetaChip(icon: "clock.fill", text: timeLabel(hangout.startAt))
                    mapMetaChip(icon: "figure.walk", text: hangout.distanceLabel)
                    mapMetaChip(icon: "person.2.fill", text: hangout.spotsLeft > 0 ? "\(hangout.spotsLeft) left" : "Full")
                    if !hangout.hasUnlockedLocation {
                        mapMetaChip(icon: "lock.fill", text: "Area only")
                    }
                    mapMetaChip(icon: "tag.fill", text: hangout.priceTier.shortLabel)
                    if Calendar.current.isDateInToday(hangout.startAt) {
                        mapMetaChip(icon: "sparkles", text: "TODAY", isAccent: true)
                    }
                }
            }
            .scrollDisabled(true)
            .allowsHitTesting(false)

            HStack(spacing: 8) {
                Button {
                    onOpenHangoutDetail(hangout)
                } label: {
                    Text("View details")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isOpeningDetail)

                Button {
                    onReportSelection(.hangout(hangout))
                } label: {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .frame(width: 38, height: 36)
                        .background(FriendZoneTheme.Colors.error.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.error.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isOpeningDetail)
            }
        }
        .padding(11)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.md)
        .scaleEffect(isOpeningDetail ? 0.97 : 1.0)
        .opacity(isOpeningDetail ? 0.34 : 1.0)
        .blur(radius: isOpeningDetail ? 1.8 : 0)
        .animation(.easeInOut(duration: 0.16), value: isOpeningDetail)
    }

    private func eventMiniPreview(_ event: HangoutsView.DiscoveryEventItem, isOpeningDetail: Bool) -> some View {
        previewShell(
            eyebrow: event.category.uppercased(),
            title: event.title,
            subtitle: event.venue,
            chips: [
                ("calendar", eventDateLabel(event.startAt)),
                ("clock.fill", timeLabel(event.startAt)),
                ("person.3.fill", "\(event.groups) groups")
            ],
            accent: Color(hex: "#0E7490"),
            isOpeningDetail: isOpeningDetail,
            onPrimary: { onOpenEventDetail(event) },
            onReport: { onReportSelection(.event(event)) }
        )
    }

    private func offerMiniPreview(_ offer: HangoutsView.DiscoveryOfferItem, isOpeningDetail: Bool) -> some View {
        previewShell(
            eyebrow: "VOUCHER",
            title: offer.title,
            subtitle: offer.venue,
            chips: [
                ("gift.fill", offer.perk),
                ("clock.badge", "Until \(eventDateLabel(offer.validUntil))"),
                ("tag.fill", offer.spotsLeft > 0 ? "\(offer.spotsLeft) left" : "Full")
            ],
            accent: Color(hex: "#B45309"),
            isOpeningDetail: isOpeningDetail,
            onPrimary: { onOpenOfferDetail(offer) },
            onReport: { onReportSelection(.offer(offer)) }
        )
    }

    private func previewShell(
        eyebrow: String,
        title: String,
        subtitle: String,
        chips: [(String, String)],
        accent: Color,
        isOpeningDetail: Bool,
        onPrimary: @escaping () -> Void,
        onReport: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.92), accent.opacity(0.66)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 66, height: 66)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white.opacity(0.92))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(accent)
                        .lineLimit(1)

                    Text(title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
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
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.1) { chip in
                        mapMetaChip(icon: chip.0, text: chip.1)
                    }
                }
            }
            .scrollDisabled(true)
            .allowsHitTesting(false)

            HStack(spacing: 8) {
                Button(action: onPrimary) {
                    Text("View details")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isOpeningDetail)

                Button(action: onReport) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .frame(width: 38, height: 36)
                        .background(FriendZoneTheme.Colors.error.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.error.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isOpeningDetail)
            }
        }
        .padding(11)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.md)
        .scaleEffect(isOpeningDetail ? 0.97 : 1.0)
        .opacity(isOpeningDetail ? 0.34 : 1.0)
        .blur(radius: isOpeningDetail ? 1.8 : 0)
        .animation(.easeInOut(duration: 0.16), value: isOpeningDetail)
    }

    private func previewThumbnail(_ hangout: HangoutItem) -> some View {
        ZStack {
            if
                let data = hangout.coverImageData,
                let image = UIImage(data: data)
            {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 66, height: 66)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [vibeColor(hangout.vibe), vibeColor(hangout.vibe).opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Text(vibeEmoji(hangout.vibe))
                        .font(.system(size: 25))
                }
            }
        }
        .frame(width: 66, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        }
    }

    private func mapMetaChip(icon: String, text: String, isAccent: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(isAccent ? .white : FriendZoneTheme.Colors.textSecondary)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            isAccent ? Color(hex: "#FF3B30") : Color.black.opacity(0.06)
        )
        .clipShape(Capsule())
    }

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func eventDateLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: value)
    }

    private func vibeColor(_ vibe: HangoutVibe) -> Color {
        vibe.accentColor
    }

    private func vibeEmoji(_ vibe: HangoutVibe) -> String {
        vibe.emoji
    }
}

enum SelectedMapDiscoveryItem: Identifiable {
    case hangout(HangoutItem)
    case event(HangoutsView.DiscoveryEventItem)
    case offer(HangoutsView.DiscoveryOfferItem)

    var id: String {
        switch self {
        case let .hangout(hangout):
            return "hangout-\(hangout.id)"
        case let .event(event):
            return "event-\(event.id)"
        case let .offer(offer):
            return "offer-\(offer.id)"
        }
    }
}

private struct MapPublicProfileRequest: Identifiable {
    let id = UUID()
    let profile: PublicProfileData
    let leadingText: String
    let highlightText: String
    let subtitle: String?
}

private struct DiscoveryMapMarker: Identifiable {
    enum Kind {
        case user
        case hangout(id: Int, vibe: HangoutVibe, isToday: Bool)
        case event(id: Int, category: String)
        case offer(id: Int, isHot: Bool)
        case cluster(count: Int, vibe: HangoutVibe, isToday: Bool, hangoutIDs: [Int])
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

    static func event(id: Int, coordinate: CLLocationCoordinate2D, category: String) -> DiscoveryMapMarker {
        DiscoveryMapMarker(id: 100_000 + id, coordinate: coordinate, kind: .event(id: id, category: category))
    }

    static func offer(id: Int, coordinate: CLLocationCoordinate2D, isHot: Bool) -> DiscoveryMapMarker {
        DiscoveryMapMarker(id: 200_000 + id, coordinate: coordinate, kind: .offer(id: id, isHot: isHot))
    }

    static func cluster(
        id: Int,
        coordinate: CLLocationCoordinate2D,
        count: Int,
        vibe: HangoutVibe,
        isToday: Bool,
        hangoutIDs: [Int]
    ) -> DiscoveryMapMarker {
        DiscoveryMapMarker(
            id: id,
            coordinate: coordinate,
            kind: .cluster(count: count, vibe: vibe, isToday: isToday, hangoutIDs: hangoutIDs)
        )
    }
}
