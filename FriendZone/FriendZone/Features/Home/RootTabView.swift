import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .hangouts

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    WebScreen(tab: tab)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.sfSymbol)
                }
                .tag(tab)
            }
        }
        .tint(FriendZoneTheme.primary)
    }
}

#Preview {
    RootTabView()
}
