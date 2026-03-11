import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct TicketModel: Identifiable {
    enum FrontStyle {
        case event
        case offer
    }

    let id: Int
    let title: String
    let date: Date
    let venue: String
    let location: String
    let host: String
    let code: String
    let qrPayload: String
    let category: String
    let groups: Int
    let organizerProfile: CreatorProfileDraft
    let frontStyle: FrontStyle
    let offerCard: HangoutsView.DiscoveryOfferItem?

    static func from(event: HangoutsView.DiscoveryEventItem) -> TicketModel {
        TicketModel(
            id: event.id,
            title: event.title,
            date: event.startAt,
            venue: event.venue,
            location: event.venue,
            host: "hosted by in-house crew",
            code: "FZ-\(event.id)-\(Int(event.startAt.timeIntervalSince1970))",
            qrPayload: "friendzone://ticket/\(event.id)",
            category: event.category,
            groups: event.groups,
            organizerProfile: event.creatorProfile,
            frontStyle: .event,
            offerCard: nil
        )
    }

    static func from(offer: HangoutsView.DiscoveryOfferItem) -> TicketModel {
        TicketModel(
            id: offer.id,
            title: offer.title,
            date: offer.validUntil,
            venue: offer.venue,
            location: offer.venue,
            host: offer.venueProfile.displayName,
            code: "OFF-\(offer.id)-\(Int(offer.validUntil.timeIntervalSince1970))",
            qrPayload: "friendzone://offer/\(offer.id)",
            category: "Offer",
            groups: 0,
            organizerProfile: offer.venueProfile,
            frontStyle: .offer,
            offerCard: offer
        )
    }

    var cardHangout: HangoutItem {
        let capacity = max(groups + 4, 8)
        let approved = min(max(1, groups), capacity)

        return HangoutItem(
            id: 9000 + id,
            sourceType: frontStyle == .offer ? .offer : .event,
            title: title,
            description: "Event ticket for \(venue).",
            vibe: vibeForCategory(category),
            cityName: organizerProfile.city,
            locationName: nil,
            hostName: organizerProfile.displayName,
            startAt: date,
            endAt: date.addingTimeInterval(2 * 60 * 60),
            capacity: capacity,
            approvedCount: approved,
            isLive: false,
            isMicro: false,
            isJoined: false,
            participantNames: [],
            coverImageData: nil,
            coverSeed: id % 10,
            distanceKm: 1.8,
            priceTier: .budget
        )
    }

    private func vibeForCategory(_ category: String) -> HangoutVibe {
        switch category.lowercased() {
        case "music", "party":
            return .drinks
        case "culture", "networking":
            return .deepTalk
        case "sports", "outdoor":
            return .sporty
        case "food":
            return .foodie
        case "tech":
            return .activity
        default:
            return .chill
        }
    }
}

struct TicketContainerView: View {
    let ticket: TicketModel

    @State private var rotation: Double = 0
    @State private var shinePhase: Double = -0.5
    @State private var showShareSheet = false
    @State private var exportedURL: URL?
    @State private var isExporting = false
    @State private var isIdleRotating = false
    @State private var idleStartDate = Date()
    @State private var idleBaseRotation: Double = 0

    private let idleRotationDuration: Double = 16
    private let fastSpinDuration: Double = 1.15

