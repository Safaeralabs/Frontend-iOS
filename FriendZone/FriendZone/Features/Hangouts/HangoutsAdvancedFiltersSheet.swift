import SwiftUI

struct HangoutsAdvancedFiltersSheet: View {
    @Binding var filters: HangoutsAdvancedFilters
    let onClose: () -> Void
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: FriendZoneTheme.Spacing.sm) {
                    distanceCard
                    vibeCard
                    optionsCard
                }
                .padding(FriendZoneTheme.Spacing.md)
            }
            .background(FriendZoneTheme.Colors.background)
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        onReset()
                        FriendZoneHaptics.selection()
                    }
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onClose()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
                }
            }
        }
    }

    private var distanceCard: some View {
        card(title: "Distance") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Max distance")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Spacer()
                    Text("\(String(format: "%.1f", filters.maxDistanceKm)) km")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                }

                Slider(value: $filters.maxDistanceKm, in: 1 ... 10, step: 0.5) { isEditing in
                    if !isEditing {
                        FriendZoneHaptics.selection()
                    }
                }
                .tint(FriendZoneTheme.Colors.primary)
            }
        }
    }

    private var vibeCard: some View {
        card(title: "Vibe") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(HangoutVibe.allCases, id: \.rawValue) { vibe in
                    let isOn = filters.selectedVibes.contains(vibe)
                    Button {
                        if isOn {
                            filters.selectedVibes.remove(vibe)
                        } else {
                            filters.selectedVibes.insert(vibe)
                        }
                        FriendZoneHaptics.selection()
                    } label: {
                        Text(vibe.title)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(isOn ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(isOn ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surfaceMuted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var optionsCard: some View {
        card(title: "Options") {
            VStack(spacing: 12) {
                Toggle(isOn: $filters.openSpotsOnly) {
                    Text("Only show with open spots")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .tint(FriendZoneTheme.Colors.primary)

                Toggle(isOn: $filters.freeOnly) {
                    Text("Free only")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .tint(FriendZoneTheme.Colors.primary)
            }
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            content()
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }
}

#Preview {
    HangoutsAdvancedFiltersSheet(
        filters: .constant(.default),
        onClose: {},
        onReset: {}
    )
}
