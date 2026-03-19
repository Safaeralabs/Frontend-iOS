import Combine
import ImageIO
import MapKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum CreateHangoutStep: Int, CaseIterable, Identifiable {
    case plan
    case vibe
    case location
    case timing
    case access
    case extras
    case preview

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .plan: return "Set The Plan"
        case .vibe: return "Set The Vibe"
        case .location: return "Pick The Spot"
        case .timing: return "Choose The Timing"
        case .access: return "Choose Who Joins"
        case .extras: return "Optional Details"
        case .preview: return "Preview"
        }
    }

    var subtitle: String {
        switch self {
        case .plan: return "Give people the headline and story in one quick glance."
        case .vibe: return "Choose the energy people are saying yes to."
        case .location: return "Pick the real-world spot. No invented places."
        case .timing: return "Lock the day and rhythm of the plan."
        case .access: return "Decide who this is for and how open it is."
        case .extras: return "Only add filters that truly help."
        case .preview: return "Check the card exactly how people will see it."
        }
    }

    var emoji: String {
        switch self {
        case .plan: return "📝"
        case .vibe: return "✨"
        case .location: return "📍"
        case .timing: return "⏰"
        case .access: return "👥"
        case .extras: return "🌍"
        case .preview: return "🪩"
        }
    }

    var warmHint: String {
        switch self {
        case .plan: return "Clarity wins. If it sounds easy to join, it usually works."
        case .vibe: return "People decide fast from feeling, not logistics."
        case .location: return "One real spot beats five vague ideas."
        case .timing: return "A simple time window feels low-friction."
        case .access: return "The right crowd matters more than a big crowd."
        case .extras: return "Keep this light unless a filter really helps."
        case .preview: return "This is the last feel-check before you post."
        }
    }

    var shortTitle: String {
        switch self {
        case .plan: return "Plan"
        case .vibe: return "Vibe"
        case .location: return "Where"
        case .timing: return "When"
        case .access: return "Who"
        case .extras: return "Extras"
        case .preview: return "Preview"
        }
    }
}

struct CreateHangoutView: View {
    let onCancel: () -> Void
    let onCreated: (CreateHangoutDraft) -> Void

    @EnvironmentObject private var session: AppSessionStore

    @StateObject private var model: CreateHangoutFormModel
    @StateObject private var placeSearch: ApplePlaceSearchModel
    @State private var resolvedPlaceQuery = ""
    @State private var currentStep: CreateHangoutStep = .plan
    @State private var isSubtitleExpanded: Bool
    @State private var selectedPlaceRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    private let languageOptions: [EmojiChoiceItem] = [
        EmojiChoiceItem(id: "en", emoji: "🇬🇧", title: "English"),
        EmojiChoiceItem(id: "es", emoji: "🇪🇸", title: "Spanish"),
        EmojiChoiceItem(id: "de", emoji: "🇩🇪", title: "German"),
        EmojiChoiceItem(id: "fr", emoji: "🇫🇷", title: "French"),
        EmojiChoiceItem(id: "it", emoji: "🇮🇹", title: "Italian"),
        EmojiChoiceItem(id: "ja", emoji: "🇯🇵", title: "Japanese")
    ]

    init(
        onCancel: @escaping () -> Void,
        onCreated: @escaping (CreateHangoutDraft) -> Void,
        initialDraft: CreateHangoutDraft = CreateHangoutDraft()
    ) {
        self.onCancel = onCancel
        self.onCreated = onCreated
        _model = StateObject(wrappedValue: CreateHangoutFormModel(initialDraft: initialDraft))
        _placeSearch = StateObject(wrappedValue: ApplePlaceSearchModel())
        _isSubtitleExpanded = State(initialValue: !initialDraft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar

                stickyStepHeader

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if model.sourceType == .event {
                            eventSourceBanner
                        }

                        currentStepContent
                            .id(currentStep)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                )
                            )
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .onChange(of: model.selectedCoverItem) { _ in
                model.loadSelectedCover()
            }
            .onChange(of: placeSearch.query) { newValue in
                guard model.isLocationEditing else { return }
                let normalizedQuery = normalizedPlaceQuery(newValue)
                guard !normalizedQuery.isEmpty else {
                    resolvedPlaceQuery = ""
                    model.clearResolvedLocation()
                    return
                }

                if !resolvedPlaceQuery.isEmpty && normalizedQuery != resolvedPlaceQuery {
                    resolvedPlaceQuery = ""
                    model.clearResolvedLocation()
                }
            }
            .onDisappear {
                model.cancelTasks()
            }
            .onAppear {
                refreshSelectedPlaceRegion()
            }
            .task(id: searchBiasCityName) {
                await placeSearch.setPreferredCity(searchBiasCityName)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: currentStep)
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(FriendZoneTheme.Typography.system(16, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .disabled(model.isSubmitting)

                Spacer(minLength: 0)
            }
            .overlay {
                Text(headerTitle)
                    .font(FriendZoneTheme.Typography.system(17, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            }
            .overlay(alignment: .trailing) {
                if model.sourceType != .hangout {
                    Text(sourceTypeTitle.uppercased())
                        .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                        .foregroundColor(model.sourceType == .event ? .white : FriendZoneTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(model.sourceType == .event ? Color(hex: "#7C3AED") : Color.black.opacity(0.04))
                        .clipShape(Capsule())
                }
            }

            stepProgressStrip
        }
        .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
        .padding(.top, FriendZoneTheme.Chrome.topOffset)
        .padding(.bottom, 10)
        .background(FriendZoneTheme.Colors.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FriendZoneTheme.Colors.borderSubtle)
                .frame(height: 1)
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message = model.errorMessage {
                errorCard(message)
            }

            HStack(spacing: 10) {
                if currentStep != .plan {
                    Button("Back") {
                        model.errorMessage = nil
                        if let previous = CreateHangoutStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = previous
                        }
                    }
                    .buttonStyle(.plain)
                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .frame(width: 96, height: 54)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button(primaryButtonTitle) {
                    handlePrimaryAction()
                }
                .buttonStyle(.plain)
                .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.22), radius: 12, x: 0, y: 6)
                .disabled(model.isSubmitting || model.sourceType == .offer)
                .opacity(model.isSubmitting || model.sourceType == .offer ? 0.65 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(FriendZoneTheme.Colors.surface.opacity(0.98))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FriendZoneTheme.Colors.borderSubtle)
                .frame(height: 1)
        }
    }

