import SwiftUI

struct CreatorProfileDraft: Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var bio: String
    var instagram: String
    var website: String
    var city: String

    init(
        id: UUID = .init(),
        displayName: String,
        bio: String,
        instagram: String,
        website: String,
        city: String
    ) {
        self.id = id
        self.displayName = displayName
        self.bio = bio
        self.instagram = instagram
        self.website = website
        self.city = city
    }

    static let sample = CreatorProfileDraft(
        displayName: "FriendZone Labs",
        bio: "Creating curated social experiences across your city.",
        instagram: "friendzone",
        website: "https://friendzone.app",
        city: "Munich"
    )

    var initial: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0) } ?? "F"
    }
}

struct PublicProfileView: View {
    let profile: CreatorProfileDraft
    let leadingText: String
    let highlightText: String
    let subtitle: String?
    var onClose: (() -> Void)? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                FriendZoneModuleHeader(
                    leadingText: leadingText,
                    highlightText: highlightText,
                    subtitle: subtitle
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                publicProfileCard
                    .padding(.horizontal, 16)

                profileBioSection
                    .padding(.horizontal, 16)

                profileLinks
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("\(highlightText.capitalized)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    onClose?()
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private var publicProfileCard: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#0F172A"), Color(hex: "#0E7490")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)

                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text(profile.initial)
                            .font(FriendZoneTheme.Typography.system(20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(profile.city)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                Text(profile.bio)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    profileChip(icon: "📍", label: profile.city)
                    profileChip(icon: "🧭", label: "Collaborations welcome")
                }
            }
        }
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
        }
    }

    private var profileBioSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bio")
                .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            Text(profile.bio)
                .font(FriendZoneTheme.Typography.system(14, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
        }
    }

    private var profileLinks: some View {
        VStack(spacing: 10) {
            if !profile.instagram.isEmpty {
                profileLinkRow(icon: "at", title: "Instagram", value: "@\(profile.instagram)")
            }
            if let url = URL(string: profile.website), !profile.website.isEmpty {
                profileLinkRow(icon: "link", title: "Website", value: profile.website, url: url)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
        }
    }

    private func profileChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(icon)
            Text(label)
                .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
        }
        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(Capsule())
    }

    private func profileLinkRow(icon: String, title: String, value: String, url: URL? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 32, height: 32)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                if let url = url {
                    Link(value, destination: url)
                        .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                } else {
                    Text(value)
                        .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }
            }
            Spacer()
        }
    }
}