    var body: some View {
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isIdleRotating)) { context in
                ZStack {
                    ticketFace(currentRotation(at: context.date))
                    shine(rotation: currentRotation(at: context.date))
                }
                .frame(width: 332, height: 206)
            }

            actionRow
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(FriendZoneTheme.Colors.surface.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        .onAppear {
            withAnimation(Animation.linear(duration: 4).repeatForever(autoreverses: false)) {
                shinePhase = 1
            }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { exportedURL = nil }) {
            if let url = exportedURL {
                ActivityView(items: [url])
            }
        }
        .onAppear {
            beginIdleRotation()
        }
        .onDisappear {
            stopIdleRotation()
        }
    }

    private func ticketFace(_ displayedRotation: Double) -> some View {
        ZStack {
            TicketFrontView(
                ticket: ticket,
                showActions: false,
                isExporting: isExporting,
                onShowCode: {},
                onDownloadPDF: {}
            )
            .scaleEffect(previewScale)
            .opacity(isShowingBack(displayedRotation) ? 0 : 1)
            .rotation3DEffect(
                .degrees(displayedRotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.92
            )

            TicketBackView(ticket: ticket, onFlipBack: flipBack)
                .scaleEffect(previewScale)
                .opacity(isShowingBack(displayedRotation) ? 1 : 0)
                .rotation3DEffect(
                    .degrees(displayedRotation - 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.92
                )
        }
        .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.74, blendDuration: 0.25), value: rotation)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            actionButton(title: "Show Code", icon: "qrcode", action: flipToBack)
            actionButton(title: isExporting ? "Preparing..." : "Download PDF", icon: "square.and.arrow.down", isDisabled: isExporting, action: exportPDF)
        }
    }

    private func actionButton(title: String, icon: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
            }
            .foregroundColor(isDisabled ? FriendZoneTheme.Colors.textSecondary : FriendZoneTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }

    private func shine(rotation: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.0), location: 0.16),
                .init(color: Color.white.opacity(0.14), location: 0.36),
                .init(color: Color.white.opacity(0.28), location: 0.50),
                .init(color: Color.white.opacity(0.08), location: 0.64),
                .init(color: Color.white.opacity(0.0), location: 0.84)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .blendMode(.screen)
            .opacity(isShowingBack(rotation) ? 0.0 : 1.0)
            .offset(x: shineOffset(rotation: rotation))
            .mask(TicketSilhouetteMask())
            .allowsHitTesting(false)
    }

    private func normalizedRotation(_ angle: Double) -> Double {
        let remainder = angle.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    private func isShowingBack(_ angle: Double) -> Bool {
        normalizedRotation(angle) >= 90 && normalizedRotation(angle) < 270
    }

    private func flipToBack() {
        let current = currentRotation(at: Date())
        stopIdleRotation(at: current)

        let currentNormalized = normalizedRotation(current)
        let deltaToBack = (180 - currentNormalized + 360).truncatingRemainder(dividingBy: 360)
        let target = current + 720 + deltaToBack

        withAnimation(.easeInOut(duration: fastSpinDuration)) {
            rotation = target
        }
    }

    private func flipBack() {
        let current = currentRotation(at: Date())
        let currentNormalized = normalizedRotation(current)
        let deltaToFront = (360 - currentNormalized).truncatingRemainder(dividingBy: 360)
        let target = current + deltaToFront

        withAnimation(.easeInOut(duration: 0.7)) {
            rotation = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            beginIdleRotation(from: target)
        }
    }

    private func exportPDF() {
        guard !isExporting else { return }
        isExporting = true
        Task.detached(priority: .background) {
            do {
                let url = try await MainActor.run {
                    try TicketPDFExporter.export(ticket: ticket)
                }
                await MainActor.run {
                    exportedURL = url
                    showShareSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run { isExporting = false }
            }
        }
    }

    private func currentRotation(at date: Date) -> Double {
        guard isIdleRotating else { return rotation }
        let elapsed = date.timeIntervalSince(idleStartDate)
        let degreesPerSecond = 360 / idleRotationDuration
        return idleBaseRotation + (elapsed * degreesPerSecond)
    }

    private func beginIdleRotation(from startRotation: Double? = nil) {
        let base = startRotation ?? rotation
        idleBaseRotation = base
        rotation = base
        idleStartDate = Date()
        isIdleRotating = true
    }

    private func stopIdleRotation(at angle: Double? = nil) {
        if let angle {
            rotation = angle
        }
        idleBaseRotation = rotation
        isIdleRotating = false
    }

    private func shineOffset(rotation: Double) -> CGFloat {
        let radians = normalizedRotation(rotation) * .pi / 180
        return CGFloat(sin(radians) * 58) + CGFloat(shinePhase * 20)
    }

    private var previewScale: CGFloat {
        switch ticket.frontStyle {
        case .event:
            return 0.84
        case .offer:
            return 0.92
        }
    }
}

struct TicketFrontView: View {
    let ticket: TicketModel
    let showActions: Bool
    let isExporting: Bool
    let onShowCode: () -> Void
    let onDownloadPDF: () -> Void

    var body: some View {
        VStack(spacing: showActions ? 18 : 0) {
            frontCard
            if showActions {
                actionRow
            }
        }
    }

    @ViewBuilder
    private var frontCard: some View {
        switch ticket.frontStyle {
        case .event:
            HangoutCardView(
                hangout: ticket.cardHangout,
                now: Date(),
                animateEntrance: false
            )
        case .offer:
            if let offer = ticket.offerCard {
                DiscoveryOfferVoucherCardView(offer: offer, animateEntrance: false)
            }
        }
    }

    private func actionButton(title: String, icon: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
            }
            .foregroundColor(isDisabled ? FriendZoneTheme.Colors.textSecondary : FriendZoneTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(isDisabled ? FriendZoneTheme.Colors.surface : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            actionButton(title: "Show Code", icon: "qrcode") { onShowCode() }
            actionButton(title: isExporting ? "Preparing..." : "Download PDF", icon: "square.and.arrow.down", isDisabled: isExporting) {
                onDownloadPDF()
            }
        }
    }

}

struct TicketBackView: View {
    let ticket: TicketModel
    let onFlipBack: () -> Void
    @State private var isZoomed = false

    var body: some View {
        VStack(spacing: 18) {
            TicketQRCodeView(payload: ticket.qrPayload)
                .frame(height: isZoomed ? 242 : 176)
                .scaleEffect(isZoomed ? 1.08 : 1)
                .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isZoomed)

            Text("Code: \(ticket.code)")
                .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            HStack(spacing: 12) {
                Button(isZoomed ? "Zoom Out" : "Zoom In") {
                    isZoomed.toggle()
                }
                .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }

                Button("Back") {
                    isZoomed = false
                    onFlipBack()
                }
                .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [FriendZoneTheme.Colors.surface, FriendZoneTheme.Colors.surface.opacity(0.9)], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct TicketQRCodeView: View {
    let payload: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = qrUIImage {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
        }
    }

    private var qrUIImage: UIImage? {
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "Q"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct TicketPDFContentView: View {
    let ticket: TicketModel

    var body: some View {
        VStack(spacing: 24) {
            TicketFrontView(
                ticket: ticket,
                showActions: false,
                isExporting: false,
                onShowCode: {},
                onDownloadPDF: {}
            )
            TicketBackView(ticket: ticket, onFlipBack: {})
        }
        .padding(16)
    }
}

struct TicketBarcodeView: View {
    let code: String
    let accent: Color

    private var bars: [CGFloat] {
        code.utf8.prefix(28).enumerated().map { index, byte in
            let base: CGFloat = CGFloat((Int(byte) % 4) + 1)
            return base + (index % 2 == 0 ? 0.5 : 0.0)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, value in
                Rectangle()
                    .fill(accent.opacity(0.9))
                    .frame(width: 2, height: value * 6)
            }
        }
    }
}

struct TicketPDFExporter {
    static func export(ticket: TicketModel) throws -> URL {
        let pageSize = CGSize(width: 360, height: 520)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { context in
            context.beginPage()
            let hosting = UIHostingController(rootView: TicketPDFContentView(ticket: ticket).frame(width: pageSize.width, height: pageSize.height))
            let view = hosting.view!
            view.bounds = CGRect(origin: .zero, size: pageSize)
            view.backgroundColor = .white
            let window = UIWindow(frame: view.bounds)
            window.rootViewController = hosting
            window.isHidden = false
            window.alpha = 0
            window.makeKeyAndVisible()
            view.layoutIfNeeded()
            view.layer.render(in: context.cgContext)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ticket-export-\(ticket.id)-\(UUID()).pdf")
        try data.write(to: url)
        return url
    }
}

struct TicketPreviewSheet: View {
    let ticket: TicketModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("Digital Ticket")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text("Flip to reveal the QR code, download the PDF, or share it in one tap.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    TicketContainerView(ticket: ticket)
                        .frame(maxWidth: 380)
                }
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
            .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Ticket preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                }
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TicketSilhouetteMask: View {
    var body: some View {
        GeometryReader { proxy in
            let sideRadius: CGFloat = 5.2
            let centerRadius: CGFloat = 10
            let topInset: CGFloat = 14
            let bottomInset: CGFloat = 14
            let edgeCount = 9
            let usableHeight = max(0, proxy.size.height - topInset - bottomInset)
            let step = usableHeight / CGFloat(max(1, edgeCount - 1))

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay {
                    ZStack {
                        ForEach(0..<edgeCount, id: \.self) { index in
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
                            .position(x: proxy.size.width * 0.5, y: 0)

                        Circle()
                            .fill(Color.black)
                            .frame(width: centerRadius * 2, height: centerRadius * 2)
                            .position(x: proxy.size.width * 0.5, y: proxy.size.height)
                    }
                    .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
    }
}