    private var eventSourceBanner: some View {
        HStack(alignment: .center, spacing: 9) {
            Text("EVENT")
                .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color(hex: "#7C3AED"))
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text("Creating hangout for an event")
                    .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                    .foregroundColor(Color(hex: "#4C1D95"))

                Text("The backend can inherit timing and location from the source event if needed.")
                    .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                    .foregroundColor(Color(hex: "#5B21B6"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(hex: "#F5F0FF"), Color(hex: "#EDE9FE")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "#DDD6FE"), lineWidth: 1)
        }
        .padding(.horizontal, 14)
    }

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("🎟️")
                    .font(.system(size: 16))

                Text("What are people saying yes to?")
                    .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }

            TextField(
                "",
                text: $model.title,
                prompt: Text("Dinner, rooftop drinks, coffee walk...")
                    .foregroundColor(Color.black.opacity(0.18)),
                axis: .vertical
            )
            .font(FriendZoneTheme.Typography.system(28, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            .lineLimit(2 ... 3)

            HStack {
                Text("BASICS")
                    .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1)

                Spacer()

                Text("\(model.title.trimmingCharacters(in: .whitespacesAndNewlines).count) chars")
                    .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        .padding(.horizontal, 14)
    }

    private var subtitleCard: some View {
        section("Subtitle", optionalHint: "optional") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        isSubtitleExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(hasSubtitle ? FriendZoneTheme.Colors.primarySoft : Color.black.opacity(0.04))
                                .frame(width: 40, height: 40)

                            Text(subtitleCardIcon)
                                .font(.system(size: 18))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(subtitleActionTitle)
                                    .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                                Text(subtitleBadgeTitle)
                                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                                    .foregroundColor(hasSubtitle ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textTertiary)
                                    .padding(.horizontal, 7)
                                    .frame(height: 18)
                                    .background(hasSubtitle ? FriendZoneTheme.Colors.primarySoft : Color.black.opacity(0.05))
                                    .clipShape(Capsule())
                            }

                            Text(subtitleSummaryText)
                                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                .lineLimit(isSubtitleExpanded ? 3 : 2)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: isSubtitleExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(hasSubtitle ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(hasSubtitle ? FriendZoneTheme.Colors.primarySoft : Color.black.opacity(0.04))
                            .clipShape(Circle())
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(hasSubtitle ? FriendZoneTheme.Colors.surface : Color.black.opacity(0.02))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                hasSubtitle ? FriendZoneTheme.Colors.primarySoftBorder : Color.black.opacity(0.06),
                                style: StrokeStyle(lineWidth: 1, dash: hasSubtitle ? [] : [5])
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                if isSubtitleExpanded {
                    ZStack(alignment: .topLeading) {
                        if model.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Optional. Add one short line only if it helps people picture the plan.")
                                .font(FriendZoneTheme.Typography.system(14, weight: .regular))
                                .foregroundColor(Color.black.opacity(0.25))
                                .padding(.top, 8)
                                .padding(.leading, 6)
                        }

                        TextEditor(text: $model.description)
                            .font(FriendZoneTheme.Typography.system(14, weight: .regular))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .frame(minHeight: 92)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.02))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack {
                        Text("Leave it blank if the title already says enough.")
                            .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                        Spacer(minLength: 0)

                        if !model.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Clear") {
                                model.description = ""
                            }
                            .buttonStyle(.plain)
                            .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                        }
                    }
                }
            }
        }
    }

    private var sourceCard: some View {
        section("Source") {
            VStack(alignment: .leading, spacing: 14) {
                fixedValueRow("Source Type", value: sourceTypeTitle, detail: sourceDetail)

                if model.sourceType == .event {
                    labeledTextField("Source Event ID", text: $model.sourceEventIDText, placeholder: "Required for event hangouts")
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var vibeCard: some View {
        section("The Vibe") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick the energy first. People usually feel this before they read everything else.")
                    .font(FriendZoneTheme.Typography.system(13, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                VibeChipGrid(
                    vibes: HangoutCreateVibe.allCases,
                    selectedVibe: model.vibe,
                    onSelect: { vibe in
                        model.vibe = vibe
                    }
                )
            }
        }
    }

    private var locationCard: some View {
        section("Where") {
            VStack(alignment: .leading, spacing: 10) {
                locationSearchField

                if placeSearch.isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if model.isLocationEditing && !placeSearch.suggestions.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(placeSearch.suggestions) { suggestion in
                            Button {
                                Task { await applyPlaceSuggestion(suggestion) }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(FriendZoneTheme.Colors.primarySoft)
                                            .frame(width: 30, height: 30)

                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(FriendZoneTheme.Colors.primary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(suggestion.title)
                                            .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(FriendZoneTheme.Typography.system(11, weight: .regular))
                                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 10)
                                .background(FriendZoneTheme.Colors.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if model.isLocationEditing && !normalizedPlaceQuery(placeSearch.query).isEmpty && !model.hasResolvedLocation && !placeSearch.isSearching {
                    selectionPromptCard(
                        title: "Pick one of the suggestions",
                        detail: "Only places selected from the dropdown can be used."
                    )
                }

                if model.hasResolvedLocation {
                    selectedPlaceCard
                    selectedPlaceMapCard
                } else {
                    selectionPromptCard(
                        title: "No place selected yet",
                        detail: model.sourceType == .event
                            ? "Pick a place from the dropdown if you want to override the source event location."
                            : "Search and choose a place from the dropdown to continue."
                    )
                }
            }
        }
    }

    private var timingCard: some View {
        section("When") {
            VStack(alignment: .leading, spacing: 10) {
                pillToggleRow {
                    pillToggleButton("Exact Time", isActive: !model.isTimeFlexible) {
                        model.isTimeFlexible = false
                    }
                    pillToggleButton("I'm Flexible", isActive: model.isTimeFlexible) {
                        model.isTimeFlexible = true
                    }
                }

                quickDayShortcutRow

                HStack(spacing: 10) {
                    modernPickerCard("Day", systemImage: "calendar") {
                        DatePicker("", selection: $model.startDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    modernPickerCard("Start Time", systemImage: "clock", isDisabled: model.isTimeFlexible) {
                        DatePicker("", selection: $model.startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .disabled(model.isTimeFlexible)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                durationCard

                timingSummaryCard
            }
        }
    }

    private var accessCard: some View {
        section("Who") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    rowLabel("Visibility")
                    pillToggleRow {
                        pillToggleButton("🌍 Public", isActive: model.visibility == .public) {
                            model.applyVisibility(.public)
                        }
                        pillToggleButton("🔒 Private", isActive: model.visibility == .inviteOnly) {
                            model.applyVisibility(.inviteOnly)
                        }
                    }
                }

                groupSizeCard

                if model.visibility == .inviteOnly {
                    VStack(alignment: .leading, spacing: 12) {
                        infoNote("Only guests with the code can join.")

                        labeledTextField(
                            "Invite Code",
                            text: $model.inviteCode,
                            placeholder: "Add a private code",
                            textInputAutocapitalization: .never
                        )

                        labeledTextField(
                            "Code Hint",
                            text: $model.inviteCodeHint,
                            placeholder: "Optional clue for your guests",
                            textInputAutocapitalization: .sentences
                        )
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        rowLabel("Crowd")
                        pillToggleRow {
                            ForEach(HangoutGenderPreference.allCases, id: \.rawValue) { option in
                                pillToggleButton(option.title, isActive: model.genderPreference == option) {
                                    model.genderPreference = option
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var audienceCard: some View {
        section("Languages & Audience") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        rowLabel("Languages")
                        Text("(optional)")
                            .font(FriendZoneTheme.Typography.system(10, weight: .regular))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }

                    EmojiChoiceChipGrid(
                        items: languageOptions,
                        selectedIDs: Set(model.languages),
                        onTap: model.toggleLanguage
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        rowLabel("Audience Tags")
                        Text("(optional · max 5)")
                            .font(FriendZoneTheme.Typography.system(10, weight: .regular))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }

                    EmojiChoiceChipGrid(
                        items: HangoutAudienceTagOption.allCases.map {
                            EmojiChoiceItem(id: $0.rawValue, emoji: $0.emoji, title: $0.title)
                        },
                        selectedIDs: Set(model.audienceTags),
                        onTap: model.toggleAudienceTag
                    )
                }
            }
        }
    }

    private var previewCard: some View {
        section("Preview") {
            VStack(alignment: .center, spacing: 10) {
                HangoutPreviewContainerView(
                    hangout: previewHangout,
                    locationAddress: model.locationAddress,
                    audienceTags: model.audienceTags,
                    languages: model.languages,
                    visibility: model.visibility,
                    genderPreference: model.genderPreference,
                    isTimeFlexible: model.isTimeFlexible
                )
                .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var coverCard: some View {
        section("Cover Photo", optionalHint: "optional") {
            VStack(alignment: .leading, spacing: 12) {
                if let preview = model.coverPreviewImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button {
                            model.clearCover()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.58))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
                } else {
                    PhotosPicker(selection: $model.selectedCoverItem, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 20, weight: .semibold))

                            Text("Add Cover Photo")
                                .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                        }
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 92)
                        .background(Color.black.opacity(0.02))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var headerTitle: String {
        "Create a Hangout"
    }

    private var sourceTypeTitle: String {
        switch model.sourceType {
        case .hangout: return "Community"
        case .event: return "Event"
        case .offer: return "Offer"
        }
    }

    private var sourceDetail: String? {
        switch model.sourceType {
        case .hangout:
            return "Standard community hangout."
        case .event:
            return "When source_event_id is present, the backend can fill missing city, location and timing data from the event."
        case .offer:
            return "The backend create endpoint still does not accept offer-sourced hangouts."
        }
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch currentStep {
        case .plan:
            if model.sourceType != .hangout {
                sourceCard
            }
            basicsCard
            coverCard
            subtitleCard
        case .vibe:
            vibeCard
        case .location:
            locationCard
        case .timing:
            timingCard
        case .access:
            accessCard
        case .extras:
            audienceCard
        case .preview:
            previewCard
        }
    }

    private var stickyStepHeader: some View {
        VStack(spacing: 0) {
            stepHeaderCard
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .background(FriendZoneTheme.Colors.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FriendZoneTheme.Colors.borderSubtle.opacity(0.75))
                .frame(height: 1)
        }
    }

    private var stepHeaderCard: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 10) {
                Text(currentStep.emoji)
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(FriendZoneTheme.Colors.primarySoft)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("STEP \(currentStep.rawValue + 1) OF \(CreateHangoutStep.allCases.count)")
                        .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(1)

                    Text(currentStep.title)
                        .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }
            }

            Spacer(minLength: 0)

            Text("\(currentStep.rawValue + 1)")
                .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(FriendZoneTheme.Colors.primarySoftBorder, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        .padding(.horizontal, 14)
    }

    private var stepProgressStrip: some View {
        HStack(spacing: 6) {
            ForEach(CreateHangoutStep.allCases) { step in
                Button {
                    guard step.rawValue <= currentStep.rawValue else { return }
                    model.errorMessage = nil
                    currentStep = step
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            Capsule()
                                .fill(step == currentStep ? FriendZoneTheme.Colors.primary : Color.black.opacity(0.06))
                                .frame(height: 5)

                            if step.rawValue < currentStep.rawValue {
                                Capsule()
                                    .fill(Color(hex: "#10B981"))
                                    .frame(height: 5)
                            }
                        }

                        Text(step.shortTitle)
                            .font(FriendZoneTheme.Typography.system(9, weight: .semibold))
                            .foregroundColor(step == currentStep ? FriendZoneTheme.Colors.textPrimary : FriendZoneTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(step.rawValue > currentStep.rawValue)
            }
        }
    }

    private var primaryButtonTitle: String {
        if currentStep == .extras {
            return "Preview"
        }
        if currentStep == .preview {
            return model.isSubmitting ? "Posting..." : "Post Hangout"
        }
        return "Continue"
    }

    private func handlePrimaryAction() {
        model.errorMessage = nil

        if let message = validationMessage(for: currentStep) {
            model.errorMessage = message
            return
        }

        guard currentStep != .preview else {
            model.submit(
                session: session,
                onSuccess: { draft in
                    onCreated(draft)
                    onCancel()
                }
            )
            return
        }

        if let next = CreateHangoutStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    private func validationMessage(for step: CreateHangoutStep) -> String? {
        switch step {
        case .plan:
            if model.sourceType == .offer {
                return "Offer-sourced hangouts are not supported yet."
            }
            if model.sourceType == .event,
               model.sourceEventIDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Add the source event ID to continue."
            }
            if model.sourceType != .event,
               model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Add a title for the plan to continue."
            }
            return nil
        case .vibe:
            return nil
        case .location:
            if model.sourceType != .event && !model.hasResolvedLocation {
                return "Choose a real place from the dropdown to continue."
            }
            return nil
        case .timing:
            if model.durationHours < 1 {
                return "Pick how long the plan lasts."
            }
            return nil
        case .access:
            if model.visibility == .inviteOnly {
                let code = model.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                if code.isEmpty {
                    return "Add an invite code for the private hangout."
                }
                if code.count < 4 {
                    return "Invite code must be at least 4 characters."
                }
            }
            return nil
        case .extras:
            return nil
        case .preview:
            return nil
        }
    }

    private var searchBiasCityName: String {
        let profileCity = session.currentProfile?.cityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !profileCity.isEmpty {
            return profileCity
        }
        return model.preferredSearchCityName
    }

    private var searchPlacePlaceholder: String {
        if !searchBiasCityName.isEmpty {
            return "Search in \(searchBiasCityName)..."
        }
        return "Search for a place..."
    }

    private var previewHangout: HangoutItem {
        HangoutItem(
            id: 9_999,
            sourceType: model.sourceType,
            title: model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your hangout title" : model.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: model.description.trimmingCharacters(in: .whitespacesAndNewlines),
            vibe: previewHangoutVibe,
            cityName: model.cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (session.currentProfile?.cityName ?? "City") : model.cityName.trimmingCharacters(in: .whitespacesAndNewlines),
            locationName: model.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : model.locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            locationAddress: model.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : model.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: Double(model.latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
            longitude: Double(model.longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
            hostUserID: session.currentUser?.id ?? session.currentProfile?.user?.id,
            hostName: session.currentProfile?.user?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (session.currentProfile?.user?.firstName ?? "You")
                : (session.currentUser?.username ?? "You"),
            startAt: previewStartAt,
            endAt: model.projectedEndAt,
            capacity: model.isCapacityUnlimited ? 24 : max(1, model.capacity),
            isCapacityUnlimited: model.isCapacityUnlimited,
            approvedCount: 0,
            isJoined: false,
            participantNames: [],
            coverImageData: model.previewCoverImageData,
            coverSeed: model.previewCoverSeed,
            distanceKm: 1.2,
            priceTier: .budget,
            visibility: model.visibility,
            inviteCode: model.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : model.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines),
            inviteCodeHint: model.inviteCodeHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : model.inviteCodeHint.trimmingCharacters(in: .whitespacesAndNewlines),
            allowWaitlist: model.visibility == .inviteOnly ? false : model.allowWaitlist,
            genderPreference: model.visibility == .inviteOnly ? .any : model.genderPreference,
            audienceTags: model.audienceTags,
            languages: model.languages,
            isTimeFlexible: model.isTimeFlexible,
            sourceEventID: model.sourceEventIDText.isEmpty ? nil : Int(model.sourceEventIDText),
            sourceOfferID: model.sourceOfferID
        )
    }

    private var previewStartAt: Date {
        model.isTimeFlexible ? Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: model.startDate) ?? model.startDate : model.startAtForPreview
    }

    private var planPulseTitle: String {
        let title = model.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = model.description.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            return "Start with the plan"
        }
        if description.isEmpty {
            return "The title is doing the work"
        }
        return "This already feels inviting"
    }

    private var planPulseDetail: String {
        let title = model.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = model.description.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            return "A clear title works best."
        }
        if description.isEmpty {
            return "Subtitle is optional."
        }
        return "Clear and easy to join."
    }

    private var subtitleSummaryText: String {
        let trimmed = model.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Optional. Use it only if one extra line helps the plan land better."
        }
        return trimmed
    }

    private var hasSubtitle: Bool {
        !model.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var subtitleCardIcon: String {
        hasSubtitle ? "💬" : "✍️"
    }

    private var subtitleActionTitle: String {
        hasSubtitle ? "Edit subtitle" : "Add a subtitle"
    }

    private var subtitleBadgeTitle: String {
        hasSubtitle ? "ADDED" : "OPTIONAL"
    }

    private var previewHangoutVibe: HangoutVibe {
        model.vibe.hangoutVibe
    }

    private var locationSearchField: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowLabel("Search Place")

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                TextField(searchPlacePlaceholder, text: $placeSearch.query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .disabled(!model.isLocationEditing)
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                if model.hasResolvedLocation && !model.isLocationEditing {
                    Button {
                        model.isLocationEditing = true
                        placeSearch.clearSuggestions()
                    } label: {
                        Text("✏️")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(model.isLocationEditing ? Color.black.opacity(0.03) : Color.black.opacity(0.02))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(model.isLocationEditing ? Color.black.opacity(0.06) : Color(hex: "#86EFAC"), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var selectedPlaceCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#16A34A"))
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Spot locked in")
                        .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                        .foregroundColor(Color(hex: "#166534"))

                    if !model.cityName.isEmpty {
                        Text(model.cityName)
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(Color(hex: "#166534"))
                            .padding(.horizontal, 7)
                            .frame(height: 18)
                            .background(Color.white.opacity(0.75))
                            .clipShape(Capsule())
                    }
                }

                Text(model.locationName)
                    .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                if !model.locationAddress.isEmpty {
                    Text(model.locationAddress)
                        .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#F0FDF4"))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "#86EFAC"), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var selectedPlaceMapCard: some View {
        Map(
            coordinateRegion: $selectedPlaceRegion,
            interactionModes: [.all],
            annotationItems: selectedPlaceMarkers
        ) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "mappin")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                }
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Image(systemName: "mappin")
                    .font(.system(size: 10, weight: .bold))
                Text("Selected spot")
                    .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
            .padding(8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private var selectedPlaceMarkers: [SelectedPlaceMarker] {
        guard let coordinate = selectedPlaceCoordinate else { return [] }
        return [SelectedPlaceMarker(coordinate: coordinate)]
    }

    private var selectedPlaceCoordinate: CLLocationCoordinate2D? {
        guard let latitude = Double(model.latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let longitude = Double(model.longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func selectionPromptCard(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("🧭")
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(detail)
                    .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.02))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func quickDayButton(title: String, offset: Int) -> some View {
        let isSelected = Calendar.current.isDate(model.startDate, inSameDayAs: shortcutDate(offset: offset))

        return Button(title) {
            model.startDate = shortcutDate(offset: offset)
        }
        .buttonStyle(.plain)
        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
        .foregroundColor(isSelected ? .white : FriendZoneTheme.Colors.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Group {
                if isSelected {
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Color.black.opacity(0.04)
                }
            }
        )
        .clipShape(Capsule())
    }

    private func quickDurationButton(hours: Int) -> some View {
        let isSelected = model.durationHours == hours

        return Button("\(hours)h") {
            model.durationHours = hours
        }
        .buttonStyle(.plain)
        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
        .foregroundColor(isSelected ? .white : FriendZoneTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(
            Group {
                if isSelected {
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Color.black.opacity(0.04)
                }
            }
        )
        .clipShape(Capsule())
    }

    private func shortcutDate(offset: Int) -> Date {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: offset, to: base) ?? base
    }

    private var timingSummaryCard: some View {
        HStack(spacing: 10) {
            Text(model.isTimeFlexible ? "🕊️" : "🗓️")
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(
                    model.isTimeFlexible
                        ? "Flexible start · \(model.durationHours)h plan"
                        : "\(timeLabel(model.startTime)) · \(model.durationHours)h plan"
                )
                    .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                if !model.isTimeFlexible {
                    Text("Wraps around \(timeLabel(model.projectedEndAt))")
                        .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: model.isTimeFlexible ? "calendar.badge.clock" : "clock.badge.checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(FriendZoneTheme.Colors.primarySoft)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.primarySoftBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var quickDayShortcutRow: some View {
        HStack(spacing: 6) {
            quickDayButton(title: "Today", offset: 0)
            quickDayButton(title: "Tomorrow", offset: 1)
            quickDayButton(title: "After Tomorrow", offset: 2)
        }
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            rowLabel("How Long")

            HStack(spacing: 10) {
                Text("⏳")
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Plan length")
                        .font(FriendZoneTheme.Typography.system(13, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                    Text("\(model.durationHours) \(model.durationHours == 1 ? "hour" : "hours")")
                        .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }

                Spacer()

                HStack(spacing: 14) {
                    capacityButton(symbol: "minus") {
                        model.durationHours = max(1, model.durationHours - 1)
                    }

                    Text("\(model.durationHours)h")
                        .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(minWidth: 34)

                    capacityButton(symbol: "plus") {
                        model.durationHours = min(12, model.durationHours + 1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.02))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 6) {
                ForEach([1, 2, 3, 4, 5, 6], id: \.self) { hours in
                    quickDurationButton(hours: hours)
                }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, optionalHint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title.uppercased())
                    .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1)

                if let optionalHint {
                    Text("(\(optionalHint))")
                        .font(FriendZoneTheme.Typography.system(10, weight: .regular))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func labeledTextField(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        textInputAutocapitalization: TextInputAutocapitalization? = .words
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            rowLabel(label)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(Color.black.opacity(0.025))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func fixedValueRow(_ label: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            rowLabel(label)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(FriendZoneTheme.Typography.system(15, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(FriendZoneTheme.Typography.system(12, weight: .regular))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.025))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var groupSizeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            rowLabel(model.visibility == .inviteOnly ? "Guest Count" : "Group Size")

            HStack(spacing: 12) {
                Text(model.visibility == .inviteOnly ? "🔐" : "👯")
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.visibility == .inviteOnly ? "Inside this circle" : "Right size for this plan")
                        .font(FriendZoneTheme.Typography.system(13, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                    Text(model.isCapacityUnlimited ? "Open size" : "\(model.capacity) people")
                        .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(groupSizeMoodText)
                        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }

                Spacer()

                if !model.isCapacityUnlimited {
                    HStack(spacing: 14) {
                        capacityButton(symbol: "minus") {
                            model.capacity = max(1, model.capacity - 1)
                        }

                        Text("\(model.capacity)")
                            .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            .frame(minWidth: 28)

                        capacityButton(symbol: "plus") {
                            model.capacity = min(30, model.capacity + 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.02))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var groupSizeMoodText: String {
        if model.isCapacityUnlimited {
            return "Let the right crowd shape the size."
        }

        switch model.capacity {
        case 1...3:
            return "Tiny circle energy."
        case 4...8:
            return "Small group, easy chemistry."
        case 9...15:
            return "A lively social table."
        default:
            return "This reads like a bigger open plan."
        }
    }

    private func languageDisplayName(_ code: String) -> String {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "en": return "🇬🇧 English"
        case "es": return "🇪🇸 Spanish"
        case "de": return "🇩🇪 German"
        case "fr": return "🇫🇷 French"
        case "it": return "🇮🇹 Italian"
        case "ja": return "🇯🇵 Japanese"
        default: return code.uppercased()
        }
    }

    private func audienceDisplayName(_ tag: String) -> String {
        if let option = HangoutAudienceTagOption(rawValue: tag) {
            return "\(option.emoji) \(option.title)"
        }
        return tag.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func capacityButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .frame(width: 32, height: 32)
                .background(FriendZoneTheme.Colors.surface)
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.10), lineWidth: 1)
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func pillToggleRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4, content: content)
            .padding(4)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func pillToggleButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(13, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? .white : FriendZoneTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    Group {
                        if isActive {
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.clear
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.black.opacity(isActive ? 0.08 : 0), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func modernPickerCard<Content: View>(
        _ label: String,
        systemImage: String,
        isDisabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            rowLabel(label)

            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isDisabled ? FriendZoneTheme.Colors.textTertiary : FriendZoneTheme.Colors.primary)
                    .frame(width: 24, height: 24)
                    .background(
                        (isDisabled ? Color.black.opacity(0.04) : FriendZoneTheme.Colors.primarySoft)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(isDisabled ? Color.black.opacity(0.02) : Color.black.opacity(0.025))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isDisabled ? Color.black.opacity(0.04) : Color.black.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isDisabled ? 0.55 : 1)
        }
    }

    private func rowLabel(_ label: String) -> some View {
        Text(label.uppercased())
            .font(FriendZoneTheme.Typography.system(11, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            .tracking(0.6)
    }

    private func infoNote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .padding(.top, 1)

            Text(text)
                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FriendZoneTheme.Colors.primarySoft)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.primarySoftBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(FriendZoneTheme.Typography.system(14, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(FriendZoneTheme.Colors.error.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.error.opacity(0.18), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @MainActor
    private func applyPlaceSuggestion(_ suggestion: ApplePlaceSuggestion) async {
        do {
            model.errorMessage = nil
            let resolved = try await placeSearch.resolve(suggestion)
            model.locationName = resolved.name
            model.locationAddress = resolved.formattedAddress
            if let latitude = resolved.latitude {
                model.latitudeText = coordinateText(latitude)
            }
            if let longitude = resolved.longitude {
                model.longitudeText = coordinateText(longitude)
            }

            if let latitude = resolved.latitude, let longitude = resolved.longitude {
                do {
                    let guessed = try await session.guessLocation(
                        lat: latitude,
                        lng: longitude,
                        cityName: resolved.cityName,
                        country: resolved.countryCode ?? resolved.countryName
                    )
                    model.cityName = guessed.cityName
                    model.cityPlaceID = guessed.cityPlaceId
                } catch {
                    let resolvedCity = resolved.cityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let profileCityName = session.currentProfile?.cityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let profileCityPlaceID = session.currentProfile?.cityPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if !profileCityName.isEmpty,
                       !profileCityPlaceID.isEmpty,
                       (resolvedCity.isEmpty || normalizedPlaceQuery(resolvedCity) == normalizedPlaceQuery(profileCityName)) {
                        model.cityName = profileCityName
                        model.cityPlaceID = profileCityPlaceID
                    } else {
                        throw AppSessionError.httpStatus(
                            400,
                            "Couldn't confirm the city for this place. Pick a result in your onboarding city."
                        )
                    }
                }
            } else if let cityName = resolved.cityName, !cityName.isEmpty {
                model.cityName = cityName
            }

            let resolvedQuery = resolved.formattedAddress.isEmpty ? resolved.name : resolved.formattedAddress
            resolvedPlaceQuery = normalizedPlaceQuery(resolvedQuery)
            placeSearch.query = resolvedQuery
            placeSearch.clearSuggestions()
            model.isLocationEditing = false
            refreshSelectedPlaceRegion()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func coordinateText(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private func normalizedPlaceQuery(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func refreshSelectedPlaceRegion() {
        guard let coordinate = selectedPlaceCoordinate else { return }
        selectedPlaceRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
    }
}

@MainActor
private final class CreateHangoutFormModel: ObservableObject {
    @Published var title: String
    @Published var description: String
    @Published var cityName: String
    @Published var cityPlaceID: String
    @Published var locationName: String
    @Published var locationAddress: String
    @Published var latitudeText: String
    @Published var longitudeText: String
    @Published var startDate: Date
    @Published var startTime: Date
    @Published var durationHours: Int
    @Published var isTimeFlexible: Bool
    @Published var isCapacityUnlimited: Bool
    @Published var capacity: Int
    @Published var visibility: HangoutVisibilityOption
    @Published var inviteCode: String
    @Published var inviteCodeHint: String
    @Published var isLocationEditing: Bool
    @Published var allowWaitlist: Bool
    @Published var genderPreference: HangoutGenderPreference
    @Published var vibe: HangoutCreateVibe
    @Published var languages: [String]
    @Published var audienceTags: [String]
    @Published var sourceEventIDText: String
    @Published var selectedCoverItem: PhotosPickerItem?
    @Published var coverPreviewImage: UIImage?
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    let sourceType: HangoutSourceType
    let sourceLabel: String?
    let sourceOfferID: Int?
    let preferredSearchCityName: String

    private var coverImageData: Data?
    private var coverLoadTask: Task<Void, Never>?
    private var submissionTask: Task<Void, Never>?

    init(initialDraft: CreateHangoutDraft) {
        title = initialDraft.title
        description = initialDraft.description
        cityName = initialDraft.cityName
        cityPlaceID = initialDraft.cityPlaceID
        locationName = initialDraft.locationName
        locationAddress = initialDraft.locationAddress
        latitudeText = initialDraft.latitude.map { String($0) } ?? ""
        longitudeText = initialDraft.longitude.map { String($0) } ?? ""
        startDate = Calendar.current.startOfDay(for: initialDraft.startAt)
        startTime = initialDraft.startAt
        durationHours = max(1, initialDraft.durationHours)
        isTimeFlexible = initialDraft.isTimeFlexible
        isCapacityUnlimited = initialDraft.isCapacityUnlimited
        capacity = max(1, initialDraft.capacity)
        visibility = initialDraft.visibility
        inviteCode = initialDraft.inviteCode
        inviteCodeHint = initialDraft.inviteCodeHint
        isLocationEditing = initialDraft.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        allowWaitlist = initialDraft.visibility == .inviteOnly ? false : true
        genderPreference = initialDraft.visibility == .inviteOnly ? .any : initialDraft.genderPreference
        vibe = initialDraft.vibe
        languages = Self.normalizedLanguageCodes(from: initialDraft.languages)
        audienceTags = initialDraft.audienceTags
        sourceType = initialDraft.sourceType
        sourceLabel = initialDraft.sourceLabel
        sourceOfferID = initialDraft.sourceOfferID
        preferredSearchCityName = initialDraft.cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceEventIDText = initialDraft.sourceEventID.map(String.init) ?? ""
        selectedCoverItem = nil
        coverImageData = initialDraft.coverImageData
        coverPreviewImage = initialDraft.coverImageData.flatMap(UIImage.init(data:))
    }

    func cancelTasks() {
        coverLoadTask?.cancel()
        submissionTask?.cancel()
    }

    func clearCover() {
        selectedCoverItem = nil
        coverImageData = nil
        coverPreviewImage = nil
    }

    func clearResolvedLocation() {
        cityName = ""
        cityPlaceID = ""
        locationName = ""
        locationAddress = ""
        latitudeText = ""
        longitudeText = ""
        isLocationEditing = true
    }

    func applyVisibility(_ newValue: HangoutVisibilityOption) {
        visibility = newValue
        if newValue == .inviteOnly {
            allowWaitlist = false
            genderPreference = .any
        } else {
            allowWaitlist = true
        }
    }

    var projectedEndAt: Date {
        combinedStartAt.addingTimeInterval(TimeInterval(durationHours * 3600))
    }

    var startAtForPreview: Date {
        combinedStartAt
    }

    var previewCoverImageData: Data? {
        coverImageData
    }

    var previewCoverSeed: Int {
        Self.coverSeed(for: title)
    }

    func toggleLanguage(_ code: String) {
        if languages.contains(code) {
            languages.removeAll { $0 == code }
            return
        }

        guard languages.count < 3 else { return }
        languages.append(code)
    }

    func toggleAudienceTag(_ tag: String) {
        if audienceTags.contains(tag) {
            audienceTags.removeAll { $0 == tag }
            return
        }

        guard audienceTags.count < 5 else { return }
        audienceTags.append(tag)
    }

    func loadSelectedCover() {
        coverLoadTask?.cancel()

        guard let item = selectedCoverItem else {
            return
        }

        coverLoadTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            guard let data = try? await item.loadTransferable(type: Data.self), !Task.isCancelled else {
                return
            }

            let optimizedData = prepareCreateHangoutCoverData(data)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.coverImageData = optimizedData
                self.coverPreviewImage = UIImage(data: optimizedData)
            }
        }
    }

    func submit(
        session: AppSessionStore,
        onSuccess: @escaping (CreateHangoutDraft) -> Void
    ) {
        errorMessage = nil

        do {
            let submission = try buildSubmission()
            let draft = buildDraft()
            isSubmitting = true
            submissionTask?.cancel()
            submissionTask = Task { [weak self] in
                do {
                    _ = try await session.createHangout(from: submission)
                    await MainActor.run {
                        guard let self, !Task.isCancelled else { return }
                        self.isSubmitting = false
                        onSuccess(draft)
                    }
                } catch {
                    await MainActor.run {
                        guard let self, !Task.isCancelled else { return }
                        self.isSubmitting = false
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildDraft() -> CreateHangoutDraft {
        var draft = CreateHangoutDraft()
        draft.title = title
        draft.description = description
        draft.vibe = vibe
        draft.languages = languages
        draft.locationName = locationName
        draft.locationAddress = locationAddress
        draft.cityName = cityName
        draft.cityPlaceID = cityPlaceID
        draft.latitude = Double(latitudeText.trimmingCharacters(in: .whitespacesAndNewlines))
        draft.longitude = Double(longitudeText.trimmingCharacters(in: .whitespacesAndNewlines))
        draft.startAt = combinedStartAt
        draft.endAt = projectedEndAt
        draft.durationHours = durationHours
        draft.isTimeFlexible = isTimeFlexible
        draft.capacity = capacity
        draft.isCapacityUnlimited = isCapacityUnlimited
        draft.visibility = visibility
        draft.inviteCode = inviteCode
        draft.inviteCodeHint = inviteCodeHint
        draft.genderPreference = genderPreference
        draft.audienceTags = audienceTags
        draft.allowWaitlist = allowWaitlist
        draft.sourceType = sourceType
        draft.sourceLabel = sourceLabel
        draft.sourceOfferID = sourceOfferID
        draft.sourceEventID = sourceEventIDText.isEmpty ? nil : Int(sourceEventIDText)
        draft.coverImageData = coverImageData
        return draft
    }

    private func buildSubmission() throws -> CreateHangoutSubmission {
        if sourceType == .offer {
            throw AppSessionError.httpStatus(400, "Offer-sourced hangouts are not supported by the backend.")
        }

        let startAt = combinedStartAt
        let endAt = projectedEndAt
        guard endAt > startAt else {
            throw AppSessionError.httpStatus(400, "end_at must be greater than start_at.")
        }

        if !isCapacityUnlimited && capacity < 1 {
            throw AppSessionError.httpStatus(400, "capacity must be at least 1.")
        }

        let parsedSourceEventID: Int?
        let trimmedSourceEvent = sourceEventIDText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSourceEvent.isEmpty {
            parsedSourceEventID = nil
        } else if let value = Int(trimmedSourceEvent) {
            parsedSourceEventID = value
        } else {
            throw AppSessionError.httpStatus(400, "source_event_id must be a number.")
        }

        if sourceType == .event, parsedSourceEventID == nil {
            throw AppSessionError.httpStatus(400, "source_event_id is required for event hangouts.")
        }

        let normalizedLocationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLocationAddress = locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCityName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCityPlaceID = cityPlaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInviteCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInviteCodeHint = inviteCodeHint.trimmingCharacters(in: .whitespacesAndNewlines)
        let latitude = try parseCoordinate(latitudeText, field: "lat")
        let longitude = try parseCoordinate(longitudeText, field: "lng")
        let locationWasSelected = !normalizedLocationName.isEmpty || !normalizedCityName.isEmpty || latitude != nil || longitude != nil

        if sourceType != .event || locationWasSelected {
            guard !normalizedLocationName.isEmpty,
                  !normalizedCityName.isEmpty,
                  !normalizedCityPlaceID.isEmpty,
                  latitude != nil,
                  longitude != nil else {
                throw AppSessionError.httpStatus(400, "Select a place from search so city and coordinates are filled automatically.")
            }
        }

        if visibility == .inviteOnly {
            guard !normalizedInviteCode.isEmpty else {
                throw AppSessionError.httpStatus(400, "Add an invite code for a private hangout.")
            }
            guard normalizedInviteCode.count >= 4 else {
                throw AppSessionError.httpStatus(400, "Invite code must be at least 4 characters.")
            }
        }

        return CreateHangoutSubmission(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            vibe: vibe,
            languages: languages,
            locationName: normalizedLocationName,
            locationAddress: normalizedLocationAddress,
            cityName: normalizedCityName,
            cityPlaceID: normalizedCityPlaceID,
            latitude: latitude,
            longitude: longitude,
            startAt: startAt,
            endAt: endAt,
            durationHours: durationHours,
            isTimeFlexible: isTimeFlexible,
            capacity: capacity,
            isCapacityUnlimited: isCapacityUnlimited,
            visibility: visibility,
            inviteCode: normalizedInviteCode,
            inviteCodeHint: normalizedInviteCodeHint,
            genderPreference: visibility == .inviteOnly ? .any : genderPreference,
            audienceTags: audienceTags,
            allowWaitlist: visibility == .inviteOnly ? false : true,
            sourceType: sourceType,
            sourceLabel: sourceLabel,
            sourceEventID: parsedSourceEventID,
            sourceOfferID: sourceOfferID,
            coverImageData: coverImageData,
            coverSeed: Self.coverSeed(for: title)
        )
    }

    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute
        )) ?? date
    }

    private var combinedStartAt: Date {
        combine(date: startDate, time: startTime)
    }

    private func parseCoordinate(_ rawValue: String, field: String) throws -> Double? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed) else {
            throw AppSessionError.httpStatus(400, "\(field) must be a decimal number.")
        }
        return value
    }

    var hasResolvedLocation: Bool {
        !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cityPlaceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !latitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !longitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var coordinateSummary: String {
        [latitudeText.trimmingCharacters(in: .whitespacesAndNewlines),
         longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private static func normalizedLanguageCodes(from values: [String]) -> [String] {
        let lookup = Dictionary(uniqueKeysWithValues: [
            ("english", "en"),
            ("spanish", "es"),
            ("german", "de"),
            ("french", "fr"),
            ("italian", "it"),
            ("japanese", "ja"),
            ("en", "en"),
            ("es", "es"),
            ("de", "de"),
            ("fr", "fr"),
            ("it", "it"),
            ("ja", "ja")
        ])

        var normalized: [String] = []
        var seenCodes = Set<String>()
        for rawValue in values {
            let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let code = lookup[key], seenCodes.insert(code).inserted else {
                continue
            }
            normalized.append(code)
        }
        return normalized
    }

    private static func coverSeed(for title: String) -> Int {
        let basis = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = basis.isEmpty ? UUID().uuidString : basis
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return abs((normalized.isEmpty ? "hangout" : normalized).hashValue) % 6
    }
}

private struct ChoiceChipGrid: View {
    let items: [(id: String, title: String)]
    let selectedIDs: Set<String>
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.id) { item in
                let isSelected = selectedIDs.contains(item.id)
                Button {
                    onTap(item.id)
                } label: {
                    Text(item.title)
                        .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : FriendZoneTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            Group {
                                if isSelected {
                                    LinearGradient(
                                        colors: [FriendZoneTheme.Colors.primary, Color(hex: "#8B5CF6")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    Color.white.opacity(0.92)
                                }
                            }
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    isSelected ? FriendZoneTheme.Colors.primary.opacity(0.34) : Color.black.opacity(0.08),
                                    lineWidth: 1.5
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .scaleEffect(isSelected ? 1.03 : 1)
                        .shadow(
                            color: isSelected ? FriendZoneTheme.Colors.primary.opacity(0.18) : Color.black.opacity(0.04),
                            radius: isSelected ? 10 : 4,
                            x: 0,
                            y: isSelected ? 4 : 2
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct EmojiChoiceItem: Identifiable {
    let id: String
    let emoji: String
    let title: String
}

private struct SelectedPlaceMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private struct HangoutPreviewContainerView: View {
    let hangout: HangoutItem
    let locationAddress: String
    let audienceTags: [String]
    let languages: [String]
    let visibility: HangoutVisibilityOption
    let genderPreference: HangoutGenderPreference
    let isTimeFlexible: Bool

    @State private var rotation: Double = 0
    @State private var liftScale: CGFloat = 1
    @State private var verticalOffset: CGFloat = 0
    @State private var shineOffset: CGFloat = -220
    @State private var isFlipping = false

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                DiscoverHangoutCardView(hangout: hangout)
                    .frame(width: 320)
                .opacity(isShowingBack ? 0 : 1)
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.92
                )

                HangoutPreviewBackView(
                    hangout: hangout,
                    locationAddress: locationAddress,
                    audienceTags: audienceTags,
                    languages: languages,
                    visibility: visibility,
                    genderPreference: genderPreference,
                    isTimeFlexible: isTimeFlexible
                )
                .opacity(isShowingBack ? 1 : 0)
                .rotation3DEffect(
                    .degrees(rotation - 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.92
                )
            }
            .frame(width: 320, height: 198)
            .overlay {
                previewShine
            }
            .scaleEffect(liftScale * cardSurfaceScale)
            .offset(y: verticalOffset)
            .shadow(
                color: Color.black.opacity(isFlipping ? 0.14 : 0.06),
                radius: isFlipping ? 18 : 8,
                x: 0,
                y: isFlipping ? 10 : 3
            )
            .contentShape(Rectangle())
            .onTapGesture {
                flipCard()
            }

            Text(isShowingBack ? "Tap to return to the front" : "Tap the card to flip it")
                .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
    }

    private var isShowingBack: Bool {
        let normalized = rotation.truncatingRemainder(dividingBy: 360)
        let value = normalized < 0 ? normalized + 360 : normalized
        return value >= 90 && value < 270
    }

    private var flipMidProgress: Double {
        abs(sin(rotation * .pi / 180))
    }

    private var cardSurfaceScale: CGFloat {
        0.968 - CGFloat(flipMidProgress) * 0.028
    }

    private var previewShine: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(isFlipping ? 0.34 : 0.18),
                Color.white.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 112)
        .rotationEffect(.degrees(18))
        .offset(x: shineOffset)
        .blendMode(.screen)
        .mask(TicketSilhouetteMask())
        .allowsHitTesting(false)
    }

    private func flipCard() {
        guard !isFlipping else { return }

        let targetRotation = isShowingBack ? 0.0 : 180.0
        isFlipping = true
        FriendZoneHaptics.selection()

        withAnimation(.easeOut(duration: 0.14)) {
            liftScale = 1.018
            verticalOffset = -5
            shineOffset = -24
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 65_000_000)

            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.12)) {
                rotation = targetRotation
                shineOffset = 228
            }

            try? await Task.sleep(nanoseconds: 120_000_000)
            FriendZoneHaptics.lightImpact()

            try? await Task.sleep(nanoseconds: 170_000_000)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                liftScale = 1
                verticalOffset = 0
            }

            try? await Task.sleep(nanoseconds: 130_000_000)
            isFlipping = false
            shineOffset = -220
        }
    }
}

private struct HangoutPreviewBackView: View {
    let hangout: HangoutItem
    let locationAddress: String
    let audienceTags: [String]
    let languages: [String]
    let visibility: HangoutVisibilityOption
    let genderPreference: HangoutGenderPreference
    let isTimeFlexible: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.16),
                    Color.white,
                    accentColor.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accentColor.opacity(0.12))
                .frame(width: 120, height: 120)
                .offset(x: 118, y: -66)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Text(vibeEmoji)
                        Text(vibeTitle.uppercased())
                    }
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())

                    Spacer(minLength: 0)

                    Text(visibility == .inviteOnly ? "PRIVATE CIRCLE" : "OPEN PLAN")
                        .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                        .foregroundColor(visibility == .inviteOnly ? Color(hex: "#7C3AED") : Color(hex: "#10B981"))
                        .padding(.horizontal, 9)
                        .frame(height: 22)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Final preview")
                        .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(previewSubheadline)
                        .font(FriendZoneTheme.Typography.system(10, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    previewPanel(title: "Where", value: placeHeadline, note: locationNote)
                    previewPanel(title: "When", value: whenHeadline, note: whenNote)
                }

                HStack(spacing: 8) {
                    previewPanel(title: "Who", value: whoHeadline, note: whoNote)
                    previewPanel(title: "Language", value: languageHeadline, note: languageNote)
                }
            }
            .padding(12)
        }
        .frame(width: 320, height: 198, alignment: .topLeading)
        .mask(TicketSilhouetteMask())
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: FriendZoneTheme.BorderWidth.thin)
                .mask(TicketSilhouetteMask())
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private func previewPanel(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.7)

            Text(value)
                .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(1)

            Text(note)
                .font(FriendZoneTheme.Typography.system(9, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.82))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var hoursText: String {
        let hours = max(1, Int(ceil(hangout.endAt.timeIntervalSince(hangout.startAt) / 3600)))
        return "\(hours)h plan"
    }

    private var vibeEmoji: String {
        hangout.vibe.emoji
    }

    private var vibeTitle: String {
        hangout.vibe.title
    }

    private var accentColor: Color {
        hangout.vibe.accentColor
    }

    private var locationNote: String {
        let city = hangout.cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !city.isEmpty {
            return "Pinned in \(city)"
        }
        if !locationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Real place confirmed"
        }
        return "Spot confirmed"
    }

    private var whenHeadline: String {
        let calendar = Calendar.current
        let dayMoment = dayMomentLabel(for: hangout.startAt)

        if calendar.isDateInToday(hangout.startAt) {
            return "\(dayMoment.emoji) \(dayMoment.todayTitle)"
        }

        if calendar.isDateInTomorrow(hangout.startAt) {
            return "\(dayMoment.emoji) Tomorrow \(dayMoment.tomorrowSuffix)"
        }

        return "\(dayMoment.emoji) \(hangout.startAt.formatted(.dateTime.weekday(.abbreviated))) \(dayMoment.shortSuffix)"
    }

    private var whenNote: String {
        if isTimeFlexible {
            return "Flexible start · \(hoursText)"
        }
        return "Starts \(hangout.startAt.formatted(.dateTime.hour().minute())) · \(hoursText)"
    }

    private var whoHeadline: String {
        if visibility == .inviteOnly {
            return "🔒 Private circle"
        }

        switch genderPreference {
        case .any:
            return "🌍 Everyone"
        case .womenOnly:
            return "💅 Gurlz only"
        case .menOnly:
            return "🕺 The boyz only"
        }
    }

    private var languageHeadline: String {
        let languageBadges = languages.prefix(2).map(formattedLanguageBadge)
        return languageBadges.isEmpty ? "🗣️ Open" : languageBadges.joined(separator: " · ")
    }

    private var previewSubheadline: String {
        if visibility == .inviteOnly {
            return "Private plan with a quick final check before it goes live."
        }
        return "One last look before this hangout appears in discovery."
    }

    private var placeHeadline: String {
        let place = hangout.locationDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = hangout.cityName.trimmingCharacters(in: .whitespacesAndNewlines)

        if place.isEmpty {
            return city.isEmpty ? "📍 Spot selected" : "📍 In \(city)"
        }

        if city.isEmpty || normalizedPreviewText(place) == normalizedPreviewText(city) {
            return "📍 \(place)"
        }

        return "📍 \(place) in \(city)"
    }

    private var compactLocationAddress: String {
        let raw = locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return hangout.cityName
        }
        if raw.count > 28 {
            return String(raw.prefix(28)) + "..."
        }
        return raw
    }

    private var whoNote: String {
        if visibility == .inviteOnly {
            return audienceSummary.isEmpty ? "Invite code required" : audienceSummary
        }
        let accessLine: String
        switch genderPreference {
        case .any:
            accessLine = "Open to the right crowd"
        case .womenOnly:
            accessLine = "Girls-first energy"
        case .menOnly:
            accessLine = "Boys-only energy"
        }
        return "\(hangout.capacity) spots · \(audienceSummary.isEmpty ? accessLine : audienceSummary)"
    }

    private var languageNote: String {
        languages.isEmpty ? "Optional filter left open" : "Selected for the right crowd"
    }

    private var audienceSummary: String {
        let tags = audienceTags.prefix(2).map(formattedAudienceTag)
        return tags.joined(separator: " · ")
    }

    private func formattedLanguageBadge(_ code: String) -> String {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "en": return "🇬🇧 EN"
        case "es": return "🇪🇸 ES"
        case "de": return "🇩🇪 DE"
        case "fr": return "🇫🇷 FR"
        case "it": return "🇮🇹 IT"
        case "ja": return "🇯🇵 JA"
        default:
            let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "🗣️" : normalized.uppercased()
        }
    }

    private func formattedAudienceTag(_ value: String) -> String {
        guard let tag = HangoutAudienceTagOption(rawValue: value) else {
            return value.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "\(tag.emoji) \(tag.title)"
    }

    private func normalizedPreviewText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func dayMomentLabel(for date: Date) -> (emoji: String, todayTitle: String, tomorrowSuffix: String, shortSuffix: String) {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return ("☀️", "This morning", "morning", "morning")
        case 12..<17:
            return ("🌤️", "This afternoon", "afternoon", "afternoon")
        case 17..<22:
            return ("🌙", "Tonight", "night", "night")
        default:
            return ("🌃", "Late tonight", "late", "late")
        }
    }
}

private struct EmojiChoiceChipGrid: View {
    let items: [EmojiChoiceItem]
    let selectedIDs: Set<String>
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 7)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
            ForEach(items) { item in
                let isSelected = selectedIDs.contains(item.id)
                Button {
                    onTap(item.id)
                } label: {
                    VStack(spacing: 5) {
                        Text(item.emoji)
                            .font(.system(size: 20))

                        Text(item.title)
                            .font(FriendZoneTheme.Typography.system(9, weight: .semibold))
                            .foregroundColor(isSelected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 66)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 7)
                    .background(
                        isSelected
                            ? FriendZoneTheme.Colors.primarySoft
                            : Color.white.opacity(0.92)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(
                                isSelected ? FriendZoneTheme.Colors.primarySoftBorder : Color.black.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .shadow(
                        color: isSelected ? FriendZoneTheme.Colors.primary.opacity(0.10) : Color.black.opacity(0.035),
                        radius: isSelected ? 8 : 3,
                        x: 0,
                        y: isSelected ? 3 : 1
                    )
                    .scaleEffect(isSelected ? 1.02 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct VibeChipGrid: View {
    let vibes: [HangoutCreateVibe]
    let selectedVibe: HangoutCreateVibe
    let onSelect: (HangoutCreateVibe) -> Void

    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 9)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
            ForEach(vibes, id: \.rawValue) { vibe in
                let isSelected = vibe == selectedVibe
                let accent = vibe.accentColor
                Button {
                    onSelect(vibe)
                } label: {
                    VStack(spacing: 7) {
                        Text(vibe.emoji)
                            .font(.system(size: 25))

                        Text(vibe.title)
                            .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                            .foregroundColor(isSelected ? accent : FriendZoneTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 80)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        isSelected
                            ? accent.opacity(0.14)
                            : Color.white.opacity(0.92)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected ? accent.opacity(0.38) : Color.black.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(
                        color: isSelected ? accent.opacity(0.16) : Color.black.opacity(0.04),
                        radius: isSelected ? 10 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                    .scaleEffect(isSelected ? 1.03 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private func prepareCreateHangoutCoverData(_ data: Data) -> Data {
    autoreleasepool {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return data
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: 1600
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return data
        }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return data
        }

        let destinationOptions = [
            kCGImageDestinationLossyCompressionQuality: 0.82
        ] as CFDictionary
        CGImageDestinationAddImage(destination, thumbnail, destinationOptions)

        guard CGImageDestinationFinalize(destination) else {
            return data
        }

        return destinationData as Data
    }
}

#if DEBUG
struct CreateHangoutView_Previews: PreviewProvider {
    static var previews: some View {
        CreateHangoutView(onCancel: {}, onCreated: { _ in })
    }
}
#endif
