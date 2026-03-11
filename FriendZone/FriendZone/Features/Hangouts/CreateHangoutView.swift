import Combine
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CreateHangoutView: View {
    let onCancel: () -> Void
    let onCreate: (CreateHangoutSubmission) async throws -> Void

    @State private var title: String
    @State private var description: String
    @State private var cityName: String
    @State private var locationName: String
    @State private var locationAddress: String
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var durationHours: Int
    @State private var capacity: Int
    @State private var selectedVibe: HangoutVibe
    @State private var selectedLanguages: [String]
    @State private var selectedCoverItem: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var coverLoadTask: Task<Void, Never>?
    @State private var submissionTask: Task<Void, Never>?
    @StateObject private var submissionState = CreateHangoutSubmissionState()

    private let sourceType: HangoutSourceType
    private let sourceLabel: String?
    private let sourceEventID: Int?
    private let sourceOfferID: Int?
    private let initialCityPlaceID: String

    private let supportedLanguages: [(label: String, code: String)] = [
        ("English", "en"),
        ("Spanish", "es"),
        ("German", "de"),
        ("French", "fr"),
        ("Italian", "it"),
        ("Japanese", "ja")
    ]

    private let supportedDurations = [1, 2, 3, 4, 6]
    private let supportedCapacities = Array(2 ... 12)
    private let supportedVibes: [HangoutVibe] = [.chill, .drinks, .deepTalk, .activity, .foodie, .sporty]

    init(
        onCancel: @escaping () -> Void,
        onCreate: @escaping (CreateHangoutSubmission) async throws -> Void,
        initialDraft: CreateHangoutDraft = CreateHangoutDraft()
    ) {
        self.onCancel = onCancel
        self.onCreate = onCreate
        self.sourceType = initialDraft.sourceType
        self.sourceLabel = initialDraft.sourceLabel
        self.sourceEventID = initialDraft.sourceEventID
        self.sourceOfferID = initialDraft.sourceOfferID
        self.initialCityPlaceID = initialDraft.cityPlaceID.trimmingCharacters(in: .whitespacesAndNewlines)

        _title = State(initialValue: initialDraft.title)
        _description = State(initialValue: initialDraft.description)
        _cityName = State(initialValue: initialDraft.cityName)
        _locationName = State(initialValue: initialDraft.locationName)
        _locationAddress = State(initialValue: initialDraft.locationAddress)
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDraft.startAt))
        _selectedTime = State(initialValue: initialDraft.startAt)
        _durationHours = State(initialValue: initialDraft.durationHours)
        _capacity = State(initialValue: max(2, initialDraft.capacity))
        _selectedVibe = State(initialValue: initialDraft.vibe)
        _selectedLanguages = State(initialValue: Self.normalizedLanguageCodes(from: initialDraft.languages))
        _coverImageData = State(initialValue: initialDraft.coverImageData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    basicsCard

                    if sourceType != .event {
                        locationCard
                        scheduleCard
                    } else {
                        sourceEventCard
                    }

                    optionsCard
                    coverCard

                    if let message = submissionState.errorMessage {
                        errorCard(message)
                    }
                }
                .padding(20)
            }
            .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(submissionState.isSubmitting)
                }

                ToolbarItem(placement: .principal) {
                    Text("Create Hangout")
                        .font(FriendZoneTheme.Typography.system(17, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(submissionState.isSubmitting ? "Posting..." : "Post") {
                        submit()
                    }
                    .disabled(submissionState.isSubmitting || sourceType == .offer)
                }
            }
            .onChange(of: selectedCoverItem) { item in
                handleCoverSelection(item)
            }
            .onDisappear {
                coverLoadTask?.cancel()
                submissionTask?.cancel()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sourceTitle)
                .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(sourceSubtitle)
                .font(FriendZoneTheme.Typography.system(14, weight: .regular))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var basicsCard: some View {
        card("Basics") {
            VStack(alignment: .leading, spacing: 14) {
                labeledTextField("Title", text: $title, placeholder: sourceType == .event ? "Optional for event hangouts" : "Coffee, walk, brunch...")
                labeledTextEditor("Description", text: $description, placeholder: "What should people expect?")
            }
        }
    }

    private var locationCard: some View {
        card("Location") {
            VStack(alignment: .leading, spacing: 14) {
                fixedValueRow("City", value: resolvedCityName, detail: resolvedCityDetail)
                labeledTextField("Place", text: $locationName, placeholder: "Mauerpark")
                labeledTextField("Address", text: $locationAddress, placeholder: "Optional")
            }
        }
    }

    private var scheduleCard: some View {
        card("Schedule") {
            VStack(alignment: .leading, spacing: 14) {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)

                Picker("Duration", selection: $durationHours) {
                    ForEach(supportedDurations, id: \.self) { value in
                        Text("\(value)h").tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var sourceEventCard: some View {
        card("Event Source") {
            VStack(alignment: .leading, spacing: 8) {
                Text(sourceLabel ?? "Linked event hangout")
                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text("Date, place and source event are resolved by the backend for event-based hangouts.")
                    .font(FriendZoneTheme.Typography.system(13, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
        }
    }

    private var optionsCard: some View {
        card("Options") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Vibe", selection: $selectedVibe) {
                    ForEach(supportedVibes, id: \.self) { vibe in
                        Text(vibe.title).tag(vibe)
                    }
                }
                .pickerStyle(.menu)

                Picker("Capacity", selection: $capacity) {
                    ForEach(supportedCapacities, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Languages")
                        .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    FlexibleLanguageChips(
                        items: supportedLanguages,
                        selectedCodes: Set(selectedLanguages),
                        onTap: toggleLanguage
                    )
                }

                if sourceType == .offer {
                    Text("Venue offer hangouts are not supported by the backend create endpoint yet.")
                        .font(FriendZoneTheme.Typography.system(13, weight: .regular))
                        .foregroundColor(Color.red)
                }
            }
        }
    }

    private var coverCard: some View {
        card("Cover Photo") {
            VStack(alignment: .leading, spacing: 12) {
                if let image = coverPreview {
                    ZStack(alignment: .topTrailing) {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button {
                            selectedCoverItem = nil
                            coverImageData = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .padding(10)
                    }
                } else {
                    PhotosPicker(selection: $selectedCoverItem, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo")
                            Text("Choose Cover Photo")
                                .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                        }
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black.opacity(0.03))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var coverPreview: Image? {
        guard let coverImageData, let uiImage = UIImage(data: coverImageData) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private var sourceTitle: String {
        switch sourceType {
        case .event:
            return "Create Event Hangout"
        case .offer:
            return "Venue Offer Hangout"
        case .hangout:
            return "Create Community Hangout"
        }
    }

    private var sourceSubtitle: String {
        if let sourceLabel, !sourceLabel.isEmpty {
            return sourceLabel
        }

        switch sourceType {
        case .event:
            return "This hangout will be linked to an event."
        case .offer:
            return "This flow is currently blocked by backend limitations."
        case .hangout:
            return "Only the fields required by the backend are included."
        }
    }

    @ViewBuilder
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func labeledTextField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(.sentences)
                .padding(12)
                .background(Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func fixedValueRow(_ label: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

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
            .padding(12)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func labeledTextEditor(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(FriendZoneTheme.Typography.system(14, weight: .regular))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .padding(.top, 20)
                        .padding(.leading, 16)
                }

                TextEditor(text: text)
                    .frame(minHeight: 120)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(FriendZoneTheme.Typography.system(14, weight: .medium))
            .foregroundColor(Color.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func toggleLanguage(_ code: String) {
        if selectedLanguages.contains(code) {
            selectedLanguages.removeAll { $0 == code }
            return
        }

        guard selectedLanguages.count < 3 else { return }
        selectedLanguages.append(code)
    }

    private func handleCoverSelection(_ item: PhotosPickerItem?) {
        coverLoadTask?.cancel()

        guard let item else {
            coverImageData = nil
            return
        }

        coverLoadTask = Task(priority: .userInitiated) {
            guard let data = try? await item.loadTransferable(type: Data.self), !Task.isCancelled else {
                return
            }

            let optimizedData = optimizeCreateHangoutCoverData(data)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                coverImageData = optimizedData
            }
        }
    }

    private func submit() {
        submissionState.errorMessage = nil

        do {
            let submission = try buildSubmission()
            let createAction = onCreate
            let cancelAction = onCancel

            submissionState.isSubmitting = true
            submissionTask?.cancel()
            submissionTask = Task {
                do {
                    try await createAction(submission)
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        submissionState.isSubmitting = false
                        cancelAction()
                    }
                } catch {
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        submissionState.isSubmitting = false
                        submissionState.errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            submissionState.errorMessage = error.localizedDescription
        }
    }

    private func buildSubmission() throws -> CreateHangoutSubmission {
        if sourceType == .offer {
            throw AppSessionError.httpStatus(400, "Offer-sourced hangouts are not supported by the backend.")
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = resolvedCityName
        let trimmedCityPlaceID = resolvedCityPlaceID
        let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        if sourceType != .event {
            guard trimmedTitle.count >= 3 else {
                throw AppSessionError.httpStatus(400, "Title must be at least 3 characters.")
            }
            guard trimmedDescription.count >= 10 else {
                throw AppSessionError.httpStatus(400, "Description must be at least 10 characters.")
            }
            guard !trimmedCity.isEmpty else {
                throw AppSessionError.httpStatus(400, "Set your city in onboarding/profile before creating a hangout.")
            }
            guard !trimmedCityPlaceID.isEmpty else {
                throw AppSessionError.httpStatus(400, "A valid city_place_id is required. Set your city in onboarding/profile first.")
            }
            guard !trimmedLocation.isEmpty else {
                throw AppSessionError.httpStatus(400, "Place is required.")
            }
        }

        let startAt = combine(selectedDate: selectedDate, selectedTime: selectedTime)
        if sourceType != .event, startAt <= Date() {
            throw AppSessionError.httpStatus(400, "Start time must be in the future.")
        }

        return CreateHangoutSubmission(
            title: trimmedTitle,
            description: trimmedDescription,
            vibe: selectedVibe,
            languages: selectedLanguages,
            locationName: trimmedLocation,
            locationAddress: trimmedAddress,
            cityName: trimmedCity,
            cityPlaceID: trimmedCityPlaceID,
            latitude: nil,
            longitude: nil,
            startAt: startAt,
            durationHours: durationHours,
            isTimeFlexible: false,
            capacity: capacity,
            isCapacityUnlimited: false,
            visibility: .public,
            inviteCode: "",
            genderPreference: .any,
            audienceTags: [],
            isMicro: false,
            isLive: false,
            sourceType: sourceType,
            sourceLabel: sourceLabel,
            sourceEventID: sourceEventID,
            sourceOfferID: sourceOfferID,
            coverImageData: coverImageData,
            coverSeed: abs(slug(from: trimmedTitle.isEmpty ? UUID().uuidString : trimmedTitle).hashValue) % 6
        )
    }

    private var resolvedCityName: String {
        let trimmed = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No city configured" : trimmed
    }

    private var resolvedCityPlaceID: String {
        initialCityPlaceID
    }

    private var resolvedCityDetail: String? {
        if sourceType == .event {
            return "For event-based hangouts, the backend can also inherit the city from the linked event."
        }

        if resolvedCityPlaceID.isEmpty {
            return "This comes from your profile. Finish onboarding or set your city in profile first."
        }

        return "Using your profile city for backend discovery."
    }

    private func combine(selectedDate: Date, selectedTime: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)

        return calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute
        )) ?? selectedDate
    }

    private func slug(from value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return normalized.isEmpty ? "unknown-city" : normalized
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

        let normalized = values.compactMap { raw -> String? in
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return lookup[key]
        }

        return Array(NSOrderedSet(array: normalized)).compactMap { $0 as? String }
    }
}

@MainActor
private final class CreateHangoutSubmissionState: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMessage: String?
}

private struct FlexibleLanguageChips: View {
    let items: [(label: String, code: String)]
    let selectedCodes: Set<String>
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.label) { item in
                let isSelected = selectedCodes.contains(item.code)
                Button {
                    onTap(item.code)
                } label: {
                    Text(item.label)
                        .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                        .foregroundColor(isSelected ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(isSelected ? FriendZoneTheme.Colors.primary : Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private func optimizeCreateHangoutCoverData(_ data: Data) -> Data {
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
        CreateHangoutView(onCancel: {}, onCreate: { _ in })
    }
}
#endif
