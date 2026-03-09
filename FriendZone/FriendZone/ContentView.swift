//
//  ContentView.swift
//  FriendZone
//
//  Created by Safaera Labs on 05.03.26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var session = AppSessionStore.shared
    @State private var isShowingLaunchSplash = true
    @State private var hasScheduledSplashDismiss = false

    var body: some View {
        ZStack {
            rootContent

            if isShowingLaunchSplash {
                FriendZoneLaunchSplashView()
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .zIndex(10)
            }
        }
        .environmentObject(session)
        .onAppear {
            scheduleSplashDismiss()
            Task {
                await session.bootstrapIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if session.isHydrating {
            Color.clear
        } else if !session.isAuthenticated {
            AuthFlowView()
        } else if !session.hasCompletedOnboarding {
            OnboardingFlowView()
        } else {
            RootTabView()
        }
    }

    private func scheduleSplashDismiss() {
        guard !hasScheduledSplashDismiss else { return }
        hasScheduledSplashDismiss = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.12) {
            withAnimation(.easeOut(duration: 0.26)) {
                isShowingLaunchSplash = false
            }
        }
    }
}

private struct FriendZoneLaunchSplashView: View {
    @State private var isSceneRevealed = false
    @State private var isPrimaryOrbitSpinning = false
    @State private var isSecondaryOrbitSpinning = false
    @State private var isLogoPulsing = false
    @State private var isTextVisible = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#F7FAFF"), Color(hex: "#EEF3FF"), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(FriendZoneTheme.Colors.primary.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 34)
                .offset(x: -120, y: isSceneRevealed ? -230 : -205)
                .opacity(isSceneRevealed ? 1 : 0.5)

            Circle()
                .fill(FriendZoneTheme.Colors.primaryAccent.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .offset(x: 130, y: isSceneRevealed ? 220 : 245)
                .opacity(isSceneRevealed ? 1 : 0.5)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .trim(from: 0.02, to: 0.92)
                        .stroke(
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary.opacity(0.90), FriendZoneTheme.Colors.primaryAccent.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 108, height: 108)
                        .rotationEffect(.degrees(isPrimaryOrbitSpinning ? 360 : 0))

                    Circle()
                        .trim(from: 0.12, to: 0.66)
                        .stroke(
                            Color(hex: "#8B5CF6").opacity(0.35),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(isSecondaryOrbitSpinning ? -360 : 0))

                    FriendZoneLogoMark(size: 56, cornerRadius: 16)
                        .scaleEffect((isSceneRevealed ? 1.0 : 0.66) * (isLogoPulsing ? 1.03 : 0.97))
                        .rotationEffect(.degrees(isSceneRevealed ? 0 : -14))
                        .opacity(isSceneRevealed ? 1 : 0)
                        .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.24), radius: 16, x: 0, y: 8)
                }

                VStack(spacing: 6) {
                    Text("FriendZone")
                        .font(FriendZoneTheme.Typography.displaySerif(30, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .opacity(isTextVisible ? 1 : 0)
                        .offset(y: isTextVisible ? 0 : 6)
                        .blur(radius: isTextVisible ? 0 : 4)

                    TimelineView(.animation(minimumInterval: 0.32, paused: !isTextVisible)) { context in
                        let dots = Int(context.date.timeIntervalSinceReferenceDate * 3).quotientAndRemainder(dividingBy: 4).remainder
                        Text("Loading your city vibes" + String(repeating: ".", count: dots))
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .opacity(isTextVisible ? 1 : 0)
                            .offset(y: isTextVisible ? 0 : 6)
                    }
                }
            }
        }
        .scaleEffect(isSceneRevealed ? 1 : 1.04)
        .opacity(isSceneRevealed ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.82, blendDuration: 0.2)) {
                isSceneRevealed = true
            }
            withAnimation(.linear(duration: 1.55).repeatForever(autoreverses: false)) {
                isPrimaryOrbitSpinning = true
            }
            withAnimation(.linear(duration: 2.05).repeatForever(autoreverses: false)) {
                isSecondaryOrbitSpinning = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isLogoPulsing = true
            }
            withAnimation(.easeOut(duration: 0.34).delay(0.15)) {
                isTextVisible = true
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
