import SwiftUI

struct WebScreen: View {
    let tab: AppTab
    @State private var reloadKey = UUID()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FriendZoneWebView(path: tab.path, reloadKey: reloadKey)
                .background(FriendZoneTheme.background)
                .ignoresSafeArea(edges: .bottom)

            Button {
                reloadKey = UUID()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(FriendZoneTheme.primary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }
}
