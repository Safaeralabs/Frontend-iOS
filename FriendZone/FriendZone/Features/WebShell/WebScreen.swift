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
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                FriendZoneWebView(path: path, reloadKey: reloadKey)
                    .background(FriendZoneTheme.background)
                    .ignoresSafeArea()

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
                .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 10))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FriendZoneTheme.background)
            .ignoresSafeArea(.container, edges: [.top, .bottom])
        }
    }
}
