import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct CreateHangoutView: View {
    let onCancel: () -> Void
    let onCreate: (CreateHangoutDraft) async throws -> Void

    @State private var draft: CreateHangoutDraft
    @State private var currentStep = 0
    @State private var highlightedFields: Set<ValidationField> = []
    @State private var topErrorMessage: String?
    @State private var isSubmitting = false
    @State private var selectedVibe: CreateHangoutVibeOption = .chill
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedTime = CreateHangoutView.roundedHalfHourTime(from: Date())
    @State private var selectedDuration = 2
    @State private var timeHighlight = false
    @State private var selectedCoverItem: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var miniMapCoordinate: CLLocationCoordinate2D?
    @State private var miniMapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
        span: MKCoordinateSpan(latitudeDelta: 0.028, longitudeDelta: 0.028)
    )

    @FocusState private var focusedField: FocusField?

    private let stepTitles = ["Basics", "Vibe", "Languages", "Where", "When", "Who & How"]
    private let languageOptions = ["English", "Spanish", "German", "French", "Italian", "Portuguese", "Dutch", "Turkish", "Arabic", "Mandarin"]
    private let durationOptions = [1, 2, 3, 4, 6]
    private let audienceTagOptions: [AudienceTagOption] = [
        .init(value: "expats_welcome", label: "🌍 Expats"),
        .init(value: "lgbtq_friendly", label: "🏳️‍🌈 LGBTQ+"),
        .init(value: "students", label: "🎓 Students"),
        .init(value: "professionals", label: "💼 Pros"),
        .init(value: "no_alcohol", label: "🍃 Sober"),
        .init(value: "dog_friendly", label: "🐾 Dogs OK"),
        .init(value: "young_adults", label: "👶 18-25"),
        .init(value: "thirty_plus", label: "🧓 30+")
    ]

    private var isLastStep: Bool {
        currentStep == stepTitles.count - 1
    }

    private var titleLength: Int {
        draft.title.count
    }

    private var descriptionLength: Int {
        draft.description.count
    }

    private var dateOptions: [CreateHangoutDateOption] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0 ..< 14).compactMap { offset in
            guard let target = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let label = target.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            return CreateHangoutDateOption(id: offset, date: target, label: label)
        }
    }

    private var minTimeMinutes: Int {
        guard Calendar.current.isDate(selectedDate, inSameDayAs: Date()) else { return 0 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private var timeOptions: [String] {
        var options: [String] = []
        for hour in 0 ..< 24 {
            for minute in stride(from: 0, to: 60, by: 30) {
                let total = hour * 60 + minute
                if total < minTimeMinutes {
                    continue
                }
                options.append(String(format: "%02d:%02d", hour, minute))
            }
        }
        return options
    }

    private var miniMapMarkers: [CreateHangoutMapMarker] {
        guard let miniMapCoordinate else { return [] }
        return [.init(coordinate: miniMapCoordinate)]
    }

    init(
        onCancel: @escaping () -> Void,
        onCreate: @escaping (CreateHangoutDraft) async throws -> Void,
        initialDraft: CreateHangoutDraft = CreateHangoutDraft()
    ) {
        self.onCancel = onCancel
        self.onCreate = onCreate
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        ZStack {
            FriendZoneTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if draft.sourceType != .hangout {
                    sourceBadge
                        .padding(.horizontal, FriendZoneTheme.Spacing.md)
                        .padding(.top, FriendZoneTheme.Spacing.sm)
                        .padding(.bottom, FriendZoneTheme.Spacing.sm)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        stepMeta

                        if let topErrorMessage {
                            errorBanner(topErrorMessage)
                                .padding(.horizontal, FriendZoneTheme.Spacing.md)
                        }

                        stepContent
                    }
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(FriendZoneTheme.Colors.background)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomComposerDock
        }
        .onAppear {
            selectedDuration = draft.durationHours
            selectedDate = Calendar.current.startOfDay(for: draft.startAt)
            selectedTime = Self.timeString(from: draft.startAt)
            enforceFutureTimeIfNeeded()
            updateMiniMapCoordinate()
        }
        .onChange(of: selectedDate) { _ in
            enforceFutureTimeIfNeeded()
        }
        .onChange(of: selectedCoverItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        coverImageData = data
                        draft.coverImageData = data
                        draft.coverSeed = abs(stableHash(String(data.count))) % 6
                    }
                }
            }
        }
        .onChange(of: draft.locationName) { _ in
            updateMiniMapCoordinate()
        }
        .onChange(of: draft.cityName) { _ in
            updateMiniMapCoordinate()
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel") {
                FriendZoneHaptics.selection()
                onCancel()
            }
            .font(FriendZoneTheme.Typography.system(16, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            Spacer()

            Text("Create a Hangout")
                .font(FriendZoneTheme.Typography.system(17, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Spacer()

            Text("\(currentStep + 1)/\(stepTitles.count)")
                .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
        .padding(.vertical, FriendZoneTheme.Spacing.sm)
        .background(FriendZoneTheme.Colors.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        let tint = sourceTagTint(for: draft.sourceType)
        HStack(spacing: 10) {
            Image(systemName: sourceIcon(for: draft.sourceType))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.sourceType.badgeTitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                    .foregroundColor(tint)

                if let context = draft.sourceLabel, !context.isEmpty {
                    Text(context)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.md, style: .continuous))
    }

    private func sourceTagTint(for sourceType: HangoutSourceType) -> Color {
        switch sourceType {
        case .event: return Color(hex: "#0E7490")
        case .offer: return Color(hex: "#B45309")
        default: return FriendZoneTheme.Colors.primary
        }
    }

    private func sourceIcon(for sourceType: HangoutSourceType) -> String {
        switch sourceType {
        case .event: return "calendar.badge.plus"
        case .offer: return "tag.fill"
        default: return "sparkles"
        }
    }

    private var stepMeta: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stepTitles[currentStep])
                .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.top, 14)
        .padding(.horizontal, FriendZoneTheme.Spacing.lg)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            basicsStep
        case 1:
            vibeStep
        case 2:
            languagesStep
        case 3:
            locationStep
        case 4:
            whenStep
        default:
            whoAndHowStep
        }
    }

    private var basicsStep: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.sm) {
                LargePromptInput(
                    text: $draft.title,
                    placeholder: "What's the plan?",
                    minHeight: 86,
                    font: FriendZoneTheme.Typography.system(32, weight: .bold),
                    textColor: FriendZoneTheme.Colors.textPrimary,
                    placeholderColor: Color.black.opacity(0.15)
                )
                .focused($focusedField, equals: .title)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(hasError(.title) ? Color(hex: "#EF4444") : Color.clear, lineWidth: 1.5)
                }

                Text("\(titleLength)/120")
                    .font(FriendZoneTheme.Typography.system(12, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let message = fieldErrorMessage(.title) {
                    fieldError(message)
                }

                LargePromptInput(
                    text: $draft.description,
                    placeholder: "Add more details... What should people expect?",
                    minHeight: 104,
                    font: FriendZoneTheme.Typography.system(15, weight: .regular),
                    textColor: FriendZoneTheme.Colors.textSecondary,
                    placeholderColor: Color.black.opacity(0.24)
                )
                .focused($focusedField, equals: .description)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(hasError(.description) ? Color(hex: "#EF4444") : Color.clear, lineWidth: 1.5)
                }

                Text("\(descriptionLength)/500")
                    .font(FriendZoneTheme.Typography.system(12, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let message = fieldErrorMessage(.description) {
                    fieldError(message)
                }
            }
            .padding(.horizontal, FriendZoneTheme.Spacing.lg)
            .padding(.vertical, FriendZoneTheme.Spacing.xl)
            .background(FriendZoneTheme.Colors.surface)
            .overlay {
                if hasError(.title) || hasError(.description) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(hex: "#EF4444").opacity(0.06))
                }
            }

            formSection(title: "COVER PHOTO", optionalTitle: "(optional)") {
                VStack(spacing: 10) {
                    if let image = coverUIImage {
                        ZStack(alignment: .topTrailing) {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Button {
                                coverImageData = nil
                                draft.coverImageData = nil
                                selectedCoverItem = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.black.opacity(0.62))
                                    .clipShape(Circle())
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        PhotosPicker(selection: $selectedCoverItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Add Cover Photo")
                                    .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                            }
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black.opacity(0.02))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(Color.black.opacity(0.12))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var vibeStep: some View {
        formSection(title: "THE VIBE") {
            FlexibleChips(
                data: CreateHangoutVibeOption.allCases,
                minimumWidth: 104,
                content: { option in
                    vibeChip(option)
                },
                onTap: { option in
                    selectedVibe = option
                    draft.vibe = option.modelValue
                    FriendZoneHaptics.selection()
                }
            )
        }
    }

    private var languagesStep: some View {
        formSection(title: "LANGUAGES", optionalTitle: "(optional)", highlighted: hasError(.languages)) {
            VStack(alignment: .leading, spacing: 10) {
                FlexibleChips(
                    data: languageOptions,
                    minimumWidth: 96,
                    content: { language in
                        languageChip(language)
                    },
                    onTap: { language in
                        if draft.languages.contains(language) {
                            draft.languages.removeAll { $0 == language }
                        } else if draft.languages.count < 3 {
                            draft.languages.append(language)
                        }
                        FriendZoneHaptics.selection()
                    }
                )

                if draft.languages.isEmpty, !hasError(.languages) {
                    emptyHint("Optional: add up to 3 languages")
                }

                if let message = fieldErrorMessage(.languages) {
                    fieldError(message)
                }
            }
        }
    }

    private var locationStep: some View {
        formSection(title: "WHERE", required: true, highlighted: hasError(.location)) {
            VStack(alignment: .leading, spacing: 10) {
                privacyNote

                VStack(alignment: .leading, spacing: 6) {
                    inputLabel("Location", required: true)

                    TextField("Search for a place...", text: $draft.locationName)
                        .focused($focusedField, equals: .location)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(hasError(.location) ? Color(hex: "#EF4444") : Color.black.opacity(0.10), lineWidth: 1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    TextField("Address (optional)", text: $draft.locationAddress)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(FriendZoneTheme.Colors.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    TextField("City", text: $draft.cityName)
                        .focused($focusedField, equals: .city)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(FriendZoneTheme.Colors.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(hasError(.location) ? Color(hex: "#EF4444") : Color.black.opacity(0.08), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !draft.cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    Text("Selected: \(draft.locationName) | \(draft.cityName)")
                        .font(FriendZoneTheme.Typography.system(12, weight: .regular))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                } else if !hasError(.location) {
                    emptyHint("Search and select a specific place")
                }

                if let message = fieldErrorMessage(.location) {
                    fieldError(message)
                }

                if miniMapCoordinate != nil {
                    ZStack {
                        Map(coordinateRegion: $miniMapRegion, annotationItems: miniMapMarkers) { marker in
                            MapAnnotation(coordinate: marker.coordinate) {
                                Circle()
                                    .fill(FriendZoneTheme.Colors.primary)
                                    .frame(width: 14, height: 14)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    }
                                    .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.28), radius: 8, x: 0, y: 3)
                            }
                        }
                        .allowsHitTesting(false)

                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .frame(height: 166)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                }
            }
        }
    }

    private var whenStep: some View {
        formSection(title: "WHEN", highlighted: hasError(.dateTime) || timeHighlight) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    timeFlexibilityButton(title: "Exact time", active: !draft.isTimeFlexible) {
                        draft.isTimeFlexible = false
                    }
                    timeFlexibilityButton(title: "I am flexible", active: draft.isTimeFlexible) {
                        draft.isTimeFlexible = true
                    }
                }
                .padding(4)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 8) {
                    quickDateButton("Today", daysFromNow: 0)
                    quickDateButton("Tomorrow", daysFromNow: 1)
                    quickDateButton("Day After", daysFromNow: 2)
                }

                pickerColumn(
                    title: "Date",
                    highlighted: false,
                    content: {
                        ForEach(dateOptions) { option in
                            pickerOption(
                                title: option.label,
                                active: Calendar.current.isDate(option.date, inSameDayAs: selectedDate),
                                emphasize: false
                            ) {
                                selectedDate = option.date
                            }
                        }
                    }
                )

                HStack(alignment: .top, spacing: 10) {
                    if !draft.isTimeFlexible {
                        pickerColumn(
                            title: "Time",
                            highlighted: timeHighlight,
                            content: {
                                ForEach(timeOptions, id: \.self) { value in
                                    pickerOption(
                                        title: value,
                                        active: selectedTime == value,
                                        emphasize: true
                                    ) {
                                        applyTime(value)
                                    }
                                }
                            }
                        )
                    }

                    pickerColumn(
                        title: "Duration",
                        highlighted: false,
                        content: {
                            ForEach(durationOptions, id: \.self) { duration in
                                pickerOption(
                                    title: "\(duration)h",
                                    active: selectedDuration == duration,
                                    emphasize: true
                                ) {
                                    selectedDuration = duration
                                    FriendZoneHaptics.selection()
                                }
                            }
                        }
                    )
                }

                if draft.isTimeFlexible {
                    emptyHint("Only date is fixed. Exact time stays flexible.")
                }

                if let message = fieldErrorMessage(.dateTime) {
                    fieldError(message)
                }
            }
        }
    }

    private var whoAndHowStep: some View {
        formSection(title: "WHO & HOW") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 12) {
                    capacityRow
                    peopleLimitRow
                    visibilityRow
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("AUDIENCE")
                        .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(1)
                        .padding(.top, FriendZoneTheme.Spacing.md)

                    HStack(spacing: 8) {
                        audienceButton("👥 Everyone", option: .any)
                        audienceButton("💃 Women only", option: .womenOnly)
                        audienceButton("♟ Men only", option: .menOnly)
                    }

                    Text("Optional tags (max 5)")
                        .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .textCase(.uppercase)

                    FlexibleChips(
                        data: audienceTagOptions,
                        minimumWidth: 112,
                        content: { option in
                            audienceTagChip(option)
                        },
                        onTap: { option in
                            toggleAudienceTag(option.value)
                        }
                    )
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 1)
                        .padding(.top, -14)
                }

                if draft.visibility == .inviteOnly {
                    VStack(alignment: .leading, spacing: 6) {
                        inputLabel("Invite Code", required: true)

                        TextField("Create a code", text: $draft.inviteCode)
                            .focused($focusedField, equals: .inviteCode)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .kerning(1)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(FriendZoneTheme.Colors.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(hasError(.inviteCode) ? Color(hex: "#EF4444") : Color.black.opacity(0.10), lineWidth: 1.5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text("Share this code with people you invite")
                            .font(FriendZoneTheme.Typography.system(12, weight: .regular))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                        if let message = fieldErrorMessage(.inviteCode) {
                            fieldError(message)
                        }
                    }
                    .padding(FriendZoneTheme.Spacing.md)
                    .background(FriendZoneTheme.Colors.primary.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .foregroundColor(FriendZoneTheme.Colors.primary.opacity(0.30))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var bottomComposerDock: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)

            VStack(spacing: 0) {
                livePreviewSection
                stepControls
            }
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(FriendZoneTheme.Colors.surface)
        }
        .background(FriendZoneTheme.Colors.surface)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: -3)
    }

    private var livePreviewSection: some View {
        formSection(title: "LIVE PREVIEW") {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(previewAccentColor)

                        Text("HANGOUT TICKET")
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .tracking(0.7)
                    }
                    .padding(.bottom, 7)

                    Text(previewTitleText)
                        .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 4)

                    Text(previewDescriptionText)
                        .font(FriendZoneTheme.Typography.system(11, weight: .regular))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .padding(.bottom, 8)

                    HStack(spacing: 8) {
                        Text(previewVisibilityLabel)
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(previewAccentColor)

                        Text("•")
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                        Text("TBA")
                            .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    ForEach(0 ..< 14, id: \.self) { _ in
                        Circle()
                            .fill(FriendZoneTheme.Colors.borderSubtle.opacity(0.95))
                            .frame(width: 2.2, height: 2.2)
                    }
                }
                .frame(width: 3)
                .padding(.horizontal, 8)

                VStack(spacing: 4) {
                    Text(previewCountdownText)
                        .font(FriendZoneTheme.Typography.system(14, weight: .heavy))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(previewAccentColor.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(previewAccentColor.opacity(0.28), lineWidth: 1)
                        }

                    Text(previewTimeLabel)
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(previewDateLabel)
                        .font(FriendZoneTheme.Typography.system(9, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(previewSpotsLabel)
                        .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                        .foregroundColor(previewSpotsColor)
                        .padding(.top, 1)

                    previewTicketBarcode

                    Text(previewTicketCode)
                        .font(FriendZoneTheme.Typography.system(8, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
                .frame(width: 74)
            }
            .padding(.horizontal, 12)
            .background(FriendZoneTheme.Colors.surface)
            .mask(livePreviewClipMask)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
                    .mask(livePreviewClipMask)
            }
        }
    }

    private var livePreviewClipMask: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white)
            .overlay {
                livePreviewPunchHoles
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    private var livePreviewPunchHoles: some View {
        GeometryReader { proxy in
            let sideRadius: CGFloat = 4.2
            let centerRadius: CGFloat = 8
            let centerX = proxy.size.width * 0.5
            let topInset: CGFloat = 10
            let bottomInset: CGFloat = 10
            let count = 8
            let usableHeight = max(0, proxy.size.height - topInset - bottomInset)
            let step = usableHeight / CGFloat(max(1, count - 1))

            ZStack {
                ForEach(0 ..< count, id: \.self) { index in
                    let y = topInset + CGFloat(index) * step

                    Circle()
                        .fill(Color.black)
                        .frame(width: sideRadius * 2, height: sideRadius * 2)
                        .position(x: 0, y: y)

                    Circle()
                        .fill(Color.black)
                        .frame(width: sideRadius * 2, height: sideRadius * 2)
                        .position(x: proxy.size.width, y: y)
                }

                Circle()
                    .fill(Color.black)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: centerX, y: 0)

                Circle()
                    .fill(Color.black)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: centerX, y: proxy.size.height)
            }
        }
    }

    private var previewTicketBarcode: some View {
        HStack(alignment: .bottom, spacing: 0.8) {
            ForEach(Array(previewBarcodeBars.enumerated()), id: \.offset) { _, bar in
                Rectangle()
                    .fill(Color.black.opacity(bar.opacity))
                    .frame(width: bar.width, height: bar.height)
            }
        }
        .frame(height: 24, alignment: .bottom)
    }

    private var capacityRow: some View {
        HStack {
            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                Text("People")
                    .font(.system(size: 20))
                Text("Capacity")
                    .font(FriendZoneTheme.Typography.system(14, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: FriendZoneTheme.Spacing.md) {
                roundStepButton(symbol: "minus", disabled: draft.isCapacityUnlimited || draft.capacity <= 2) {
                    draft.capacity = max(2, draft.capacity - 1)
                }

                Text(draft.isCapacityUnlimited ? "∞" : "\(draft.capacity)")
                    .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .frame(minWidth: 24)

                roundStepButton(symbol: "plus", disabled: draft.isCapacityUnlimited || draft.capacity >= 20) {
                    draft.capacity = min(20, draft.capacity + 1)
                }
            }
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(Color.black.opacity(0.02))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var peopleLimitRow: some View {
        HStack {
            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                Text("Limit")
                    .font(.system(size: 20))
                Text("People limit")
                    .font(FriendZoneTheme.Typography.system(14, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                peopleLimitButton(title: "Limited", active: !draft.isCapacityUnlimited) {
                    draft.isCapacityUnlimited = false
                }
                peopleLimitButton(title: "Unlimited", active: draft.isCapacityUnlimited) {
                    draft.isCapacityUnlimited = true
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(Color.black.opacity(0.02))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var visibilityRow: some View {
        HStack {
            HStack(spacing: FriendZoneTheme.Spacing.sm) {
                Text("Visibility")
                    .font(.system(size: 20))
                Text("Visibility")
                    .font(FriendZoneTheme.Typography.system(14, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                visibilityButton(.public, label: "Public")
                visibilityButton(.inviteOnly, label: "Private")
            }
            .padding(4)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(Color.black.opacity(0.02))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stepControls: some View {
        HStack(spacing: 10) {
            Button {
                handlePrevStep()
            } label: {
                Text("Back")
                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(currentStep == 0 ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .disabled(currentStep == 0 || isSubmitting)

            Button {
                handleNextStep()
            } label: {
                Text(isSubmitting ? "Creating..." : (isLastStep ? "Post Hangout" : "Next"))
                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.28), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
        }
        .padding(.top, 6)
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
    }

    private func formSection<Content: View>(
        title: String,
        optionalTitle: String? = nil,
        required: Bool = false,
        highlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FriendZoneTheme.Spacing.md) {
            HStack(spacing: 4) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1)

                if let optionalTitle {
                    Text(optionalTitle)
                        .font(FriendZoneTheme.Typography.system(10, weight: .regular))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }

                if required {
                    Text("*")
                        .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                        .foregroundColor(Color(hex: "#EF4444"))
                }
            }

            content()
        }
        .padding(FriendZoneTheme.Spacing.lg)
        .background(FriendZoneTheme.Colors.surface)
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "#FCA5A5"), lineWidth: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, FriendZoneTheme.Spacing.md)
    }

    private func vibeChip(_ option: CreateHangoutVibeOption) -> some View {
        Text(option.title)
            .font(FriendZoneTheme.Typography.system(14, weight: .medium))
            .foregroundColor(selectedVibe == option ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(selectedVibe == option ? FriendZoneTheme.Colors.primary : Color.black.opacity(0.04))
            .overlay {
                Capsule()
                    .stroke(selectedVibe == option ? FriendZoneTheme.Colors.primary : Color.black.opacity(0.08), lineWidth: 1.5)
            }
            .clipShape(Capsule())
            .shadow(color: selectedVibe == option ? FriendZoneTheme.Colors.primary.opacity(0.28) : .clear, radius: 6, x: 0, y: 3)
    }

    private func languageChip(_ language: String) -> some View {
        let selected = draft.languages.contains(language)
        return Text(language)
            .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
            .foregroundColor(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(selected ? FriendZoneTheme.Colors.primarySoft : FriendZoneTheme.Colors.surface)
            .overlay {
                Capsule()
                    .stroke(selected ? FriendZoneTheme.Colors.primarySoftBorder : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
            }
            .clipShape(Capsule())
    }

    private func audienceTagChip(_ option: AudienceTagOption) -> some View {
        let selected = draft.audienceTags.contains(option.value)
        return Text(option.label)
            .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
            .foregroundColor(selected ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.surface)
            .overlay {
                Capsule()
                    .stroke(selected ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
            }
            .clipShape(Capsule())
    }

    private var privacyNote: some View {
        Text("Your exact location stays private. It is only shared with people after you accept them.")
            .font(FriendZoneTheme.Typography.system(12, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .lineSpacing(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(FriendZoneTheme.Colors.primary.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.primary.opacity(0.16), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func inputLabel(_ title: String, required: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            if required {
                Text("*")
                    .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                    .foregroundColor(Color(hex: "#EF4444"))
            }
        }
    }

    private func fieldError(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#DC2626"))
            Text("Warning: \(message)")
                .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                .foregroundColor(Color(hex: "#DC2626"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: "#EF4444").opacity(0.08))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(hex: "#EF4444"))
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func emptyHint(_ message: String) -> some View {
        Text(message)
            .font(FriendZoneTheme.Typography.system(13, weight: .regular))
            .foregroundColor(FriendZoneTheme.Colors.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(FriendZoneTheme.Colors.primary.opacity(0.05))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(FriendZoneTheme.Colors.primary)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func quickDateButton(_ title: String, daysFromNow: Int) -> some View {
        let active = isQuickDateActive(daysFromNow: daysFromNow)
        return Button {
            applyQuickDate(daysFromNow: daysFromNow)
        } label: {
            Text(title)
                .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                .foregroundColor(active ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    active
                        ? LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary.opacity(0.14), FriendZoneTheme.Colors.primaryAccent.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [Color.white.opacity(0.92), Color.white.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                )
                .overlay {
                    Capsule()
                        .stroke(active ? FriendZoneTheme.Colors.primary.opacity(0.36) : Color.black.opacity(0.12), lineWidth: 1)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func pickerColumn<Content: View>(title: String, highlighted: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    content()
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.02), Color.black.opacity(0.01)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(highlighted ? FriendZoneTheme.Colors.primary.opacity(0.28) : Color.black.opacity(0.08), lineWidth: highlighted ? 1.5 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pickerOption(title: String, active: Bool, emphasize: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            FriendZoneHaptics.selection()
        } label: {
            Text(title)
                .font(FriendZoneTheme.Typography.system(14, weight: emphasize ? .bold : .semibold))
                .foregroundColor(active ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: emphasize ? 40 : 38)
                .background(
                    active
                        ? LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary.opacity(0.16), FriendZoneTheme.Colors.primaryAccent.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [Color.white.opacity(0.90), Color.white.opacity(0.90)], startPoint: .top, endPoint: .bottom)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(active ? FriendZoneTheme.Colors.primary.opacity(0.32) : Color.clear, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: active ? FriendZoneTheme.Colors.primary.opacity(0.12) : .clear, radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func roundStepButton(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            FriendZoneHaptics.selection()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
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
        .opacity(disabled ? 0.30 : 1)
        .disabled(disabled)
    }

    private func visibilityButton(_ option: HangoutVisibilityOption, label: String) -> some View {
        let active = draft.visibility == option
        return Button {
            draft.visibility = option
            if option == .public {
                draft.inviteCode = ""
            }
            FriendZoneHaptics.selection()
        } label: {
            Text(label)
                .font(FriendZoneTheme.Typography.system(13, weight: active ? .semibold : .medium))
                .foregroundColor(active ? FriendZoneTheme.Colors.textPrimary : FriendZoneTheme.Colors.textSecondary)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(active ? FriendZoneTheme.Colors.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: active ? Color.black.opacity(0.10) : .clear, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func timeFlexibilityButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            FriendZoneHaptics.selection()
        } label: {
            Text(title)
                .font(FriendZoneTheme.Typography.system(13, weight: active ? .semibold : .medium))
                .foregroundColor(active ? FriendZoneTheme.Colors.textPrimary : FriendZoneTheme.Colors.textSecondary)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .background(active ? FriendZoneTheme.Colors.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: active ? Color.black.opacity(0.10) : .clear, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func peopleLimitButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            FriendZoneHaptics.selection()
        } label: {
            Text(title)
                .font(FriendZoneTheme.Typography.system(13, weight: active ? .semibold : .medium))
                .foregroundColor(active ? FriendZoneTheme.Colors.textPrimary : FriendZoneTheme.Colors.textSecondary)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(active ? FriendZoneTheme.Colors.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: active ? Color.black.opacity(0.10) : .clear, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func audienceButton(_ title: String, option: HangoutGenderPreference) -> some View {
        let active = draft.genderPreference == option
        return Button {
            draft.genderPreference = option
            FriendZoneHaptics.selection()
        } label: {
            Text(title)
                .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                .foregroundColor(active ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    active
                        ? LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary.opacity(0.14), FriendZoneTheme.Colors.primaryAccent.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [FriendZoneTheme.Colors.surface, FriendZoneTheme.Colors.surface], startPoint: .top, endPoint: .bottom)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(active ? FriendZoneTheme.Colors.primary.opacity(0.40) : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "#991B1B"))
                .padding(.top, 1)

            Text(message)
                .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                .foregroundColor(Color(hex: "#B91C1C"))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(FriendZoneTheme.Spacing.md)
        .background(Color(hex: "#FEF2F2"))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "#FCA5A5"), lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var previewTitleText: String {
        let value = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Your hangout title" : value
    }

    private var previewDescriptionText: String {
        let value = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Add details to see your live ticket preview." : value
    }

    private var previewVisibilityLabel: String {
        draft.visibility == .public ? "PUBLIC" : "PRIVATE"
    }

    private var previewCityCode: String {
        let normalized = draft.cityName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let knownCodes: [String: String] = [
            "munich": "MUC",
            "munchen": "MUC",
            "münchen": "MUC",
            "berlin": "BER",
            "madrid": "MAD",
            "barcelona": "BCN",
            "paris": "PAR",
            "london": "LON",
            "lisbon": "LIS",
            "rome": "ROM",
            "amsterdam": "AMS",
            "new york": "NYC",
            "los angeles": "LAX",
            "miami": "MIA"
        ]
        if let code = knownCodes[normalized] {
            return code
        }
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        if compact.isEmpty {
            return "CITY"
        }
        return String(compact.prefix(3)).uppercased()
    }

    private var previewStartAt: Date {
        composeStartDate() ?? Date().addingTimeInterval(60 * 60)
    }

    private var previewTimeLabel: String {
        if draft.isTimeFlexible {
            return "Flexible"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: previewStartAt)
    }

    private var previewDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: previewStartAt).uppercased()
    }

    private var previewSpotsLeft: Int? {
        if draft.isCapacityUnlimited {
            return nil
        }
        return max(0, draft.capacity - 1)
    }

    private var previewSpotsLabel: String {
        guard let previewSpotsLeft else { return "Unlimited" }
        return previewSpotsLeft > 0 ? "\(previewSpotsLeft) Left" : "Full"
    }

    private var previewSpotsColor: Color {
        guard let previewSpotsLeft else { return previewAccentColor }
        return previewSpotsLeft > 0 ? previewAccentColor : FriendZoneTheme.Colors.error
    }

    private var previewTicketCode: String {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: previewStartAt)
        let day = String(format: "%02d", components.day ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let year = String(components.year ?? 0)
        return "\(previewCityCode)-\(day)-\(month)-000-\(year)"
    }

    private var previewBarcodeBars: [(width: CGFloat, height: CGFloat, opacity: CGFloat)] {
        let base = "\(previewTicketCode)|\(previewStartAt.timeIntervalSince1970)|\(previewTitleText)"
        var result: [(width: CGFloat, height: CGFloat, opacity: CGFloat)] = []
        let widths: [CGFloat] = [0.8, 1.2, 1.6]

        result.append((1.8, 24, 0.9))
        result.append((0.8, 18, 0.88))
        result.append((1.8, 24, 0.9))

        for (index, byte) in base.utf8.prefix(28).enumerated() {
            let value = Int(byte)
            let width = widths[value % widths.count]
            let height: CGFloat
            switch value % 5 {
            case 0: height = 24
            case 1: height = 22
            case 2: height = 20
            case 3: height = 23
            default: height = 21
            }
            let opacity: CGFloat = index.isMultiple(of: 7) ? 0.95 : 0.88
            result.append((width, height, opacity))

            if index == 13 {
                result.append((1.8, 24, 0.9))
                result.append((0.8, 18, 0.88))
                result.append((1.8, 24, 0.9))
            }
        }

        result.append((1.8, 24, 0.9))
        result.append((0.8, 18, 0.88))
        result.append((1.8, 24, 0.9))

        while result.count < 40 {
            result.append((1.0, 20, 0.85))
        }
        return result
    }

    private var previewCountdownText: String {
        if draft.isTimeFlexible {
            return "FLEX"
        }
        let diff = Int(previewStartAt.timeIntervalSince(Date()))
        if diff <= 0 { return "NOW" }
        let minutes = diff / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    private var previewAccentColor: Color {
        switch selectedVibe {
        case .chill, .social:
            return Color(hex: "#667EEA")
        case .party, .drinks:
            return Color(hex: "#F59E0B")
        case .creative, .outdoors, .boardGames:
            return Color(hex: "#10B981")
        case .deepTalks:
            return Color(hex: "#8B5CF6")
        case .culture:
            return Color(hex: "#EF4444")
        case .sporty:
            return Color(hex: "#0EA5E9")
        }
    }

    private var coverUIImage: Image? {
        guard let coverImageData, let uiImage = UIImage(data: coverImageData) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private var progressFraction: CGFloat {
        CGFloat(currentStep + 1) / CGFloat(stepTitles.count)
    }

    private func handleNextStep() {
        let errors = stepErrors(for: currentStep)
        guard errors.isEmpty else {
            highlightedFields = Set(errors.map(\.field))
            topErrorMessage = errors[0].message
            focusedField = errors[0].focus
            FriendZoneHaptics.lightImpact()
            return
        }

        highlightedFields.removeAll()
        topErrorMessage = nil

        if isLastStep {
            Task { await submit() }
            return
        }

        withAnimation(FriendZoneTheme.Motion.easeOutExpo) {
            currentStep += 1
        }
    }

    private func handlePrevStep() {
        guard currentStep > 0 else { return }
        highlightedFields.removeAll()
        topErrorMessage = nil

        withAnimation(FriendZoneTheme.Motion.easeOutExpo) {
            currentStep -= 1
        }
    }

    @MainActor
    private func submit() async {
        let errors = validationErrors()
        guard errors.isEmpty else {
            highlightedFields = Set(errors.map(\.field))
            topErrorMessage = errors[0].message
            focusedField = errors[0].focus
            FriendZoneHaptics.lightImpact()
            return
        }

        guard let startAt = composeStartDate() else {
            topErrorMessage = "Could not build a valid start time."
            FriendZoneHaptics.lightImpact()
            return
        }

        isSubmitting = true

        draft.startAt = startAt
        draft.durationHours = selectedDuration
        draft.vibe = selectedVibe.modelValue
        draft.cityPlaceID = draft.cityName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "-")
        draft.isLive = false
        draft.isMicro = false
        draft.coverImageData = coverImageData

        do {
            try await onCreate(draft)
            FriendZoneHaptics.success()
            isSubmitting = false
            onCancel()
        } catch {
            isSubmitting = false
            topErrorMessage = error.localizedDescription
            FriendZoneHaptics.lightImpact()
        }
    }

    private func stepErrors(for step: Int) -> [ValidationError] {
        let all = validationErrors()
        switch step {
        case 0:
            return all.filter { $0.field == .title || $0.field == .description }
        case 2:
            return all.filter { $0.field == .languages }
        case 3:
            return all.filter { $0.field == .location }
        case 4:
            return all.filter { $0.field == .dateTime }
        case 5:
            return all.filter { $0.field == .inviteCode }
        default:
            return []
        }
    }

    private func validationErrors() -> [ValidationError] {
        var errors: [ValidationError] = []

        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            errors.append(.init(field: .title, message: "Title must be at least 3 characters", focus: .title))
        }

        if draft.description.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
            errors.append(.init(field: .description, message: "Description must be at least 10 characters", focus: .description))
        }

        if draft.languages.count > 3 {
            errors.append(.init(field: .languages, message: "Maximum 3 languages allowed", focus: nil))
        }

        if draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.init(field: .location, message: "Select a specific place", focus: .location))
        }

        if draft.isTimeFlexible {
            if !isFlexibleDateValid() {
                errors.append(.init(field: .dateTime, message: "Cannot be in the past", focus: nil))
            }
        } else if !isDateTimeInFuture() {
            errors.append(.init(field: .dateTime, message: "Cannot be in the past", focus: nil))
        }

        if draft.visibility == .inviteOnly,
           draft.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            errors.append(.init(field: .inviteCode, message: "Required for private hangouts", focus: .inviteCode))
        }

        return errors
    }

    private func hasError(_ field: ValidationField) -> Bool {
        highlightedFields.contains(field)
    }

    private func fieldErrorMessage(_ field: ValidationField) -> String? {
        guard highlightedFields.contains(field) else { return nil }
        return validationErrors().first(where: { $0.field == field })?.message
    }

    private func toggleAudienceTag(_ value: String) {
        if draft.audienceTags.contains(value) {
            draft.audienceTags.removeAll { $0 == value }
        } else if draft.audienceTags.count < 5 {
            draft.audienceTags.append(value)
        }
        FriendZoneHaptics.selection()
    }

    private func applyQuickDate(daysFromNow: Int) {
        guard let target = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Calendar.current.startOfDay(for: Date())) else {
            return
        }
        selectedDate = target
        FriendZoneHaptics.selection()
    }

    private func isQuickDateActive(daysFromNow: Int) -> Bool {
        guard let target = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Calendar.current.startOfDay(for: Date())) else {
            return false
        }
        return Calendar.current.isDate(target, inSameDayAs: selectedDate)
    }

    private func applyTime(_ value: String) {
        selectedTime = value
        withAnimation(.easeInOut(duration: 0.18)) {
            timeHighlight = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeInOut(duration: 0.2)) {
                timeHighlight = false
            }
        }
    }

    private func enforceFutureTimeIfNeeded() {
        if !timeOptions.contains(selectedTime), let first = timeOptions.first {
            selectedTime = first
        }
    }

    private func composeStartDate() -> Date? {
        if draft.isTimeFlexible {
            return composeFlexibleStartDate()
        }

        let chunks = selectedTime.split(separator: ":")
        guard chunks.count == 2,
              let hour = Int(chunks[0]),
              let minute = Int(chunks[1])
        else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Calendar.current.startOfDay(for: selectedDate)
        )
    }

    private func composeFlexibleStartDate() -> Date? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let todayStart = calendar.startOfDay(for: Date())

        guard dayStart >= todayStart else { return nil }

        if dayStart > todayStart {
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)
        }

        let minimumStart = Date().addingTimeInterval(30 * 60)
        return roundUpToHalfHour(minimumStart)
    }

    private func isDateTimeInFuture() -> Bool {
        guard let selected = composeStartDate() else { return false }
        return selected > Date()
    }

    private func isFlexibleDateValid() -> Bool {
        Calendar.current.startOfDay(for: selectedDate) >= Calendar.current.startOfDay(for: Date())
    }

    private func roundUpToHalfHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        var hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let roundedMinute: Int

        if minute == 0 || minute == 30 {
            roundedMinute = minute
        } else if minute < 30 {
            roundedMinute = 30
        } else {
            roundedMinute = 0
            hour += 1
        }

        components.hour = hour
        components.minute = roundedMinute
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    private func updateMiniMapCoordinate() {
        let location = draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = draft.cityName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !location.isEmpty, !city.isEmpty else {
            miniMapCoordinate = nil
            draft.latitude = nil
            draft.longitude = nil
            return
        }

        let hash = stableHash("\(location)|\(city)")
        let latOffset = Double(hash % 5000) / 100_000.0 - 0.025
        let lngOffset = Double((hash / 5000) % 5000) / 100_000.0 - 0.025

        let coordinate = CLLocationCoordinate2D(
            latitude: 52.52 + latOffset,
            longitude: 13.405 + lngOffset
        )

        miniMapCoordinate = coordinate
        miniMapRegion.center = coordinate
        draft.latitude = coordinate.latitude
        draft.longitude = coordinate.longitude
    }

    private func stableHash(_ input: String) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash & 0x7FFF_FFFF)
    }

    private static func roundedHalfHourTime(from date: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = .current

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        if minute < 30 {
            return String(format: "%02d:30", hour)
        }

        return String(format: "%02d:00", (hour + 1) % 24)
    }

    private static func timeString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }
}

private enum FocusField: Hashable {
    case title
    case description
    case location
    case city
    case inviteCode
}

private enum ValidationField: Hashable {
    case title
    case description
    case languages
    case location
    case dateTime
    case inviteCode
}

private struct ValidationError {
    let field: ValidationField
    let message: String
    let focus: FocusField?
}

private struct AudienceTagOption: Hashable {
    let value: String
    let label: String
}

private struct CreateHangoutDateOption: Identifiable {
    let id: Int
    let date: Date
    let label: String
}

private struct CreateHangoutMapMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private enum CreateHangoutVibeOption: String, CaseIterable, Hashable {
    case chill
    case social
    case party
    case creative
    case outdoors
    case drinks
    case deepTalks
    case boardGames
    case culture
    case sporty

    var title: String {
        switch self {
        case .chill: return "Chill"
        case .social: return "Social"
        case .party: return "Party"
        case .creative: return "Creative"
        case .outdoors: return "Outdoors"
        case .drinks: return "Drinks"
        case .deepTalks: return "Deep talks"
        case .boardGames: return "Board games"
        case .culture: return "Culture"
        case .sporty: return "Sporty"
        }
    }

    var modelValue: HangoutVibe {
        switch self {
        case .chill, .social:
            return .chill
        case .party, .drinks:
            return .drinks
        case .creative, .outdoors, .boardGames:
            return .activity
        case .deepTalks:
            return .deepTalk
        case .culture:
            return .foodie
        case .sporty:
            return .sporty
        }
    }
}

private struct LargePromptInput: View {
    @Binding var text: String

    let placeholder: String
    let minHeight: CGFloat
    let font: Font
    let textColor: Color
    let placeholderColor: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundColor(placeholderColor)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }

            TextEditor(text: $text)
                .font(font)
                .foregroundColor(textColor)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: minHeight)
                .padding(.horizontal, -4)
                .padding(.vertical, -8)
        }
    }
}

private struct FlexibleChips<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let minimumWidth: CGFloat
    let content: (Data.Element) -> Content
    let onTap: (Data.Element) -> Void

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(data), id: \.self) { element in
                Button {
                    onTap(element)
                } label: {
                    content(element)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#if DEBUG
struct CreateHangoutView_Previews: PreviewProvider {
    static var previews: some View {
        CreateHangoutView(onCancel: {}, onCreate: { _ in })
    }
}
#endif
