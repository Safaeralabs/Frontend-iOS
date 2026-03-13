import MapKit
import SwiftUI

enum ActiveCityStatusButtonStyle {
    case detailed
    case compact
}

struct ActiveCityStatusButton: View {
    @EnvironmentObject private var session: AppSessionStore

    let action: () -> Void
    var style: ActiveCityStatusButtonStyle = .detailed

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if style == .detailed {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.isTravelModeActive ? "TRAVEL MODE" : "HOME BASE")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .tracking(1.1)

                        Text(session.activeCityName ?? session.homeCityName ?? "Choose city")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(session.isTravelModeActive ? "✈️" : "📍")
                            .font(.system(size: 14))

                        Text(session.activeCityName ?? session.homeCityName ?? "Choose city")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if style == .detailed {
                    Text(session.isTravelModeActive ? "✈️ Travel" : "🏠 Home")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(session.isTravelModeActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(
                            (session.isTravelModeActive ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surfaceMuted)
                        )
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: style == .detailed ? 54 : 46)
            .background(Color.white.opacity(0.84))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
            .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        }
        .buttonStyle(.plain)
    }
}

private enum TravelModeScope: String, CaseIterable, Identifiable {
    case home
    case travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "🏠 Home"
        case .travel:
            return "✈️ Travel"
        }
    }
}

struct TravelModeSheet: View {
    @EnvironmentObject private var session: AppSessionStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var citySearch = ApplePlaceSearchModel(resultTypes: [.address])
    @State private var selectedScope: TravelModeScope = .home
    @State private var selectedCityName = ""
    @State private var selectedCityPlaceId = ""
    @State private var isCityLocked = false
    @State private var isResolvingCity = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    FriendZoneModuleHeader(
                        leadingText: "Travel ",
                        highlightText: "Mode",
                        subtitle: "Browse another city without changing your home base.",
                        topInset: 0,
                        horizontalPadding: 16
                    )

                    homeCityCard
                    scopePicker

                    if selectedScope == .travel {
                        travelCityCard
                    }

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .padding(.bottom, 110)
            }
            .background(FriendZoneTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
        .task {
            seedFromSession()
        }
    }

    private var homeCityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOME BASE")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(1.1)

            Text(session.homeCityName ?? "City not set yet")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text("Your profile keeps this city as the default. Travel Mode only changes what you explore.")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.white, FriendZoneTheme.Colors.primarySoft.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var scopePicker: some View {
        HStack(spacing: 8) {
            ForEach(TravelModeScope.allCases) { scope in
                let isActive = scope == selectedScope
                Button {
                    selectedScope = scope
                    errorMessage = nil
                    FriendZoneHaptics.selection()
                } label: {
                    Text(scope.title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            isActive
                                ? LinearGradient(
                                    colors: [FriendZoneTheme.Colors.primary.opacity(0.16), FriendZoneTheme.Colors.primaryAccent.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(colors: [Color.white, Color.white], startPoint: .top, endPoint: .bottom)
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
        .padding(6)
        .background(Color.white.opacity(0.85))
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var travelCityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRAVEL CITY")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(1.1)

                    Text("Pick the city you want to explore right now.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Spacer()

                if isCityLocked {
                    Button {
                        isCityLocked = false
                        citySearch.query = ""
                        selectedCityName = ""
                        selectedCityPlaceId = ""
                        errorMessage = nil
                        FriendZoneHaptics.selection()
                    } label: {
                        Text("✏️")
                            .font(.system(size: 15))
                            .frame(width: 30, height: 30)
                            .background(FriendZoneTheme.Colors.surfaceMuted)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if isCityLocked {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCityName)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        Text("Travel city locked in")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                    }

                    Spacer()

                    Text("✈️")
                        .font(.system(size: 20))
                }
                .padding(14)
                .background(FriendZoneTheme.Colors.primarySoft.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.primarySoftBorder, lineWidth: 1)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                        TextField("Search a city", text: $citySearch.query)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }

                    if isResolvingCity {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Locking city...")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        }
                    } else if !citySearch.suggestions.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(citySearch.suggestions) { suggestion in
                                Button {
                                    Task { await selectSuggestion(suggestion) }
                                } label: {
                                    HStack(spacing: 10) {
                                        Text("📍")
                                            .font(.system(size: 14))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.title)
                                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                                            if !suggestion.subtitle.isEmpty {
                                                Text(suggestion.subtitle)
                                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 11)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task { await save() }
            } label: {
                Text(actionTitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaving || !canSave)
            .opacity((isSaving || !canSave) ? 0.6 : 1)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var actionTitle: String {
        if isSaving {
            return "Saving..."
        }
        return selectedScope == .home ? "Use Home City" : "Activate Travel Mode"
    }

    private var canSave: Bool {
        switch selectedScope {
        case .home:
            return true
        case .travel:
            return isCityLocked && !selectedCityName.isEmpty && !selectedCityPlaceId.isEmpty
        }
    }

    private func seedFromSession() {
        selectedScope = session.isTravelModeActive ? .travel : .home
        selectedCityName = session.currentProfile?.travelCityName ?? ""
        selectedCityPlaceId = session.currentProfile?.travelCityPlaceId ?? ""
        isCityLocked = !selectedCityName.isEmpty && !selectedCityPlaceId.isEmpty
        citySearch.query = isCityLocked ? selectedCityName : ""
    }

    private func selectSuggestion(_ suggestion: ApplePlaceSuggestion) async {
        isResolvingCity = true
        errorMessage = nil

        defer {
            isResolvingCity = false
        }

        do {
            let resolved = try await citySearch.resolve(suggestion)
            guard let latitude = resolved.latitude, let longitude = resolved.longitude else {
                throw AppSessionError.invalidInput("Could not resolve the selected city.")
            }
            let guessed = try await session.guessLocation(
                lat: latitude,
                lng: longitude,
                cityName: resolved.cityName ?? suggestion.title,
                country: resolved.countryCode ?? resolved.countryName
            )

            selectedCityName = guessed.cityName
            selectedCityPlaceId = guessed.cityPlaceId
            citySearch.query = guessed.cityName
            citySearch.clearSuggestions()
            isCityLocked = true
            FriendZoneHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            switch selectedScope {
            case .home:
                try await session.updateTravelMode(enabled: false)
            case .travel:
                try await session.updateTravelMode(
                    enabled: true,
                    cityName: selectedCityName,
                    cityPlaceId: selectedCityPlaceId
                )
            }
            FriendZoneHaptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
