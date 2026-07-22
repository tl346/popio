import PhotosUI
import MapKit
import SwiftUI
import UIKit

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSession
    let event: PopioEvent
    let isAdminReview: Bool
    @State private var selectedPicture: PhotosPickerItem?
    @State private var pictureData: Data?
    @State private var submissionMessage: String?
    @State private var isShowingMenu = false
    @State private var heartPulse = false
    @State private var expandedPhoto: EventContribution?
    @State private var activeReportRequest: UGCReportRequest?
    @State private var userIDToBlock: String?
    @State private var isShowingRejectionSheet = false
    @State private var isReviewingEvent = false
    @State private var reviewErrorMessage: String?
    @State private var isShowingAdminEditor = false
    @State private var isConfirmingEventDeletion = false
    @State private var isDeletingEvent = false
    @State private var adminActionError: String?

    init(event: PopioEvent, opensChat: Bool = false, isAdminReview: Bool = false) {
        self.event = event
        self.isAdminReview = isAdminReview
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topControls
                    .padding(.top, 8)

                alignedEventContent
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 176)
        }
        .scrollIndicators(.hidden)
        .background(PopioTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isAdminReview {
                adminReviewActionBar
            } else {
                bottomActionBar
            }
        }
        .onChange(of: selectedPicture) { _, newValue in
            guard let newValue else { return }

            Task {
                if let imageData = try? await jpegData(from: newValue) {
                    session.submitContribution(for: currentEvent, type: .picture, imageData: imageData)
                    submissionMessage = "Photo submitted for review."
                }
                pictureData = nil
                selectedPicture = nil
            }
        }
        .fullScreenCover(item: $expandedPhoto) { contribution in
            EventExpandedPhotoView(
                contribution: contribution,
                category: currentEvent.category
            )
            .environmentObject(session)
        }
        .sheet(item: $activeReportRequest) { request in
            UGCReportSheet(request: request)
                .environmentObject(session)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isShowingRejectionSheet) {
            EventRejectionSheet(eventTitle: currentEvent.title) { comment in
                try await session.reviewEvent(currentEvent, status: .rejected, comment: comment)
                dismiss()
            }
            .presentationDetents([.height(410)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isShowingAdminEditor) {
            AdminEventEditor(event: currentEvent) { updatedEvent in
                try await session.updateEvent(updatedEvent)
            }
            .environmentObject(session)
        }
        .confirmationDialog(
            "Delete this pop-up?",
            isPresented: $isConfirmingEventDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Pop-up", role: .destructive) {
                Task {
                    isDeletingEvent = true
                    defer { isDeletingEvent = false }
                    do {
                        try await session.deleteEvent(currentEvent)
                        dismiss()
                    } catch {
                        adminActionError = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the event and its photos and chat messages.")
        }
        .alert(
            "Admin action failed",
            isPresented: Binding(
                get: { adminActionError != nil },
                set: { if !$0 { adminActionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { adminActionError = nil }
        } message: {
            Text(adminActionError ?? "Please try again.")
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: Binding(
                get: { userIDToBlock != nil },
                set: { if !$0 { userIDToBlock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block User", role: .destructive) {
                if let userIDToBlock {
                    session.blockUser(userIDToBlock)
                    self.userIDToBlock = nil
                }
            }

            Button("Cancel", role: .cancel) {
                userIDToBlock = nil
            }
        } message: {
            Text("You will no longer see this user's pop-ups, photos, or chat messages.")
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            EventBannerImageView(event: currentEvent)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

            Text(dateBadgeText)
                .font(PopioFont.custom(size: 13, weight: .semibold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color(red: 0.90, green: 0.84, blue: 1.00), in: Capsule())
                .padding(14)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(Rectangle())
        .sheet(isPresented: $isShowingMenu) {
            EventMenuSheet(event: currentEvent)
        }
    }

    private var alignedEventContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroSection
            summarySection
            eventFactsSection
            descriptionCallout
            tagsSection

            if currentEvent.hasMenuImage {
                menuButton
            }

            creatorSection

            if !goingUsers.isEmpty {
                GoingUsersStack(users: goingUsers, totalCount: currentEvent.goingCount)
            }

            communitySection
        }
        .padding(.horizontal, 12)
    }

    private var topControls: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                EventDetailCircleActionButton(systemImage: "chevron.left", foreground: PopioTheme.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            safetyMenu
            eventHeartButton
            eventShareButton
        }
    }

    @ViewBuilder
    private var safetyMenu: some View {
        if session.currentUser?.isAdmin == true {
            Menu {
                Button {
                    isShowingAdminEditor = true
                } label: {
                    Label("Edit Pop-up", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    isConfirmingEventDeletion = true
                } label: {
                    Label("Delete Pop-up", systemImage: "trash")
                }
                .disabled(isDeletingEvent)
            } label: {
                EventDetailCircleActionButton(systemImage: "ellipsis", foreground: PopioTheme.ink, background: .white)
            }
            .accessibilityLabel("Event administration options")
        } else if let creator = session.users.first(where: { $0.id == currentEvent.createdByUserID }),
                  creator.id != session.currentUser?.id {
            Menu {
                Button(role: .destructive) {
                    activeReportRequest = UGCReportRequest(
                        targetType: .event,
                        targetID: currentEvent.id,
                        reportedUserID: creator.id,
                        reportedUsername: creator.username,
                        title: "Report Pop-up"
                    )
                } label: {
                    Label("Report Pop-up", systemImage: "flag")
                }

                Button(role: .destructive) {
                    userIDToBlock = creator.id
                } label: {
                    Label("Block @\(creator.username)", systemImage: "hand.raised")
                }
            } label: {
                EventDetailCircleActionButton(systemImage: "ellipsis", foreground: PopioTheme.ink, background: .white)
            }
            .accessibilityLabel("Safety options")
        }
    }

    private var eventHeartButton: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.42)) {
                heartPulse = true
            }
            session.toggleLike(for: currentEvent)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    heartPulse = false
                }
            }
        } label: {
            EventDetailCircleActionButton(
                systemImage: session.isLikedByCurrentUser(currentEvent) ? "heart.fill" : "heart",
                foreground: session.isLikedByCurrentUser(currentEvent) ? PopioTheme.coral : PopioTheme.ink,
                background: .white
            )
            .scaleEffect(heartPulse ? 1.18 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.isLikedByCurrentUser(currentEvent) ? "Remove interest" : "Mark interested")
    }

    private var eventShareButton: some View {
        ShareLink(item: shareText) {
            EventDetailCircleActionButton(
                systemImage: "square.and.arrow.up",
                foreground: .black,
                background: .white
            )
        }
        .accessibilityLabel("Share event")
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(currentEvent.title)
                .font(PopioFont.custom(size: 23, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                EventDetailBadge(text: currentEvent.category.rawValue, tint: PopioTheme.gold)

                if currentEvent.hasMenuImage {
                    EventDetailBadge(text: "Menu", tint: PopioTheme.coral)
                }
            }
        }
    }

    private var eventFactsSection: some View {
        HStack(spacing: 10) {
            Label(shortLocation, systemImage: "mappin.circle.fill")
                .lineLimit(1)

            Rectangle()
                .fill(PopioTheme.line)
                .frame(width: 1, height: 18)

            Label(timeText ?? "Time TBD", systemImage: "clock.fill")
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .font(PopioFont.custom(size: 14, weight: .medium))
        .foregroundStyle(PopioTheme.muted)
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PopioTheme.line, lineWidth: 1)
        }
    }

    private var descriptionCallout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About")
                .font(PopioFont.custom(size: 16, weight: .semibold))
                .foregroundStyle(PopioTheme.gold)

            Text(descriptionText)
                .font(PopioFont.custom(size: 14, weight: .regular))
                .foregroundStyle(PopioTheme.ink.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PopioTheme.line, lineWidth: 1)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EventDetailSectionTitle("Tags")

            HStack(spacing: 8) {
                ForEach(detailTags, id: \.self) { tag in
                    EventDetailBadge(text: tag, tint: PopioTheme.gold)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PopioTheme.line, lineWidth: 1)
        }
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

                if let creator, creator.id != session.currentUser?.id {
                    Button {
                        session.sendFriendRequest(to: creator)
                    } label: {
                        Text(followButtonTitle(for: creator))
                            .font(PopioFont.custom(size: 13, weight: .semibold))
                            .foregroundStyle(followButtonTint(for: creator))
                            .padding(.horizontal, 17)
                            .frame(height: 38)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(followButtonTint(for: creator).opacity(0.58), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(session.relationshipState(with: creator) != .none)
                    .accessibilityLabel(followButtonTitle(for: creator))
                }
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button {
                session.toggleGoing(for: currentEvent)
            } label: {
                Label("Going", systemImage: session.isGoingByCurrentUser(currentEvent) ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .foregroundStyle(.white)
            .background(eventActionGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .buttonStyle(.plain)
            .accessibilityLabel(session.isGoingByCurrentUser(currentEvent) ? "Remove going status" : "Mark as going")

            NavigationLink {
                EventChatView(event: currentEvent)
            } label: {
                Label("Chatroom", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .foregroundStyle(PopioTheme.gold)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PopioTheme.gold.opacity(0.46), lineWidth: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open event chatroom")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 48)
        .background(Color.white)
    }

    private var adminReviewActionBar: some View {
        VStack(spacing: 10) {
            if let reviewErrorMessage {
                Text(reviewErrorMessage)
                    .font(PopioFont.caption(.semibold))
                    .foregroundStyle(PopioTheme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    reviewErrorMessage = nil
                    isReviewingEvent = true
                    defer { isReviewingEvent = false }

                    do {
                        try await session.reviewEvent(currentEvent, status: .approved, comment: "")
                        dismiss()
                    } catch {
                        reviewErrorMessage = error.localizedDescription
                    }
                }
            } label: {
                Label(isReviewingEvent ? "Approving..." : "Approve", systemImage: "checkmark.circle.fill")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .foregroundStyle(.white)
            .background(eventActionGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .buttonStyle(.plain)
            .disabled(isReviewingEvent)
            .accessibilityLabel("Approve pop-up")

            Button {
                reviewErrorMessage = nil
                isShowingRejectionSheet = true
            } label: {
                Label("Reject", systemImage: "xmark.circle.fill")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .foregroundStyle(PopioTheme.coral)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PopioTheme.coral.opacity(0.62), lineWidth: 1)
            }
            .buttonStyle(.plain)
            .disabled(isReviewingEvent)
            .accessibilityLabel("Reject pop-up")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 48)
        .background(Color.white)
    }

    private var goingUsers: [PopioUser] {
        currentEvent.goingUserIDs.compactMap { userID in
            session.users.first { $0.id == userID }
        }
        .prefix(5)
        .map(\.self)
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
        let contributions = visiblePictureContributions
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
                    Button {
                        expandedPhoto = contribution
                    } label: {
                        EventPhotoGridTile(
                            contribution: contribution,
                            category: currentEvent.category,
                            isPending: contribution.moderationStatus == .pending
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View photo by \(contribution.creatorUsername)")
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

    private var visiblePictureContributions: [EventContribution] {
        session.eventContributions
            .filter { contribution in
                guard contribution.eventID == currentEvent.id, contribution.type == .picture else { return false }

                if contribution.moderationStatus == .approved {
                    return true
                }

                return contribution.moderationStatus == .pending
                    && contribution.createdByUserID == session.currentUser?.id
            }
            .sorted { $0.createdDate > $1.createdDate }
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

    private var dateBadgeText: String {
        currentEvent.eventDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var shortLocation: String {
        let parts = currentEvent.address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return parts.dropFirst().first ?? parts.first ?? currentEvent.address
    }

    private var detailTags: [String] {
        let tags = currentEvent.tags.isEmpty ? [currentEvent.category.rawValue] : currentEvent.tags
        return tags.prefix(4).map(\.self)
    }

    private func followButtonTitle(for user: PopioUser) -> String {
        switch session.relationshipState(with: user) {
        case .none:
            return "Follow"
        case .outgoingPending:
            return "Sent"
        case .incomingPending:
            return "Respond"
        case .friends:
            return "Following"
        }
    }

    private func followButtonTint(for user: PopioUser) -> Color {
        switch session.relationshipState(with: user) {
        case .none:
            return PopioTheme.gold
        case .outgoingPending:
            return PopioTheme.muted
        case .incomingPending, .friends:
            return PopioTheme.accent
        }
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

private struct AdminEventEditor: View {
    @Environment(\.dismiss) private var dismiss

    let event: PopioEvent
    let save: (PopioEvent) async throws -> Void

    @State private var title: String
    @State private var description: String
    @State private var category: EventCategory
    @State private var address: String
    @State private var eventDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var hasStartTime: Bool
    @State private var hasEndTime: Bool
    @State private var tags: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(event: PopioEvent, save: @escaping (PopioEvent) async throws -> Void) {
        self.event = event
        self.save = save
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description)
        _category = State(initialValue: event.category)
        _address = State(initialValue: event.address)
        _eventDate = State(initialValue: event.eventDate)
        _startTime = State(initialValue: event.startTime ?? event.eventDate)
        _endTime = State(initialValue: event.endTime ?? event.startTime ?? event.eventDate)
        _hasStartTime = State(initialValue: event.startTime != nil)
        _hasEndTime = State(initialValue: event.endTime != nil)
        _tags = State(initialValue: event.tags.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    editorHeader
                    fieldSection("Event details") {
                        editorTextField("Event name", text: $title)

                        Picker("Category", selection: $category) {
                            ForEach(EventCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .tint(PopioTheme.gold)

                        TextField("Description", text: $description, axis: .vertical)
                            .lineLimit(4...8)
                            .popioField()
                    }

                    fieldSection("Location") {
                        editorTextField("Address", text: $address)
                    }

                    fieldSection("Schedule") {
                        DatePicker("Event date", selection: $eventDate, displayedComponents: .date)

                        Toggle("Start time", isOn: $hasStartTime)
                            .tint(PopioTheme.gold)
                        if hasStartTime {
                            DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                        }

                        Toggle("End time", isOn: $hasEndTime)
                            .tint(PopioTheme.gold)
                        if hasEndTime {
                            DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                        }
                    }

                    fieldSection("Tags") {
                        editorTextField("Comma-separated tags", text: $tags)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(PopioFont.caption(.semibold))
                            .foregroundStyle(PopioTheme.coral)
                    }
                }
                .padding(16)
                .padding(.bottom, 88)
            }
            .scrollIndicators(.hidden)
            .background(PopioTheme.background)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    Task { await persistChanges() }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(PopioFont.custom(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(PopioTheme.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(PopioTheme.backgroundElevated)
            }
        }
    }

    private var editorHeader: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundStyle(PopioTheme.muted)
            Spacer()
            Text("Edit Pop-up")
                .font(PopioFont.custom(size: 20, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)
            Spacer()
            Text("Cancel").hidden()
        }
        .frame(height: 44)
    }

    private func fieldSection<Content: View>(
        _ heading: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(PopioFont.custom(size: 15, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)
            content()
        }
        .popioCard(cornerRadius: 22, padding: 16)
    }

    private func editorTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .popioField()
    }

    private func persistChanges() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedAddress.isEmpty else {
            errorMessage = "An event name and address are required."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var updatedEvent = event
            updatedEvent.title = trimmedTitle
            updatedEvent.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedEvent.category = category
            updatedEvent.address = trimmedAddress
            updatedEvent.eventDate = eventDate
            updatedEvent.startTime = hasStartTime ? startTime : nil
            updatedEvent.endTime = hasEndTime ? endTime : nil
            updatedEvent.tags = tags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if trimmedAddress.caseInsensitiveCompare(event.address) != .orderedSame {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = trimmedAddress
                guard let coordinate = try await MKLocalSearch(request: request).start().mapItems.first?.placemark.coordinate else {
                    throw AdminEventEditorError.locationNotFound
                }
                updatedEvent.latitude = coordinate.latitude
                updatedEvent.longitude = coordinate.longitude
            }

            try await save(updatedEvent)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum AdminEventEditorError: LocalizedError {
    case locationNotFound

    var errorDescription: String? {
        "That address could not be located. Try a more specific address."
    }
}

private struct EventRejectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let eventTitle: String
    let reject: (String) async throws -> Void

    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let characterLimit = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(PopioTheme.ink.opacity(0.14))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Image(systemName: "text.bubble.fill")
                    .font(PopioFont.custom(size: 18, weight: .semibold))
                    .foregroundStyle(PopioTheme.coral)
                    .frame(width: 42, height: 42)
                    .background(PopioTheme.coral.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Why is this pop-up being rejected?")
                        .font(PopioFont.custom(size: 17, weight: .semibold))
                        .foregroundStyle(PopioTheme.ink)

                    Text(eventTitle)
                        .font(PopioFont.custom(size: 12.5, weight: .medium))
                        .foregroundStyle(PopioTheme.muted)
                        .lineLimit(1)
                }
            }

            TextField("Share a clear reason with the event creator...", text: $comment, axis: .vertical)
                .lineLimit(5...7)
                .font(PopioFont.custom(size: 14, weight: .medium))
                .foregroundStyle(PopioTheme.ink)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PopioTheme.coral.opacity(0.30), lineWidth: 1)
                }
                .onChange(of: comment) { _, newValue in
                    guard newValue.count > characterLimit else { return }
                    comment = String(newValue.prefix(characterLimit))
                }

            HStack {
                Text("The creator will receive this in their mailbox.")
                    .font(PopioFont.custom(size: 11, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)

                Spacer()

                Text("\(comment.count)/\(characterLimit)")
                    .font(PopioFont.custom(size: 11, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)
                    .monospacedDigit()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(PopioFont.caption(.semibold))
                    .foregroundStyle(PopioTheme.coral)
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    dismiss()
                }
                .font(PopioFont.custom(size: 14, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PopioTheme.line, lineWidth: 1)
                }

                Button {
                    Task {
                        isSubmitting = true
                        errorMessage = nil
                        defer { isSubmitting = false }

                        do {
                            try await reject(comment)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Text(isSubmitting ? "Sending..." : "Reject & Send")
                        .font(PopioFont.custom(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .foregroundStyle(.white)
                .background(PopioTheme.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .opacity(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting ? 0.55 : 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [Color.white, PopioTheme.coral.opacity(0.07), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
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
    var foreground: Color = PopioTheme.ink
    var background: Color = .white

    var body: some View {
        Image(systemName: systemImage)
            .font(PopioFont.custom(size: 15.5, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: 42, height: 42)
            .background(background, in: Circle())
            .overlay {
                Circle()
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
            .shadow(color: PopioTheme.shadow.opacity(0.12), radius: 8, y: 4)
    }
}

private struct EventDetailBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(PopioFont.custom(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct GoingUsersStack: View {
    let users: [PopioUser]
    let totalCount: Int

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                    ProfileAvatarView(user: user, size: 30)
                        .offset(x: CGFloat(index) * 20)
                        .zIndex(Double(users.count - index))
                }
            }
            .frame(width: CGFloat(max(users.count - 1, 0)) * 20 + 30, height: 32, alignment: .leading)

            Text(goingText)
                .font(PopioFont.custom(size: 12.5, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(PopioTheme.accentSoft.opacity(0.70), in: Capsule())
        .overlay {
            Capsule()
                .stroke(PopioTheme.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private var goingText: String {
        if totalCount == 1 {
            return "1 person is going"
        }

        return "\(totalCount) people are going"
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
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .stroke(PopioTheme.gold.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct EventPhotoGridTile: View {
    let contribution: EventContribution
    let category: EventCategory
    var isPending = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            BannerImageView(
                imageData: contribution.imageData,
                imageURL: contribution.imageURL,
                category: category,
                focusY: 0.5
            )
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(Rectangle())

            if isPending {
                Text("Pending")
                    .font(PopioFont.custom(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Color.black.opacity(0.54), in: Capsule())
                    .padding(6)
            }
        }
    }
}

private struct EventExpandedPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSession
    let contribution: EventContribution
    let category: EventCategory
    @State private var activeReportRequest: UGCReportRequest?
    @State private var isConfirmingBlock = false

    private var currentContribution: EventContribution {
        session.eventContributions.first { $0.id == contribution.id } ?? contribution
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            BannerImageView(
                imageData: currentContribution.imageData,
                imageURL: currentContribution.imageURL,
                category: category,
                focusY: 0.5
            )
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            VStack {
                HStack(alignment: .top) {
                    Text("PC: @\(currentContribution.creatorUsername)")
                        .font(PopioFont.custom(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Color.black.opacity(0.42), in: Capsule())

                    Spacer()

                    HStack(spacing: 8) {
                        if currentContribution.createdByUserID != session.currentUser?.id {
                            photoSafetyMenu
                        }

                        if currentContribution.moderationStatus == .approved {
                            photoLikeButton
                        } else {
                            pendingReviewBadge
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()
            }

            VStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(PopioFont.custom(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(Color.black.opacity(0.48), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }
        }
        .sheet(item: $activeReportRequest) { request in
            UGCReportSheet(request: request)
                .environmentObject(session)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.hidden)
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: $isConfirmingBlock,
            titleVisibility: .visible
        ) {
            Button("Block User", role: .destructive) {
                session.blockUser(currentContribution.createdByUserID)
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer see this user's pop-ups, photos, or chat messages.")
        }
    }

    private var photoSafetyMenu: some View {
        Menu {
            Button(role: .destructive) {
                activeReportRequest = UGCReportRequest(
                    targetType: .photo,
                    targetID: currentContribution.id,
                    reportedUserID: currentContribution.createdByUserID,
                    reportedUsername: currentContribution.creatorUsername,
                    title: "Report Photo"
                )
            } label: {
                Label("Report Photo", systemImage: "flag")
            }

            Button(role: .destructive) {
                isConfirmingBlock = true
            } label: {
                Label("Block @\(currentContribution.creatorUsername)", systemImage: "hand.raised")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(PopioFont.custom(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.42), in: Circle())
        }
        .accessibilityLabel("Photo safety options")
    }

    private var photoLikeButton: some View {
        Button {
            session.toggleLike(for: currentContribution)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: session.isLikedByCurrentUser(currentContribution) ? "heart.fill" : "heart")
                    .font(PopioFont.custom(size: 16, weight: .semibold))

                Text("\(currentContribution.likeCount)")
                    .font(PopioFont.custom(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(session.isLikedByCurrentUser(currentContribution) ? PopioTheme.coral : .white)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.black.opacity(0.42), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.isLikedByCurrentUser(currentContribution) ? "Unlike photo" : "Like photo")
    }

    private var pendingReviewBadge: some View {
        Text("Pending review")
            .font(PopioFont.custom(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.black.opacity(0.42), in: Capsule())
    }
}

struct UGCReportRequest: Identifiable, Hashable {
    let id = UUID()
    let targetType: UserContentReportTargetType
    let targetID: String
    let reportedUserID: String
    let reportedUsername: String
    let title: String
}

private struct UGCReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSession
    let request: UGCReportRequest
    @State private var selectedReason = "Inappropriate content"
    @State private var details = ""
    @State private var didSubmit = false
    @State private var isSubmitting = false
    @State private var submissionError: String?

    private let reasons = [
        "Inappropriate content",
        "Harassment or hate",
        "Spam or scam",
        "False or misleading",
        "Other"
    ]
    private let characterLimit = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.black.opacity(0.14))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(request.title)
                    .font(PopioFont.custom(size: 18, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)

                Text("Report @\(request.reportedUsername). Our team will review this.")
                    .font(PopioFont.custom(size: 12.5, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)
            }

            Picker("Reason", selection: $selectedReason) {
                ForEach(reasons, id: \.self) { reason in
                    Text(reason).tag(reason)
                }
            }
            .pickerStyle(.menu)
            .tint(PopioTheme.gold)

            TextField("Add details for the reviewer...", text: $details, axis: .vertical)
                .lineLimit(4...6)
                .font(PopioFont.custom(size: 14, weight: .medium))
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PopioTheme.line, lineWidth: 1)
                }
                .onChange(of: details) { _, newValue in
                    if newValue.count > characterLimit {
                        details = String(newValue.prefix(characterLimit))
                    }
                }

            HStack {
                Text("\(details.count)/\(characterLimit)")
                    .font(PopioFont.custom(size: 11, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)
                    .monospacedDigit()

                Spacer()

                if didSubmit {
                    Text("Report submitted.")
                        .font(PopioFont.custom(size: 12, weight: .semibold))
                        .foregroundStyle(PopioTheme.accent)
                }
            }

            if let submissionError {
                Label(submissionError, systemImage: "exclamationmark.triangle.fill")
                    .font(PopioFont.custom(size: 12, weight: .semibold))
                    .foregroundStyle(PopioTheme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    isSubmitting = true
                    submissionError = nil
                    defer { isSubmitting = false }

                    do {
                        try await session.reportContent(
                            targetType: request.targetType,
                            targetID: request.targetID,
                            reportedUserID: request.reportedUserID,
                            reason: selectedReason,
                            details: details
                        )
                        didSubmit = true
                        try? await Task.sleep(for: .milliseconds(550))
                        dismiss()
                    } catch {
                        submissionError = error.localizedDescription
                    }
                }
            } label: {
                Label(isSubmitting ? "Submitting..." : "Submit Report", systemImage: "flag.fill")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(PopioTheme.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(didSubmit || isSubmitting)
            .opacity(didSubmit || isSubmitting ? 0.65 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .background(PopioTheme.background.ignoresSafeArea())
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
    @State private var activeReportRequest: UGCReportRequest?
    @State private var userIDToBlock: String?
    private let tabBarClearance: CGFloat = 46

    private var currentEvent: PopioEvent {
        session.events.first { $0.id == event.id } ?? event
    }

    private var messages: [EventContribution] {
        session.approvedContributions(for: currentEvent, type: .review)
            .sorted { $0.createdDate < $1.createdDate }
    }

    private var messageIDs: [String] {
        messages.map(\.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty {
                        ChatEmptyState()
                            .padding(.horizontal, 16)
                            .padding(.top, 112)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(messages) { message in
                                ChatMessageBubble(
                                    contribution: message,
                                    isCurrentUser: message.createdByUserID == session.currentUser?.id,
                                    isLiked: session.isLikedByCurrentUser(message),
                                    likeCount: message.likeCount,
                                    toggleLike: {
                                        session.toggleLike(for: message)
                                    },
                                    report: {
                                        activeReportRequest = UGCReportRequest(
                                            targetType: .chatMessage,
                                            targetID: message.id,
                                            reportedUserID: message.createdByUserID,
                                            reportedUsername: message.creatorUsername,
                                            title: "Report Message"
                                        )
                                    },
                                    block: {
                                        userIDToBlock = message.createdByUserID
                                    }
                                )
                                .id(message.id)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .bottom)
                                            .combined(with: .opacity)
                                            .combined(with: .scale(scale: 0.96, anchor: .bottom)),
                                        removal: .opacity
                                    )
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 18 + tabBarClearance)
                        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: messageIDs)
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
            .padding(.top, 4)
            .padding(.bottom, 4 + tabBarClearance)
            .background(PopioTheme.backgroundElevated)
        }
        .sheet(item: $activeReportRequest) { request in
            UGCReportSheet(request: request)
                .environmentObject(session)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.hidden)
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: Binding(
                get: { userIDToBlock != nil },
                set: { if !$0 { userIDToBlock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block User", role: .destructive) {
                if let userIDToBlock {
                    session.blockUser(userIDToBlock)
                    self.userIDToBlock = nil
                }
            }

            Button("Cancel", role: .cancel) {
                userIDToBlock = nil
            }
        } message: {
            Text("You will no longer see this user's pop-ups, photos, or chat messages.")
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

                Text(currentEvent.isArchived ? "Archived event · Chat history" : "Event chat")
                    .font(PopioFont.custom(size: 12, weight: .medium))
                    .foregroundStyle(currentEvent.isArchived ? PopioTheme.gold : PopioTheme.muted)
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
    let isLiked: Bool
    let likeCount: Int
    let toggleLike: () -> Void
    let report: () -> Void
    let block: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
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

                messageBubble

                if !isCurrentUser {
                    HStack(spacing: 10) {
                        Button(action: report) {
                            Label("Report", systemImage: "flag")
                                .labelStyle(.titleAndIcon)
                        }

                        Button(action: block) {
                            Label("Block", systemImage: "hand.raised")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(PopioFont.custom(size: 10.5, weight: .semibold))
                    .foregroundStyle(PopioTheme.muted)
                    .padding(.horizontal, 4)
                    .buttonStyle(.plain)
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

    private var messageBubble: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 5) {
            Text(contribution.text.isEmpty ? "Message" : contribution.text)
                .font(PopioFont.custom(size: 14, weight: .medium))
                .foregroundStyle(isCurrentUser ? .white : PopioTheme.ink)
                .lineSpacing(2)

            if isCurrentUser {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(PopioFont.custom(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.82))

                    Text("\(likeCount)")
                        .font(PopioFont.custom(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .monospacedDigit()
                }
                .accessibilityLabel("\(likeCount) likes")
            } else {
                Button(action: toggleLike) {
                    HStack(spacing: 3) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(PopioFont.custom(size: 9.5, weight: .semibold))
                            .foregroundStyle(isLiked ? PopioTheme.coral : PopioTheme.muted)

                        Text("\(likeCount)")
                            .font(PopioFont.custom(size: 9.5, weight: .semibold))
                            .foregroundStyle(PopioTheme.muted)
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isLiked ? "Unlike message" : "Like message")
            }
        }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if !isCurrentUser {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PopioTheme.line, lineWidth: 1)
                }
            }
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
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(PopioFont.custom(size: 14, weight: .medium))
                .foregroundStyle(PopioTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(PopioFont.custom(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(Color.black.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct ChatEmptyState: View {
    var body: some View {
        Image("nomsgyet")
            .resizable()
            .scaledToFit()
            .frame(width: 270, height: 270)
            .accessibilityLabel("No messages yet")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
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
