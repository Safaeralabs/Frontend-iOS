import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 1
    case basicInfo
    case gender
    case location
    case languages
    case interests
    case vibes
    case availability
    case hangoutStyle
    case ready

    var isProgressVisible: Bool {
        rawValue > 1 && rawValue < 10
    }
}

private enum LanguageLevel: String, CaseIterable, Identifiable {
    case native
    case fluent
    case conversational
    case basic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .native: return "Native"
        case .fluent: return "Fluent"
        case .conversational: return "Conversational"
        case .basic: return "Basic"
        }
    }

    var emoji: String {
        switch self {
        case .native: return "⭐"
        case .fluent: return "💬"
        case .conversational: return "🗣️"
        case .basic: return "📖"
        }
    }
}

private enum GroupSize: String, CaseIterable, Identifiable {
    case solo
    case small
    case medium
    case large
    case any

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solo: return "One-on-One"
        case .small: return "Small Groups"
        case .medium: return "Medium Groups"
        case .large: return "Large Groups"
        case .any: return "Any Size"
        }
    }

    var emoji: String {
        switch self {
        case .solo: return "👥"
        case .small: return "👨‍👩‍👦"
        case .medium: return "👨‍👩‍👧‍👦"
        case .large: return "🎉"
        case .any: return "🌟"
        }
    }

    var description: String {
        switch self {
        case .solo: return "Prefer intimate 1:1 hangouts"
        case .small: return "3-5 people, close-knit vibes"
        case .medium: return "6-10 people, social energy"
        case .large: return "10+ people, party atmosphere"
        case .any: return "Flexible with group size"
        }
    }

    var summary: String {
        switch self {
        case .solo: return "Solo (1-on-1)"
        case .small: return "Small (2-4)"
        case .medium: return "Medium (5-10)"
        case .large: return "Large (10+)"
        case .any: return "Any size"
        }
    }
}

private struct OnboardingLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    let flag: String
    var level: LanguageLevel

    var id: String { code }
}

private struct SelectableOption: Identifiable, Hashable {
    let value: String
    let title: String
    let emoji: String
    let subtitle: String

    var id: String { value }
}

private struct InterestCategory: Identifiable {
    let title: String
    let options: [SelectableOption]

    var id: String { title }
}

private struct OnboardingProfileData {
    var name: String = ""
    var avatar: String = ""
    var gender: String = ""
    var city: String = ""
    var cityPlaceId: String = ""
    var languages: [OnboardingLanguage] = []
    var interests: [String] = []
    var vibes: [String] = []
    var availability: [String] = []
    var groupSize: GroupSize = .small
    var activityTypes: [String] = []
}

