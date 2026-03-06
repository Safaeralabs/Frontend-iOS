import SwiftUI

struct FriendZoneTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
                )
                .friendZoneShadow(FriendZoneTheme.Shadows.md)
        )
    }

    private func tabButton(for tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(FriendZoneTheme.Motion.easeOutBack) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                iconView(for: tab, isSelected: isSelected)
                Text(tab.title)
                    .font(
                        FriendZoneTheme.Typography.system(
                            tab.isMain ? 10 : 9,
                            weight: isSelected ? .semibold : .medium
                        )
                    )
                    .foregroundStyle(isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, tab.isMain ? 3 : 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }

    @ViewBuilder
    private func iconView(for tab: AppTab, isSelected: Bool) -> some View {
        if tab.isMain {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("FZ")
                    .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                    .foregroundStyle(FriendZoneTheme.Colors.textInverse)
            }
            .frame(width: 42, height: 42)
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.30), radius: 6, x: 0, y: 2)
        } else {
            ZStack {
                Circle()
                    .fill(isSelected ? FriendZoneTheme.Colors.primarySoft : .clear)
                Image(systemName: tab.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textTertiary)
            }
            .frame(width: 34, height: 34)
            .scaleEffect(isSelected ? 1.04 : 1.0)
        }
    }
}

#Preview {
    ZStack {
        FriendZoneTheme.Colors.background.ignoresSafeArea()
        VStack {
            Spacer()
            FriendZoneTabBar(selectedTab: .constant(.hangouts))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }
}
