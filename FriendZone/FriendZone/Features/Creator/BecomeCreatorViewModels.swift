import Foundation
import Combine

@MainActor
final class SettingsCreatorContextViewModel: ObservableObject {
    @Published private(set) var userFlags: SettingsUserRoleFlags
    @Published private(set) var isLoading = false
    @Published private(set) var loadErrorMessage: String?

    private let profileAPI: SettingsProfileAPIServiceProtocol
    private var hasLoaded = false

    init(userFlags: SettingsUserRoleFlags, profileAPI: SettingsProfileAPIServiceProtocol? = nil) {
        self.userFlags = userFlags
        self.profileAPI = profileAPI ?? SettingsProfileAPIService()
    }

    convenience init(profileAPI: SettingsProfileAPIServiceProtocol? = nil) {
        self.init(
            userFlags: AppSessionStore.shared.roleFlags,
            profileAPI: profileAPI
        )
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedFlags = try await profileAPI.fetchUserRoleFlags()
            userFlags = fetchedFlags
            loadErrorMessage = nil
            hasLoaded = true
        } catch {
            loadErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not load profile settings."
        }
    }

    func markRoleGranted(_ roleType: RoleType) {
        switch roleType {
        case .eventCreator:
            userFlags.isEventCreator = true
        case .venueOwner:
            userFlags.isVenueOwner = true
        }
    }
}

@MainActor
final class BecomeCreatorViewModel: ObservableObject {
    struct UserMessage: Identifiable, Equatable {
        enum Kind {
            case success
            case error
        }

        let id = UUID()
        let kind: Kind
        let text: String
    }

    @Published private(set) var userFlags: SettingsUserRoleFlags
    @Published private(set) var requests: [RoleRequest] = []

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var activeRole: RoleType?

    @Published var orgName = ""
    @Published var orgDescription = ""

    @Published var venueName = ""
    @Published var venueAddress = ""
    @Published var venueGooglePlaceID = ""
    @Published var venueCategory = "bar"

    @Published var userMessage: UserMessage?

    private let roleRequestsAPI: RoleRequestsAPIServiceProtocol

    init(
        userFlags: SettingsUserRoleFlags,
        roleRequestsAPI: RoleRequestsAPIServiceProtocol? = nil
    ) {
        self.userFlags = userFlags
        self.roleRequestsAPI = roleRequestsAPI ?? RoleRequestsAPIService()
    }

    var pendingEventRequest: RoleRequest? {
        requests.first(where: { $0.roleType == .eventCreator && $0.status == .pending })
    }

    var pendingVenueRequest: RoleRequest? {
        requests.first(where: { $0.roleType == .venueOwner && $0.status == .pending })
    }

    var rejectedEventRequest: RoleRequest? {
        requests.first(where: { $0.roleType == .eventCreator && $0.status == .rejected })
    }

    var rejectedVenueRequest: RoleRequest? {
        requests.first(where: { $0.roleType == .venueOwner && $0.status == .rejected })
    }

    var isEventCreator: Bool {
        userFlags.isEventCreator
    }

    var isVenueOwner: Bool {
        userFlags.isVenueOwner
    }

    func loadRequests() async {
        isLoading = true
        defer { isLoading = false }

        do {
            requests = try await roleRequestsAPI.list()
            userMessage = nil
        } catch {
            userMessage = UserMessage(
                kind: .error,
                text: (error as? LocalizedError)?.errorDescription ?? "Could not load role requests."
            )
        }
    }

    func handleToggle(_ role: RoleType) {
        activeRole = (activeRole == role) ? nil : role
    }

    func submit(onRoleGranted: (RoleType) -> Void) async {
        guard let role = activeRole else { return }

        if role == .eventCreator {
            guard !orgName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                userMessage = UserMessage(kind: .error, text: "Organization name is required.")
                return
            }
        }

        if role == .venueOwner {
            let trimmedVenueName = venueName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedVenueAddress = venueAddress.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedVenueName.isEmpty, !trimmedVenueAddress.isEmpty else {
                userMessage = UserMessage(kind: .error, text: "Venue name and address are required.")
                return
            }
        }

        isSaving = true
        defer { isSaving = false }

        let payload = payloadForActiveRole(role)

        do {
            let created = try await roleRequestsAPI.create(payload)
            requests = [created] + requests
            activeRole = nil
            userMessage = UserMessage(kind: .success, text: "Application submitted successfully.")

            if created.status == .approved {
                markRoleGranted(created.roleType)
                onRoleGranted(created.roleType)
            }
        } catch {
            userMessage = UserMessage(
                kind: .error,
                text: (error as? LocalizedError)?.errorDescription ?? "Could not submit application."
            )
        }
    }

    private func payloadForActiveRole(_ role: RoleType) -> CreateRoleRequestDTO {
        switch role {
        case .eventCreator:
            return CreateRoleRequestDTO(
                roleType: .eventCreator,
                organizationName: orgName.trimmingCharacters(in: .whitespacesAndNewlines),
                organizationDescription: orgDescription.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                venueName: nil,
                venueGooglePlaceID: nil,
                venueAddress: nil,
                venueCategory: nil
            )

        case .venueOwner:
            return CreateRoleRequestDTO(
                roleType: .venueOwner,
                organizationName: nil,
                organizationDescription: nil,
                venueName: venueName.trimmingCharacters(in: .whitespacesAndNewlines),
                venueGooglePlaceID: venueGooglePlaceID.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                venueAddress: venueAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                venueCategory: venueCategory
            )
        }
    }

    private func markRoleGranted(_ roleType: RoleType) {
        switch roleType {
        case .eventCreator:
            userFlags.isEventCreator = true
        case .venueOwner:
            userFlags.isVenueOwner = true
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