struct OnboardingFlowView: View {
    @AppStorage("fz.auth.hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var currentStep: OnboardingStep = .welcome
    @State private var data = OnboardingProfileData()
    @State private var isCompleting = false
    @State private var completionError = ""

    private let totalSteps = OnboardingStep.allCases.count

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                onboardingBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if currentStep.isProgressVisible {
                        progressBar(topInset: proxy.safeAreaInsets.top)
                    }

                    currentStepView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(FriendZoneTheme.Motion.easeOutExpo, value: currentStep)
            .ignoresSafeArea(.container, edges: [.bottom])
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            FriendZoneTheme.Colors.background

            Circle()
                .fill(FriendZoneTheme.Colors.primary.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 44)
                .offset(x: -150, y: -300)

            Circle()
                .fill(FriendZoneTheme.Colors.primaryAccent.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 42)
                .offset(x: 160, y: 320)
        }
    }

    private func progressBar(topInset: CGFloat) -> some View {
        HStack(spacing: 14) {
            Button {
                prevStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(FriendZoneTheme.Colors.surface)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            GeometryReader { barProxy in
                let progress = CGFloat(currentStep.rawValue - 1) / CGFloat(totalSteps - 2)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FriendZoneTheme.Colors.borderSubtle)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barProxy.size.width * progress)
                }
            }
            .frame(height: 4)

            Text("\(currentStep.rawValue - 1)/\(totalSteps - 2)")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, topInset + 14)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .welcome:
            OnboardingWelcomeStep(onContinue: nextStep)
        case .basicInfo:
            OnboardingBasicInfoStep(name: $data.name, avatar: $data.avatar, onContinue: nextStep)
        case .gender:
            OnboardingGenderStep(gender: $data.gender, onContinue: nextStep)
        case .location:
            OnboardingLocationStep(city: $data.city, cityPlaceId: $data.cityPlaceId, onContinue: nextStep)
        case .languages:
            OnboardingLanguagesStep(languages: $data.languages, onContinue: nextStep)
        case .interests:
            OnboardingInterestsStep(interests: $data.interests, onContinue: nextStep)
        case .vibes:
            OnboardingVibesStep(vibes: $data.vibes, onContinue: nextStep)
        case .availability:
            OnboardingAvailabilityStep(availability: $data.availability, onContinue: nextStep)
        case .hangoutStyle:
            OnboardingHangoutStyleStep(
                groupSize: $data.groupSize,
                activityTypes: $data.activityTypes,
                onContinue: nextStep
            )
        case .ready:
            OnboardingReadyStep(
                data: data,
                isCompleting: isCompleting,
                errorMessage: completionError,
                onComplete: completeOnboarding
            )
        }
    }

    private func nextStep() {
        guard currentStep.rawValue < totalSteps else { return }
        if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    private func prevStep() {
        guard currentStep.rawValue > 1 else { return }
        if let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            currentStep = previous
        }
    }

    private func completeOnboarding() {
        guard !isCompleting else { return }
        completionError = ""
        isCompleting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            isCompleting = false
            hasCompletedOnboarding = true
        }
    }
}

private struct OnboardingStepShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }
}

private struct OnboardingWelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    FriendZoneBrandPill()

                    Text("Meet people,\nmake memories")
                        .font(FriendZoneTheme.Typography.displaySerif(36, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1.5)

                    Text("The social app that helps you connect with people nearby and create real friendships.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.top, 10)

                VStack(spacing: 14) {
                    OnboardingFeatureRow(
                        emoji: "🎯",
                        title: "Spontaneous Hangouts",
                        description: "Join activities happening right now"
                    )
                    OnboardingFeatureRow(
                        emoji: "⚡",
                        title: "Share Your Vibes",
                        description: "Let friends know what you are up for"
                    )
                    OnboardingFeatureRow(
                        emoji: "🗺️",
                        title: "Explore Nearby",
                        description: "Discover events and people around you"
                    )
                }

                VStack(spacing: 10) {
                    OnboardingPrimaryButton(title: "Get Started", disabled: false, action: onContinue)
                    Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 6)
            }
        }
    }
}

private struct OnboardingBasicInfoStep: View {
    @Binding var name: String
    @Binding var avatar: String
    let onContinue: () -> Void

    private var initials: String {
        let letters = name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
        return String(letters).uppercased()
    }

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 24) {
                OnboardingHeader(
                    title: "What's your name?",
                    subtitle: "This is how others will see you"
                )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 102, height: 102)
                    .overlay {
                        Text(initials.isEmpty ? "?" : initials)
                            .font(FriendZoneTheme.Typography.system(34, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .friendZoneShadow(FriendZoneTheme.Shadows.md)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Enter your full name", text: $name)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .medium))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                        .onChange(of: name) { newValue in
                            if newValue.count > 50 {
                                name = String(newValue.prefix(50))
                            }
                        }

                    Text("\(name.count)/50")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                OnboardingPrimaryButton(
                    title: "Continue",
                    disabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: {
                        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleaned.isEmpty else { return }
                        name = cleaned
                        avatar = initials
                        onContinue()
                    }
                )
            }
        }
    }
}

private struct OnboardingGenderStep: View {
    @Binding var gender: String
    let onContinue: () -> Void

