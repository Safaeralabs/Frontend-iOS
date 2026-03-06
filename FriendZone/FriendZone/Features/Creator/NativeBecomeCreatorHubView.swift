import SwiftUI

struct NativeBecomeCreatorHubView: View {
    private struct VenueCategoryOption: Identifiable {
        let value: String
        let label: String

        var id: String { value }
    }

    private static let venueCategories: [VenueCategoryOption] = [
        .init(value: "bar", label: "Bar"),
        .init(value: "cafe", label: "Cafe"),
        .init(value: "restaurant", label: "Restaurant"),
        .init(value: "club", label: "Club / Nightclub"),
        .init(value: "coworking", label: "Coworking Space"),
        .init(value: "park", label: "Park / Outdoor"),
        .init(value: "gym", label: "Gym / Sports"),
        .init(value: "gallery", label: "Gallery / Museum"),
        .init(value: "theater", label: "Theater / Cinema"),
        .init(value: "other", label: "Other")
    ]

    @StateObject private var viewModel: BecomeCreatorViewModel

    private let onRoleGranted: (RoleType) -> Void

    init(userFlags: SettingsUserRoleFlags, onRoleGranted: @escaping (RoleType) -> Void) {
        _viewModel = StateObject(wrappedValue: BecomeCreatorViewModel(userFlags: userFlags))
        self.onRoleGranted = onRoleGranted
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                introCard

                if let message = viewModel.userMessage {
                    messageCard(message)
                }

                roleCard(
                    role: .eventCreator,
                    isActive: viewModel.isEventCreator,
                    pendingRequest: viewModel.pendingEventRequest,
                    rejectedRequest: viewModel.rejectedEventRequest,
                    title: "Event Creator",
                    subtitle: "Create and host public events in your city",
                    icon: "ticket.fill",
                    iconGradient: [Color(hex: "#667EEA"), Color(hex: "#764BA2")],
                    form: {
                        eventCreatorForm
                    }
                )

                roleCard(
                    role: .venueOwner,
                    isActive: viewModel.isVenueOwner,
                    pendingRequest: viewModel.pendingVenueRequest,
                    rejectedRequest: viewModel.rejectedVenueRequest,
                    title: "Venue Owner",
                    subtitle: "Register your bar, cafe, or venue on FriendZone",
                    icon: "building.2.fill",
                    iconGradient: [Color(hex: "#F7971E"), Color(hex: "#FFD200")],
                    form: {
                        venueOwnerForm
                    }
                )

                if viewModel.activeRole != nil {
                    Button {
                        Task {
                            await viewModel.submit(onRoleGranted: onRoleGranted)
                        }
                    } label: {
                        Text(viewModel.isSaving ? "Submitting..." : "Submit application")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaving)
                    .opacity(viewModel.isSaving ? 0.7 : 1)
                }

                howItWorksCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Creator Program")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRequests()
        }
    }

    private var introCard: some View {
        VStack(spacing: 10) {
            Text("✨")
                .font(.system(size: 38))

            Text("Become a creator")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text("Host public events or register your venue on FriendZone. Apply for the role that fits you best.")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 14)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private func messageCard(_ message: BecomeCreatorViewModel.UserMessage) -> some View {
        let isError = message.kind == .error

        return Text(message.text)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            .foregroundColor(isError ? FriendZoneTokens.Colors.errorStrong : FriendZoneTokens.Colors.successStrong)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background((isError ? FriendZoneTheme.Colors.error : FriendZoneTheme.Colors.success).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke((isError ? FriendZoneTheme.Colors.error : FriendZoneTheme.Colors.success).opacity(0.22), lineWidth: 1)
            }
    }

    private func roleCard<Form: View>(
        role: RoleType,
        isActive: Bool,
        pendingRequest: RoleRequest?,
        rejectedRequest: RoleRequest?,
        title: String,
        subtitle: String,
        icon: String,
        iconGradient: [Color],
        @ViewBuilder form: () -> Form
    ) -> some View {
        let isOpen = viewModel.activeRole == role
        let isPending = pendingRequest != nil
        let isBlocked = isActive || isPending

        return VStack(spacing: 0) {
            Button {
                viewModel.handleToggle(role)
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                        Text(subtitle)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    statusBadge(
                        isActive: isActive,
                        isPending: isPending,
                        isRejected: rejectedRequest != nil,
                        isOpen: isOpen
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .disabled(isBlocked)

            if let rejectionReason = rejectedRequest?.rejectionReason, !rejectionReason.isEmpty {
                Text("Reason: \(rejectionReason)")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTokens.Colors.errorStrong)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .padding(.top, 2)
            }

            if isOpen && !isBlocked {
                Divider()
                    .padding(.horizontal, 14)

                form()
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isOpen ? FriendZoneTheme.Colors.primary.opacity(0.32) : FriendZoneTheme.Colors.borderSubtle,
                    lineWidth: isOpen ? 2 : 1
                )
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        .animation(FriendZoneTheme.Motion.easeInOutCirc, value: isOpen)
    }

    @ViewBuilder
    private func statusBadge(isActive: Bool, isPending: Bool, isRejected: Bool, isOpen: Bool) -> some View {
        if isActive {
            badge("Active", fg: FriendZoneTokens.Colors.successStrong, bg: FriendZoneTheme.Colors.success.opacity(0.14))
        } else if isPending {
            badge("Pending", fg: FriendZoneTokens.Colors.warningStrong, bg: FriendZoneTheme.Colors.warning.opacity(0.16))
        } else if isRejected {
            badge("Rejected", fg: FriendZoneTokens.Colors.errorStrong, bg: FriendZoneTheme.Colors.error.opacity(0.12))
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
        }
    }

    private func badge(_ title: String, fg: Color, bg: Color) -> some View {
        Text(title)
            .font(FriendZoneTheme.Typography.system(12, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bg)
            .clipShape(Capsule())
    }

    private var eventCreatorForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledField(title: "Organization / Community name *") {
                TextField("e.g. Munich Tech Events", text: $viewModel.orgName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(FriendZoneTheme.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
                    }
            }

            labeledField(title: "What kind of events do you plan to create?") {
                VStack(alignment: .trailing, spacing: 6) {
                    TextEditor(text: $viewModel.orgDescription)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 96, maxHeight: 130)
                        .padding(10)
                        .background(FriendZoneTheme.Colors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
                        }

                    Text("\(viewModel.orgDescription.count)/500")
                        .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }
            }
        }
        .onChange(of: viewModel.orgName) { value in
            if value.count > 120 {
                viewModel.orgName = String(value.prefix(120))
            }
        }
        .onChange(of: viewModel.orgDescription) { value in
            if value.count > 500 {
                viewModel.orgDescription = String(value.prefix(500))
            }
        }
    }

    private var venueOwnerForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledField(title: "Venue name *") {
                TextField("Venue name", text: $viewModel.venueName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(FriendZoneTheme.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
                    }
            }

            labeledField(title: "Venue address *") {
                TextField("Full address", text: $viewModel.venueAddress)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(FriendZoneTheme.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
                    }
            }

            labeledField(title: "Category") {
                Picker("Category", selection: $viewModel.venueCategory) {
                    ForEach(Self.venueCategories) { category in
                        Text(category.label).tag(category.value)
                    }
                }
                .pickerStyle(.menu)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(FriendZoneTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
                }
            }
        }
        .onChange(of: viewModel.venueName) { value in
            if value.count > 120 {
                viewModel.venueName = String(value.prefix(120))
            }
        }
        .onChange(of: viewModel.venueAddress) { value in
            if value.count > 300 {
                viewModel.venueAddress = String(value.prefix(300))
            }
        }
    }

    private func labeledField<Field: View>(title: String, @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .textCase(.uppercase)

            field()
        }
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            stepRow(number: "1", text: "Fill in the form and submit")
            stepRow(number: "2", text: "Our team reviews your request (1-3 days)")
            stepRow(number: "3", text: "Once approved, your role is unlocked")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                .frame(width: 26, height: 26)
                .background(
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            Text(text)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
    }
}

#if DEBUG
struct NativeBecomeCreatorHubView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NativeBecomeCreatorHubView(userFlags: .empty) { _ in }
        }
    }
}
#endif
