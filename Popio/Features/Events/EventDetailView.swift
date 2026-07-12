import PhotosUI
import MapKit
import SwiftUI
import UIKit

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSession
    let event: PopioEvent
    @State private var selectedPicture: PhotosPickerItem?
    @State private var pictureData: Data?
    @State private var submissionMessage: String?
    @State private var isShowingMenu = false

    init(event: PopioEvent, opensChat: Bool = false) {
        self.event = event
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection

                VStack(alignment: .leading, spacing: 16) {
                    summarySection
                    eventFactsSection
                    descriptionCallout

                    if currentEvent.hasMenuImage {
                        menuButton
                    }

                    locationSection
                    creatorSection
                    actionSection
                    communitySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 96)
                .background(
                    PopioTheme.background,
                    in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                )
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 10) {
                        eventHeartButton
                        eventShareButton
                    }
                        .padding(.trailing, 28)
                        .offset(y: -27)
                }
                .offset(y: -28)
                .padding(.bottom, -28)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollIndicators(.hidden)
        .background(PopioTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedPicture) { _, newValue in
            guard let newValue else { return }

            Task {
                if let imageData = try? await jpegData(from: newValue) {
                    session.submitContribution(for: currentEvent, type: .picture, imageData: imageData)
                    submissionMessage = "Picture added."
                }
                pictureData = nil
                selectedPicture = nil
            }
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            EventBannerImageView(event: currentEvent)
                .frame(maxWidth: .infinity)
                .aspectRatio(5.0 / 3.0, contentMode: .fit)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.32),
                    Color.black.opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .allowsHitTesting(false)

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(PopioFont.custom(size: 18, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.96), in: Circle())
                    .shadow(color: PopioTheme.shadow.opacity(0.18), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .padding(.top, 56)
            .padding(.leading, 18)
        }
        .aspectRatio(5.0 / 3.0, contentMode: .fit)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $isShowingMenu) {
            EventMenuSheet(event: currentEvent)
        }
    }

    private var eventHeartButton: some View {
        Button {
            session.toggleLike(for: currentEvent)
        } label: {
            EventDetailCircleActionButton(systemImage: session.isLikedByCurrentUser(currentEvent) ? "heart.fill" : "heart")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.isLikedByCurrentUser(currentEvent) ? "Remove interest" : "Mark interested")
    }

    private var eventShareButton: some View {
        ShareLink(item: shareText) {
            EventDetailCircleActionButton(systemImage: "square.and.arrow.up")
        }
        .accessibilityLabel("Share event")
    }

    private var summarySection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(currentEvent.title)
                    .font(PopioFont.custom(size: 24, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Label(currentEvent.address, systemImage: "mappin.circle.fill")
                    .font(PopioFont.custom(size: 14, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)
                    .lineLimit(2)

                Text(String(format: "%.1f mi away", currentEvent.distanceInMiles))
                    .font(PopioFont.custom(size: 13, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)
            }

            Spacer(minLength: 0)
        }
    }

    private var eventFactsSection: some View {
        let event = currentEvent

        return HStack(spacing: 0) {
            EventDetailFact(
                systemImage: "calendar",
                title: event.eventDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                subtitle: timeText ?? "Time TBD",
                tint: PopioTheme.coral
            )

            EventDetailDivider()

            EventDetailFact(
                systemImage: "tag",
                title: event.category.rawValue,
                subtitle: "Pop-up",
                tint: PopioTheme.gold
            )

            EventDetailDivider()

            EventDetailFact(
                systemImage: "person.2",
                title: "\(event.goingCount) Going",
                subtitle: "\(approvedReviewCount) chat",
                tint: PopioTheme.accent
            )
        }
        .padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PopioTheme.line, lineWidth: 1)
        }
    }

    private var descriptionCallout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A cozy evening pop-up")
                .font(PopioFont.custom(size: 16, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)

            Text(descriptionText)
                .font(PopioFont.custom(size: 14, weight: .regular))
                .foregroundStyle(PopioTheme.ink.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    PopioTheme.accentSoft.opacity(0.76),
                    PopioTheme.coralSoft.opacity(0.62),
                    PopioTheme.backgroundElevated
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var menuButton: some View {
        Button {
            isShowingMenu = true
        } label: {
            Label("Menu", systemImage: "menucard.fill")
                .font(PopioFont.custom(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
        }
        .foregroundStyle(PopioTheme.gold)
        .background(PopioTheme.coralSoft.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PopioTheme.coral.opacity(0.18), lineWidth: 1)
        }
        .buttonStyle(.plain)
    }

    private var timeText: String? {
        let event = currentEvent

        switch (event.startTime, event.endTime) {
        case let (start?, end?):
            return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        case let (start?, nil):
            return "Starts \(start.formatted(date: .omitted, time: .shortened))"
        case let (nil, end?):
            return "Ends \(end.formatted(date: .omitted, time: .shortened))"
        case (nil, nil):
            return nil
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EventDetailSectionTitle("Location")

            VStack(spacing: 0) {
                EventLocationMapPreview(event: currentEvent)
                    .frame(height: 132)

                HStack(spacing: 12) {
                    Text(currentEvent.address)
                        .font(PopioFont.custom(size: 15, weight: .semibold))
                        .foregroundStyle(PopioTheme.ink)
                        .lineLimit(3)

                    Spacer(minLength: 0)

                    Link(destination: directionsURL) {
                        Label("Get Directions", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                            .font(PopioFont.custom(size: 13, weight: .semibold))
                            .foregroundStyle(PopioTheme.gold)
                    }
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
        }
    }

    private var creatorSection: some View {
        let event = currentEvent
        let creator = session.creator(for: event)

        return VStack(alignment: .leading, spacing: 10) {
            EventDetailSectionTitle("Found by")

            HStack(spacing: 12) {
                ProfileAvatarView(user: creator, size: 50)

                VStack(alignment: .leading, spacing: 3) {
                    Text(creator?.displayName ?? creator?.username ?? event.creatorUsername)
                        .font(PopioFont.custom(size: 16, weight: .semibold))
                        .foregroundStyle(PopioTheme.ink)

                    Text("@\(creator?.username ?? event.creatorUsername)")
                        .font(PopioFont.custom(size: 13, weight: .medium))
                        .foregroundStyle(PopioTheme.muted)
                }

                Spacer()
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
        }
    }

    private var actionSection: some View {
        HStack(spacing: 12) {
            Button {
                session.toggleGoing(for: currentEvent)
            } label: {
                Label(session.isGoingByCurrentUser(currentEvent) ? "Going" : "Going", systemImage: "checkmark.circle.fill")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .foregroundStyle(.white)
            .background(eventActionGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .buttonStyle(.plain)
            .accessibilityLabel(session.isGoingByCurrentUser(currentEvent) ? "Remove going status" : "Mark as going")

            NavigationLink {
                EventChatView(event: currentEvent)
            } label: {
                Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .foregroundStyle(.white)
            .background(eventActionGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.36), lineWidth: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open event chat")
        }
    }

    private var eventActionGradient: LinearGradient {
        LinearGradient(
            colors: [
                PopioTheme.coral.opacity(0.86),
                PopioTheme.gold.opacity(0.90),
                PopioTheme.accent.opacity(0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EventDetailSectionTitle("Photos")
            picturesSection
        }
    }

    private var picturesSection: some View {
        let contributions = session.approvedContributions(for: currentEvent, type: .picture)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 3)

        return VStack(alignment: .leading, spacing: 10) {
            if let submissionMessage {
                Text(submissionMessage)
                    .font(PopioFont.footnote(.semibold))
                    .foregroundStyle(PopioTheme.accent)
            }

            LazyVGrid(columns: columns, spacing: 5) {
                PhotosPicker(selection: $selectedPicture, matching: .images) {
                    EventPhotoAddTile()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add photo")

                ForEach(contributions) { contribution in
                    EventPhotoGridTile(contribution: contribution, category: currentEvent.category)
                }
            }
        }
    }

    private func contributionList(type: EventContributionType) -> some View {
        let contributions = session.approvedContributions(for: currentEvent, type: type)

        return VStack(alignment: .leading, spacing: 12) {
            if let submissionMessage {
                Text(submissionMessage)
                    .font(PopioFont.footnote(.semibold))
                    .foregroundStyle(PopioTheme.accent)
            }

            if contributions.isEmpty {
                EmptyStateView(
                    systemImage: emptyImageName(for: type),
                    title: emptyTitle(for: type),
                    message: emptyMessage(for: type)
                )
            } else {
                ForEach(contributions) { contribution in
                    contributionRow(contribution)
                }
            }
        }
    }

    private func contributionRow(_ contribution: EventContribution) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if contribution.type == .picture {
                BannerImageView(
                    imageData: contribution.imageData,
                    imageURL: contribution.imageURL,
                    category: currentEvent.category,
                    focusY: 0.5
                )
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !contribution.text.isEmpty {
                Text(contribution.text)
                    .font(PopioFont.subheadline(.medium))
                    .foregroundStyle(PopioTheme.ink)
            }

            HStack {
                Text("@\(contribution.creatorUsername)")
                    .font(PopioFont.caption(.semibold))
                    .foregroundStyle(PopioTheme.muted)

                Spacer()

                LikeButton(
                    isLiked: session.isLikedByCurrentUser(contribution),
                    likeCount: contribution.likeCount,
                    size: .compact
                ) {
                    session.toggleLike(for: contribution)
                }
            }
        }
        .popioCard(cornerRadius: 22, padding: 14)
    }

    private func emptyImageName(for type: EventContributionType) -> String {
        switch type {
        case .picture:
            return "photo"
        case .review:
            return "bubble.left.and.bubble.right"
        }
    }

    private func emptyTitle(for type: EventContributionType) -> String {
        switch type {
        case .picture:
            return "No photos yet"
        case .review:
            return "No chat yet"
        }
    }

    private func emptyMessage(for type: EventContributionType) -> String {
        switch type {
        case .picture:
            return "Approved photos will appear here."
        case .review:
            return ""
        }
    }

    private var currentEvent: PopioEvent {
        session.events.first { $0.id == event.id } ?? event
    }

    private var descriptionText: String {
        let trimmedDescription = currentEvent.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDescription.isEmpty ? "Details coming soon." : trimmedDescription
    }

    private var approvedReviewCount: Int {
        session.approvedContributions(for: currentEvent, type: .review).count
    }

    private var directionsURL: URL {
        let query = currentEvent.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentEvent.address
        return URL(string: "http://maps.apple.com/?q=\(query)") ?? URL(string: "http://maps.apple.com")!
    }

    private var shareText: String {
        var parts = [
            currentEvent.title,
            currentEvent.address,
            currentEvent.eventDate.formatted(date: .complete, time: .omitted)
        ]

        if let timeText {
            parts.append(timeText)
        }

        parts.append("Shared from Popio")
        return parts.joined(separator: "\n")
    }

    private func jpegData(from item: PhotosPickerItem) async throws -> Data? {
        guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
        guard let image = UIImage(data: data) else { return data }
        return image.jpegData(compressionQuality: 0.85)
    }
}

private struct EventLocationMapPreview: View {
    let event: PopioEvent

    var body: some View {
        ZStack {
            if let coordinate = event.coordinate {
                Map(initialPosition: .region(region(for: coordinate))) {
                    Marker(event.title, coordinate: coordinate)
                        .tint(PopioTheme.gold)
                }
                .mapStyle(.standard(elevation: .flat))
                .allowsHitTesting(false)
            } else {
                LinearGradient(
                    colors: [
                        PopioTheme.gold.opacity(0.22),
                        PopioTheme.accent.opacity(0.18),
                        PopioTheme.coral.opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.0),
                    PopioTheme.accent.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            Image(systemName: "mappin.circle.fill")
                .font(PopioFont.custom(size: 34, weight: .semibold))
                .foregroundStyle(PopioTheme.gold)
                .shadow(color: Color.white.opacity(0.9), radius: 4)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
    }

    private func region(for coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    }
}

private struct EventDetailFact: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 18, weight: .medium))
                .foregroundStyle(tint)

            Text(title)
                .font(PopioFont.custom(size: 12.5, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(subtitle)
                .font(PopioFont.custom(size: 11.5, weight: .medium))
                .foregroundStyle(PopioTheme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

private struct EventDetailDivider: View {
    var body: some View {
        Rectangle()
            .fill(PopioTheme.line)
            .frame(width: 1, height: 48)
    }
}

private struct EventDetailCircleActionButton: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(PopioFont.custom(size: 18, weight: .semibold))
            .foregroundStyle(PopioTheme.gold)
            .frame(width: 50, height: 50)
            .background(
                LinearGradient(
                    colors: [
                        PopioTheme.accentSoft.opacity(0.92),
                        PopioTheme.coralSoft.opacity(0.72),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(PopioTheme.gold.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: PopioTheme.shadow.opacity(0.14), radius: 10, y: 5)
    }
}

private struct EventPhotoAddTile: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PopioTheme.accentSoft.opacity(0.92),
                    PopioTheme.coralSoft.opacity(0.72),
                    PopioTheme.gold.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "plus")
                .font(PopioFont.custom(size: 24, weight: .semibold))
                .foregroundStyle(PopioTheme.ink.opacity(0.76))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.70), in: Circle())
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopioTheme.gold.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct EventPhotoGridTile: View {
    let contribution: EventContribution
    let category: EventCategory

    var body: some View {
        BannerImageView(
            imageData: contribution.imageData,
            imageURL: contribution.imageURL,
            category: category,
            focusY: 0.5
        )
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EventDetailSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(PopioFont.custom(size: 18, weight: .semibold))
            .foregroundStyle(PopioTheme.ink)
    }
}

private struct DetailInfoRow: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 15, weight: .bold))
                .foregroundStyle(PopioTheme.accent)
                .frame(width: 28, height: 28)
                .background(PopioTheme.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PopioFont.caption(.bold))
                    .foregroundStyle(PopioTheme.muted)
                Text(value)
                    .font(PopioFont.subheadline(.bold))
                    .foregroundStyle(PopioTheme.ink)
            }
        }
    }
}

private struct TextContributionComposerCard: View {
    let title: String
    let prompt: String
    let placeholder: String
    let systemImage: String
    @Binding var text: String
    let minLines: Int
    let maxLines: Int
    let buttonTitle: String
    let submit: () -> Void

    private var isSubmitDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ComposerHeader(title: title, prompt: prompt, systemImage: systemImage)

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(minLines...maxLines)
                .font(PopioFont.subheadline())
                .foregroundStyle(PopioTheme.ink)
                .padding(14)
                .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PopioTheme.gold.opacity(0.28), lineWidth: 1)
                }

            Button(action: submit) {
                Label(buttonTitle, systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .popioPrimaryButton()
            .disabled(isSubmitDisabled)
        }
        .padding(16)
        .background {
            EventComposerBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PopioTheme.gold.opacity(0.20), lineWidth: 1)
        }
    }
}

struct EventChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSession
    let event: PopioEvent
    @State private var messageText = ""
    private let tabBarClearance: CGFloat = 62

    private var currentEvent: PopioEvent {
        session.events.first { $0.id == event.id } ?? event
    }

    private var messages: [EventContribution] {
        session.approvedContributions(for: currentEvent, type: .review)
            .sorted { $0.createdDate < $1.createdDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty {
                        ChatEmptyState()
                            .padding(.horizontal, 16)
                            .padding(.top, 48)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(messages) { message in
                                ChatMessageBubble(
                                    contribution: message,
                                    isCurrentUser: message.createdByUserID == session.currentUser?.id
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 18 + tabBarClearance)
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    scrollToLatest(using: proxy)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToLatest(using: proxy)
                }
            }
        }
        .background(PopioTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatInputBar(
                text: $messageText,
                send: submitChatMessage
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8 + tabBarClearance)
            .background(PopioTheme.backgroundElevated)
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(PopioFont.custom(size: 17, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(Color.white, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(PopioTheme.line, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            EventBannerImageView(event: currentEvent)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(currentEvent.title)
                    .font(PopioFont.custom(size: 16, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)
                    .lineLimit(1)

                Text("Event chat")
                    .font(PopioFont.custom(size: 12, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(PopioTheme.backgroundElevated)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PopioTheme.line)
                .frame(height: 1)
        }
    }

    private func submitChatMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        session.submitContribution(for: currentEvent, type: .review, text: trimmedText)
        messageText = ""
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let lastID = messages.last?.id else { return }

        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct ChatMessageBubble: View {
    let contribution: EventContribution
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 48)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text("@\(contribution.creatorUsername)")
                        .font(PopioFont.custom(size: 11, weight: .semibold))
                        .foregroundStyle(PopioTheme.muted)
                        .padding(.leading, 4)
                }

                Text(contribution.text.isEmpty ? "Message" : contribution.text)
                    .font(PopioFont.custom(size: 14, weight: .medium))
                    .foregroundStyle(isCurrentUser ? .white : PopioTheme.ink)
                    .lineSpacing(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        if !isCurrentUser {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PopioTheme.line, lineWidth: 1)
                        }
                    }

                Text(contribution.createdDate.formatted(.dateTime.hour().minute()))
                    .font(PopioFont.custom(size: 10, weight: .medium))
                    .foregroundStyle(PopioTheme.muted.opacity(0.82))
                    .padding(.horizontal, 4)
            }

            if !isCurrentUser {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var bubbleBackground: some ShapeStyle {
        if isCurrentUser {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [PopioTheme.gold, PopioTheme.gold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color.white)
    }
}

private struct ChatInputBar: View {
    @Binding var text: String
    let send: () -> Void

    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(PopioFont.custom(size: 14, weight: .medium))
                .foregroundStyle(PopioTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(PopioTheme.line, lineWidth: 1)
                }

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(PopioFont.custom(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: isSendDisabled
                                ? [PopioTheme.muted.opacity(0.38), PopioTheme.muted.opacity(0.28)]
                                : [PopioTheme.gold, PopioTheme.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSendDisabled)
            .accessibilityLabel("Send chat message")
        }
        .padding(10)
        .background(EventChatBarBackground(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(PopioTheme.gold.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct ChatEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(PopioFont.custom(size: 30, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [PopioTheme.gold, PopioTheme.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .background(PopioTheme.gold.opacity(0.12), in: Circle())

            Text("No chat yet")
                .font(PopioFont.custom(size: 15, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)

            Text("Start the conversation for this pop-up.")
                .font(PopioFont.custom(size: 12, weight: .medium))
                .foregroundStyle(PopioTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct EventChatBarBackground: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        LinearGradient(
            colors: [
                PopioTheme.surface,
                PopioTheme.coralSoft.opacity(0.70)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct PictureComposerCard: View {
    let imageData: Data?
    let category: EventCategory
    @Binding var selectedPicture: PhotosPickerItem?
    let submit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ComposerHeader(
                title: "Add pictures",
                prompt: "Upload a clear look at the pop-up so others know what to expect.",
                systemImage: "photo.fill"
            )

            if imageData == nil {
                PhotosPicker(selection: $selectedPicture, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(PopioFont.custom(size: 30, weight: .semibold))
                            .foregroundStyle(PopioTheme.gold)

                        Text("Choose a picture")
                            .font(PopioFont.subheadline(.bold))
                            .foregroundStyle(PopioTheme.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(PopioTheme.gold.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 12) {
                    BannerImageView(
                        imageData: imageData,
                        imageURL: nil,
                        category: category,
                        focusY: 0.5
                    )
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $selectedPicture, matching: .images) {
                            Label("Change", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .popioSecondaryButton()

                        Button(action: submit) {
                            Label("Post", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .popioPrimaryButton()
                    }
                }
            }
        }
        .padding(16)
        .background {
            EventComposerBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PopioTheme.gold.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct ComposerHeader: View {
    let title: String
    let prompt: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [PopioTheme.gold, PopioTheme.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PopioFont.custom(size: 16, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)

                Text(prompt)
                    .font(PopioFont.caption(.medium))
                    .foregroundStyle(PopioTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct EventComposerBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                PopioTheme.surface,
                PopioTheme.coralSoft.opacity(0.58),
                PopioTheme.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