    private let options: [SelectableOption] = [
        .init(value: "male", title: "Male", emoji: "♂", subtitle: "Personalized recommendations"),
        .init(value: "female", title: "Female", emoji: "♀", subtitle: "Personalized recommendations"),
        .init(value: "non_binary", title: "Non-binary", emoji: "⚧", subtitle: "Personalized recommendations")
    ]

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 24) {
                OnboardingHeader(
                    title: "How do you identify?",
                    subtitle: "This helps us personalise your experience"
                )

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        let isSelected = gender == option.value

                        Button {
                            gender = option.value
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                onContinue()
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(option.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(FriendZoneTheme.Typography.system(17, weight: .semibold))
                                    Text(option.subtitle)
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                        .opacity(0.86)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                }
                            }
                            .foregroundColor(isSelected ? .white : FriendZoneTheme.Colors.textPrimary)
                            .padding(.horizontal, 18)
                            .frame(height: 74)
                            .background(
                                Group {
                                    if isSelected {
                                        LinearGradient(
                                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    } else {
                                        Color.white.opacity(0.72)
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? Color.clear : FriendZoneTheme.Colors.primary.opacity(0.22), lineWidth: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Prefer not to say") {
                    gender = ""
                    onContinue()
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .buttonStyle(.plain)
            }
        }
    }
}

private struct OnboardingLocationStep: View {
    @Binding var city: String
    @Binding var cityPlaceId: String
    let onContinue: () -> Void

    private let suggestions = ["Munich", "Berlin", "Hamburg", "Frankfurt", "Cologne", "Stuttgart"]

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 24) {
                OnboardingHeader(
                    title: "Where are you based?",
                    subtitle: "Help us show you relevant hangouts nearby"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("City")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    TextField("Start typing your city...", text: $city)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .medium))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                        .onChange(of: city) { newValue in
                            cityPlaceId = slug(from: newValue)
                        }

                    HStack(spacing: 8) {
                        ForEach(suggestions.filter { !city.lowercased().contains($0.lowercased()) }.prefix(3), id: \.self) { item in
                            Button(item) {
                                city = item
                                cityPlaceId = slug(from: item)
                            }
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(FriendZoneTheme.Colors.primarySoft)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                        }
                    }

                    if !city.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(FriendZoneTokens.Colors.successStrong)
                            Text(city)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTokens.Colors.successStrong)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(FriendZoneTheme.Colors.success.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.success.opacity(0.35), lineWidth: 1)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Text("💡")
                    Text("Type your city name and select it. This helps us match you with nearby hangouts.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .lineSpacing(2)
                }
                .padding(14)
                .background(FriendZoneTheme.Colors.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }

                OnboardingPrimaryButton(
                    title: "Continue",
                    disabled: city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: {
                        city = city.trimmingCharacters(in: .whitespacesAndNewlines)
                        cityPlaceId = slug(from: city)
                        onContinue()
                    }
                )
            }
        }
    }

    private func slug(from value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }
}

private struct OnboardingLanguagesStep: View {
    @Binding var languages: [OnboardingLanguage]
    let onContinue: () -> Void

    @State private var selectedLanguageCode = ""
    @State private var selectedLevel: LanguageLevel?

    private let availableLanguages: [OnboardingLanguage] = [
        .init(code: "en", name: "English", flag: "🇺🇸", level: .fluent),
        .init(code: "es", name: "Spanish", flag: "🇪🇸", level: .fluent),
        .init(code: "fr", name: "French", flag: "🇫🇷", level: .fluent),
        .init(code: "de", name: "German", flag: "🇩🇪", level: .fluent),
        .init(code: "it", name: "Italian", flag: "🇮🇹", level: .fluent),
        .init(code: "pt", name: "Portuguese", flag: "🇵🇹", level: .fluent),
        .init(code: "zh", name: "Mandarin", flag: "🇨🇳", level: .fluent),
        .init(code: "ja", name: "Japanese", flag: "🇯🇵", level: .fluent),
        .init(code: "ko", name: "Korean", flag: "🇰🇷", level: .fluent),
        .init(code: "ar", name: "Arabic", flag: "🇸🇦", level: .fluent),
        .init(code: "hi", name: "Hindi", flag: "🇮🇳", level: .fluent),
        .init(code: "ru", name: "Russian", flag: "🇷🇺", level: .fluent)
    ]

