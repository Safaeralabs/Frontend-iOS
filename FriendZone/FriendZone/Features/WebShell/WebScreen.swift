import SwiftUI

struct WebScreen: View {
    let path: String
    @State private var reloadKey = UUID()

    init(tab: AppTab) {
        self.path = tab.path
    }

    init(path: String) {
        self.path = path
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FriendZoneWebView(path: path, reloadKey: reloadKey)
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
                    .friendZoneShadow(FriendZoneTheme.Shadows.md)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }
}