    private var selectedLanguageName: String {
        availableLanguages.first(where: { $0.code == selectedLanguageCode })?.name ?? "Choose a language"
    }

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 22) {
                OnboardingHeader(
                    title: "What languages do you speak?",
                    subtitle: "Connect with people who speak your language"
                )

                if !languages.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(languages) { item in
                            HStack(spacing: 10) {
                                Text(item.flag)
                                    .font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                    Text("\(item.level.emoji) \(item.level.label)")
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                }
                                Spacer()
                                Button {
                                    languages.removeAll { $0.code == item.code }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(FriendZoneTheme.Colors.error)
                                        .frame(width: 26, height: 26)
                                        .background(FriendZoneTheme.Colors.error.opacity(0.10))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 58)
                            .background(FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    Menu {
                        ForEach(availableLanguages.filter { candidate in
                            !languages.contains(where: { $0.code == candidate.code })
                        }) { language in
                            Button("\(language.flag) \(language.name)") {
                                selectedLanguageCode = language.code
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedLanguageCode.isEmpty ? "Choose a language" : selectedLanguageName)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(selectedLanguageCode.isEmpty ? FriendZoneTheme.Colors.textSecondary : FriendZoneTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                    }

                    if !selectedLanguageCode.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            ForEach(LanguageLevel.allCases) { level in
                                let selected = selectedLevel == level
                                Button {
                                    selectedLevel = level
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(level.emoji)
                                        Text(level.label)
                                    }
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                                    .foregroundColor(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(selected ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    OnboardingPrimaryButton(
                        title: "Add Language",
                        disabled: selectedLanguageCode.isEmpty || selectedLevel == nil,
                        action: addLanguage
                    )
                }
                .padding(14)
                .background(Color.black.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 10) {
                    OnboardingPrimaryButton(
                        title: "Continue",
                        disabled: languages.isEmpty,
                        action: onContinue
                    )

                    Button("Skip for now") {
                        onContinue()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func addLanguage() {
        guard let selectedLevel,
              let base = availableLanguages.first(where: { $0.code == selectedLanguageCode }),
              !languages.contains(where: { $0.code == selectedLanguageCode }) else {
            return
        }

        languages.append(.init(code: base.code, name: base.name, flag: base.flag, level: selectedLevel))
        selectedLanguageCode = ""
        self.selectedLevel = nil
    }
}

private struct OnboardingInterestsStep: View {
    @Binding var interests: [String]
    let onContinue: () -> Void

    private let categories: [InterestCategory] = [
        .init(title: "Food & Drinks", options: [
            .init(value: "coffee", title: "Coffee", emoji: "☕", subtitle: ""),
            .init(value: "brunch", title: "Brunch", emoji: "🥐", subtitle: ""),
            .init(value: "foodie", title: "Foodie", emoji: "🍜", subtitle: ""),
            .init(value: "cocktails", title: "Cocktails", emoji: "🍸", subtitle: ""),
            .init(value: "wine", title: "Wine", emoji: "🍷", subtitle: ""),
            .init(value: "cooking", title: "Cooking", emoji: "👨‍🍳", subtitle: "")
        ]),
        .init(title: "Active & Sports", options: [
            .init(value: "gym", title: "Gym", emoji: "💪", subtitle: ""),
            .init(value: "yoga", title: "Yoga", emoji: "🧘", subtitle: ""),
            .init(value: "running", title: "Running", emoji: "🏃", subtitle: ""),
            .init(value: "hiking", title: "Hiking", emoji: "🥾", subtitle: ""),
            .init(value: "cycling", title: "Cycling", emoji: "🚴", subtitle: ""),
            .init(value: "sports", title: "Sports", emoji: "⚽", subtitle: "")
        ]),
        .init(title: "Arts & Culture", options: [
            .init(value: "music", title: "Music", emoji: "🎵", subtitle: ""),
            .init(value: "concerts", title: "Concerts", emoji: "🎤", subtitle: ""),
            .init(value: "museums", title: "Museums", emoji: "🎨", subtitle: ""),
            .init(value: "theater", title: "Theater", emoji: "🎭", subtitle: ""),
            .init(value: "photography", title: "Photography", emoji: "📸", subtitle: ""),
            .init(value: "art", title: "Art", emoji: "🖼️", subtitle: "")
        ]),
        .init(title: "Entertainment", options: [
            .init(value: "movies", title: "Movies", emoji: "🎬", subtitle: ""),
            .init(value: "gaming", title: "Gaming", emoji: "🎮", subtitle: ""),
            .init(value: "board-games", title: "Board Games", emoji: "🎲", subtitle: ""),
            .init(value: "clubbing", title: "Clubbing", emoji: "💃", subtitle: ""),
            .init(value: "karaoke", title: "Karaoke", emoji: "🎤", subtitle: ""),
            .init(value: "comedy", title: "Comedy", emoji: "😂", subtitle: "")
        ]),
        .init(title: "Outdoors & Nature", options: [
            .init(value: "beach", title: "Beach", emoji: "🏖️", subtitle: ""),
            .init(value: "camping", title: "Camping", emoji: "🏕️", subtitle: ""),
            .init(value: "nature", title: "Nature", emoji: "🌲", subtitle: ""),
            .init(value: "animals", title: "Animals", emoji: "🐕", subtitle: ""),
            .init(value: "gardening", title: "Gardening", emoji: "🌱", subtitle: ""),
            .init(value: "adventure", title: "Adventure", emoji: "🗺️", subtitle: "")
        ]),
        .init(title: "Learning & Growth", options: [
            .init(value: "reading", title: "Reading", emoji: "📚", subtitle: ""),
            .init(value: "languages", title: "Languages", emoji: "🗣️", subtitle: ""),
            .init(value: "tech", title: "Tech", emoji: "💻", subtitle: ""),
            .init(value: "entrepreneurship", title: "Business", emoji: "💼", subtitle: ""),
            .init(value: "meditation", title: "Meditation", emoji: "🧘‍♀️", subtitle: ""),
            .init(value: "volunteering", title: "Volunteering", emoji: "🤝", subtitle: "")
        ])
    ]

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 20) {
                OnboardingHeader(
                    title: "What are you into?",
                    subtitle: "Pick at least 3 interests to help us match you with the right people"
                )

                HStack(spacing: 4) {
                    Text("\(interests.count)")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                    Text("/ 3 minimum")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Capsule())

                VStack(spacing: 18) {
                    ForEach(categories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.title.uppercased())
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                                ForEach(category.options) { option in
                                    let selected = interests.contains(option.value)
                                    Button {
                                        toggle(option.value)
                                    } label: {
                                        VStack(spacing: 8) {
                                            Text(option.emoji)
                                                .font(.system(size: 30))
                                            Text(option.title)
                                                .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 90)
                                        .background(selected ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle, lineWidth: selected ? 1.5 : 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                OnboardingPrimaryButton(
                    title: "Continue (\(interests.count) selected)",
                    disabled: interests.count < 3,
                    action: onContinue
                )
            }
        }
    }

    private func toggle(_ value: String) {
        if interests.contains(value) {
            interests.removeAll { $0 == value }
        } else {
            interests.append(value)
        }
    }
}

private struct OnboardingVibesStep: View {
    @Binding var vibes: [String]
    let onContinue: () -> Void

    private let options: [SelectableOption] = [
        .init(value: "chill", title: "Chill & Relaxed", emoji: "😌", subtitle: "Low-key hangouts"),
        .init(value: "social", title: "Social Butterfly", emoji: "🦋", subtitle: "Meet new people"),
        .init(value: "active", title: "Active & Energetic", emoji: "⚡", subtitle: "Always on the move"),
        .init(value: "party", title: "Party Animal", emoji: "🎉", subtitle: "Nightlife and fun"),
        .init(value: "foodie", title: "Foodie Explorer", emoji: "🍜", subtitle: "Food is life"),
        .init(value: "creative", title: "Creative Soul", emoji: "🎨", subtitle: "Art and culture"),
        .init(value: "intellectual", title: "Deep Thinker", emoji: "🧠", subtitle: "Meaningful chats"),
        .init(value: "adventurous", title: "Adventurer", emoji: "🗺️", subtitle: "Always exploring")
    ]

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 20) {
                OnboardingHeader(
                    title: "What's your vibe?",
                    subtitle: "Choose up to 3 that best describe your personality"
                )

                HStack(spacing: 4) {
                    Text("\(vibes.count)")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                    Text("/ 3 max")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Capsule())

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(options, id: \.id) { option in
                        let selected = vibes.contains(option.value)
                        let disabled = vibes.count >= 3 && !selected
                        Button {
                            guard !disabled else { return }
                            toggle(option.value)
                        } label: {
                            VStack(spacing: 8) {
                                Text(option.emoji)
                                    .font(.system(size: 34))
                                Text(option.title)
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                                    .multilineTextAlignment(.center)
                                Text(option.subtitle)
                                    .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .opacity(0.82)
                            }
                            .foregroundColor(selected ? .white : FriendZoneTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .background {
                                if selected {
                                    LinearGradient(
                                        colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    Color.white.opacity(0.78)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(selected ? Color.clear : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(disabled ? 0.45 : 1)
                    }
                }

                OnboardingPrimaryButton(
                    title: "Continue",
                    disabled: vibes.isEmpty,
                    action: onContinue
                )
            }
        }
    }

    private func toggle(_ value: String) {
        if vibes.contains(value) {
            vibes.removeAll { $0 == value }
        } else if vibes.count < 3 {
            vibes.append(value)
        }
    }
}

private struct OnboardingAvailabilityStep: View {
    @Binding var availability: [String]
    let onContinue: () -> Void

    private let options: [SelectableOption] = [
        .init(value: "mornings", title: "Mornings", emoji: "🌅", subtitle: "6AM - 12PM"),
        .init(value: "afternoons", title: "Afternoons", emoji: "☀️", subtitle: "12PM - 6PM"),
        .init(value: "evenings", title: "Evenings", emoji: "🌆", subtitle: "6PM - 10PM"),
        .init(value: "nights", title: "Late Nights", emoji: "🌙", subtitle: "10PM - 2AM"),
        .init(value: "weekdays", title: "Weekdays", emoji: "📅", subtitle: "Mon - Fri"),
        .init(value: "weekends", title: "Weekends", emoji: "🎉", subtitle: "Sat - Sun"),
        .init(value: "flexible", title: "Very Flexible", emoji: "🤸", subtitle: "Anytime"),
        .init(value: "spontaneous", title: "Spontaneous", emoji: "⚡", subtitle: "Last minute")
    ]

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 22) {
                OnboardingHeader(
                    title: "When are you free?",
                    subtitle: "Let people know when you're usually available to hang out"
                )

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(options) { option in
                        let selected = availability.contains(option.value)
                        Button {
                            toggle(option.value)
                        } label: {
                            VStack(spacing: 8) {
                                Text(option.emoji)
                                    .font(.system(size: 34))
                                Text(option.title)
                                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                Text(option.subtitle)
                                    .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            }
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(selected ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle, lineWidth: selected ? 1.5 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                OnboardingPrimaryButton(
                    title: "Continue",
                    disabled: availability.isEmpty,
                    action: onContinue
                )
            }
        }
    }

    private func toggle(_ value: String) {
        if availability.contains(value) {
            availability.removeAll { $0 == value }
        } else {
            availability.append(value)
        }
    }
}

private struct OnboardingHangoutStyleStep: View {
    @Binding var groupSize: GroupSize
    @Binding var activityTypes: [String]
    let onContinue: () -> Void

    private let activityOptions: [SelectableOption] = [
        .init(value: "structured", title: "Structured", emoji: "📋", subtitle: "Planned activities"),
        .init(value: "spontaneous", title: "Spontaneous", emoji: "🎲", subtitle: "Go with the flow"),
        .init(value: "indoor", title: "Indoor", emoji: "🏠", subtitle: "Cafes, bars, venues"),
        .init(value: "outdoor", title: "Outdoor", emoji: "🌳", subtitle: "Parks, nature, walks"),
        .init(value: "daytime", title: "Daytime", emoji: "☀️", subtitle: "Brunch, coffee, lunch"),
        .init(value: "nighttime", title: "Nighttime", emoji: "🌙", subtitle: "Dinner, bars, clubs")
    ]

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 22) {
                OnboardingHeader(
                    title: "What's your hangout style?",
                    subtitle: "Help us understand your preferences"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferred Group Size")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    ForEach(GroupSize.allCases) { option in
                        let selected = groupSize == option
                        Button {
                            groupSize = option
                        } label: {
                            HStack(spacing: 12) {
                                Text(option.emoji)
                                    .font(.system(size: 32))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                    Text(option.description)
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                }
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(FriendZoneTheme.Colors.primary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 66)
                            .background(selected ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle, lineWidth: selected ? 1.5 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Activity Preferences (Select multiple)")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    ForEach(activityOptions) { option in
                        let selected = activityTypes.contains(option.value)
                        Button {
                            toggleActivity(option.value)
                        } label: {
                            HStack(spacing: 10) {
                                Text(option.emoji)
                                    .font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                    Text(option.subtitle)
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                }
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(FriendZoneTheme.Colors.primary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 54)
                            .background(selected ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle, lineWidth: selected ? 1.5 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                OnboardingPrimaryButton(
                    title: "Continue",
                    disabled: activityTypes.isEmpty,
                    action: onContinue
                )
            }
        }
    }

    private func toggleActivity(_ value: String) {
        if activityTypes.contains(value) {
            activityTypes.removeAll { $0 == value }
        } else {
            activityTypes.append(value)
        }
    }
}

private struct OnboardingReadyStep: View {
    let data: OnboardingProfileData
    let isCompleting: Bool
    let errorMessage: String
    let onComplete: () -> Void

    var body: some View {
        OnboardingStepShell {
            VStack(spacing: 24) {
                Text("🎉")
                    .font(.system(size: 76))
                    .frame(height: 80)

                Text("You're all set!")
                    .font(FriendZoneTheme.Typography.system(34, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text("Welcome to FriendZone, \(firstName)")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR PROFILE HIGHLIGHTS")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                    OnboardingSummaryRow(emoji: "📍", label: "Location", value: data.city.isEmpty ? "Not set" : data.city)
                    if !data.languages.isEmpty {
                        OnboardingSummaryRow(
                            emoji: "🗣️",
                            label: "Languages",
                            value: data.languages.map(\.name).joined(separator: ", ")
                        )
                    }
                    OnboardingSummaryRow(emoji: "✨", label: "Interests", value: data.interests.isEmpty ? "None yet" : "\(data.interests.count) selected")
                    OnboardingSummaryRow(emoji: "🎯", label: "Vibes", value: data.vibes.isEmpty ? "None yet" : "\(data.vibes.count) vibes")
                    OnboardingSummaryRow(emoji: "📅", label: "Availability", value: data.availability.isEmpty ? "Not set" : "\(data.availability.count) time slots")
                    OnboardingSummaryRow(emoji: "👥", label: "Group Size", value: data.groupSize.summary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("WHAT'S NEXT?")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                    OnboardingFeatureRow(
                        emoji: "🌊",
                        title: "Discover Hangouts",
                        description: "Browse activities happening near you right now"
                    )
                    OnboardingFeatureRow(
                        emoji: "⚡",
                        title: "Share Your Vibes",
                        description: "Let people know what you're up for with Ambitions"
                    )
                    OnboardingFeatureRow(
                        emoji: "🗺️",
                        title: "Explore Nearby",
                        description: "See hangouts and events on the map"
                    )
                }

                if !errorMessage.isEmpty {
                    HStack(spacing: 8) {
                        Text("⚠️")
                        Text(errorMessage)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                    }
                    .foregroundColor(FriendZoneTokens.Colors.errorStrong)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FriendZoneTheme.Colors.error.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.error.opacity(0.25), lineWidth: 1)
                    }
                }

                OnboardingPrimaryButton(
                    title: isCompleting ? "Setting up your profile..." : "Let's Go! 🚀",
                    disabled: isCompleting,
                    action: onComplete
                )
            }
        }
    }

    private var firstName: String {
        let first = data.name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "friend" : first
    }
}

private struct OnboardingHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(28, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(FriendZoneTheme.Typography.system(15, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.bottom, 2)
    }
}

private struct OnboardingPrimaryButton: View {
    let title: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}

private struct OnboardingFeatureRow: View {
    let emoji: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(description)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .lineSpacing(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 74)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct OnboardingSummaryRow: View {
    let emoji: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                Text(value)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}
