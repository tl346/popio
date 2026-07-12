import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isShowingEditProfile = false
    @State private var editProfileInitialFocus: EditProfileFocusedField?
    @State private var isShowingProfileMenu = false
    @State private var selectedActivityTab: ProfileActivityTab = .going

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                profileTopBar

                ScrollView {
                    VStack(spacing: 22) {
                        profileHeader
                        statsRow
                        activitySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
            }
            .background(PopioTheme.background)
            .navigationTitle("")
            .onAppear {
                viewModel.load(from: session.currentUser)
            }
            .sheet(isPresented: $isShowingEditProfile) {
                EditProfileView(
                    viewModel: viewModel,
                    isPresented: $isShowingEditProfile,
                    initialFocus: editProfileInitialFocus
                )
                    .environmentObject(session)
            }
            .sheet(isPresented: $isShowingProfileMenu) {
                ProfileOptionsSheet(
                    editProfile: {
                        viewModel.load(from: session.currentUser)
                        editProfileInitialFocus = nil
                        isShowingProfileMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isShowingEditProfile = true
                        }
                    },
                    signOut: {
                        isShowingProfileMenu = false
                        Task {
                            try? await session.logout()
                        }
                    }
                )
                .presentationDetents([.height(230)])
                .presentationDragIndicator(.hidden)
            }
            .navigationDestination(for: PopioEvent.self) { event in
                EventDetailView(event: event)
            }
        }
    }

    private var profileTopBar: some View {
        HStack(spacing: 10) {
            Image("appicontransparent")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .accessibilityLabel("Popio")

            Spacer()

            Button {
                isShowingProfileMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(PopioFont.custom(size: 17, weight: .bold))
                    .foregroundStyle(ProfilePalette.orange)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile options")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(PopioTheme.background)
        .zIndex(2)
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ProfileHeroAvatar(user: session.currentUser)

            VStack(spacing: 8) {
                Text(profileFullName)
                    .font(PopioFont.custom(size: 24, weight: .semibold))
                    .foregroundStyle(ProfilePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                InstagramProfilePill(handle: profileInstagramHandle)

                Text(profileBio)
                    .font(PopioFont.custom(size: 14.5, weight: .medium))
                    .foregroundStyle(ProfilePalette.body)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 18)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            ProfileStatBlock(
                systemImage: "star.fill",
                value: "\(pointsCount.formatted())",
                label: "Points",
                tint: PopioTheme.coral
            )

            ProfileStatDivider()

            ProfileStatBlock(
                systemImage: "checkmark.circle",
                value: "\(goingEvents.count)",
                label: "Going",
                tint: ProfilePalette.orange
            )

            ProfileStatDivider()

            NavigationLink {
                FriendsView()
            } label: {
                ProfileStatBlock(
                    systemImage: "person.2",
                    value: "\(followersCount)",
                    label: "Followers",
                    tint: PopioTheme.accent
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show followers list")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProfileActivityPicker(selectedTab: $selectedActivityTab)

            VStack(spacing: 0) {
                switch selectedActivityTab {
                case .going:
                    activityEventsList(goingEvents, emptyText: "Pop-ups you're going to will appear here.")
                case .interested:
                    activityEventsList(interestedEvents, emptyText: "Hearted pop-ups will appear here.")
                case .activeChats:
                    activeChatsList
                }
            }
        }
    }

    @ViewBuilder
    private func activityEventsList(_ events: [PopioEvent], emptyText: String) -> some View {
        if events.isEmpty {
            ProfileEmptyActivityRow(text: emptyText)
        } else {
            ForEach(Array(events.prefix(6).enumerated()), id: \.element.id) { index, event in
                NavigationLink(value: event) {
                    ProfileEventActivityRow(
                        event: event,
                        trailingSystemImage: selectedActivityTab == .going ? "checkmark.circle.fill" : "heart.fill",
                        isLast: index == min(events.count, 6) - 1
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var activeChatsList: some View {
        let chats = activeChats

        if chats.isEmpty {
            ProfileEmptyActivityRow(text: "Chats you start on pop-ups will appear here.")
        } else {
            ForEach(Array(chats.prefix(6).enumerated()), id: \.element.id) { index, chat in
                NavigationLink {
                    EventChatView(event: chat.event)
                } label: {
                    ProfileChatActivityRow(
                        chat: chat,
                        isLast: index == min(chats.count, 6) - 1
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var profileFullName: String {
        guard let user = session.currentUser else { return "Popio User" }
        let fullName = [user.firstName, user.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return fullName.isEmpty ? profileDisplayName : fullName
    }

    private var profileDisplayName: String {
        guard let user = session.currentUser else { return "popio_user" }
        let trimmedDisplayName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDisplayName.isEmpty ? user.username : trimmedDisplayName
    }

    private var profileSecondaryName: String {
        guard let user = session.currentUser else { return "@popio_user" }
        let username = user.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = username.isEmpty ? "@popio_user" : "@\(username)"
        return profileDisplayName.caseInsensitiveCompare(profileFullName) == .orderedSame ? handle : profileDisplayName
    }

    private var profileBio: String {
        let trimmedBio = session.currentUser?.bio.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedBio.isEmpty ? "Add a bio to tell people what pop-ups you love." : trimmedBio
    }

    private var profileInstagramHandle: String {
        session.currentUser?.instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var pointsCount: Int {
        session.mvpStanding(for: session.currentUser)?.points ?? 0
    }

    private var followersCount: Int {
        guard let currentUserID = session.currentUser?.id else { return 0 }
        return session.friendRequests.filter {
            $0.status == .accepted
                && ($0.toUserID == currentUserID || $0.fromUserID == currentUserID)
        }.count
    }

    private var interestedEvents: [PopioEvent] {
        guard let currentUserID = session.currentUser?.id else { return [] }
        return session.approvedEvents.filter { $0.likedUserIDs.contains(currentUserID) }
    }

    private var goingEvents: [PopioEvent] {
        guard let currentUserID = session.currentUser?.id else { return [] }
        return session.approvedEvents.filter { $0.goingUserIDs.contains(currentUserID) }
    }

    private var activeChats: [ProfileChatSummary] {
        guard let currentUserID = session.currentUser?.id else { return [] }
        let chatsByEventID = Dictionary(grouping: session.eventContributions
            .filter {
                $0.createdByUserID == currentUserID
                    && $0.type == .review
                    && $0.moderationStatus == .approved
            },
            by: \.eventID
        )

        return chatsByEventID.compactMap { eventID, chats -> ProfileChatSummary? in
            guard let event = session.events.first(where: { $0.id == eventID }),
                  let latestChat = chats.sorted(by: { $0.createdDate > $1.createdDate }).first else {
                return nil
            }
            return ProfileChatSummary(event: event, latestChat: latestChat)
        }
        .sorted { $0.latestChat.createdDate > $1.latestChat.createdDate }
    }

}

private enum ProfileActivityTab: String, CaseIterable {
    case going = "Going"
    case interested = "Interested"
    case activeChats = "Active Chats"
}

private enum EditProfileFocusedField: Hashable {
    case instagram
}

private struct ProfileChatSummary: Identifiable, Hashable {
    let event: PopioEvent
    let latestChat: EventContribution

    var id: String { event.id }
}

private enum ProfilePalette {
    static let ink = PopioTheme.ink
    static let body = PopioTheme.ink.opacity(0.82)
    static let muted = PopioTheme.muted
    static let orange = PopioTheme.gold
    static let orangeSoft = PopioTheme.gold.opacity(0.16)
    static let line = PopioTheme.line
    static let shadow = PopioTheme.shadow
    static let cardGradient = LinearGradient(
        colors: [
            PopioTheme.surface,
            PopioTheme.gold.opacity(0.08),
            PopioTheme.coralSoft.opacity(0.20)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct ProfileLogoMark: View {
    var body: some View {
        Image("popioicon")
            .resizable()
            .scaledToFit()
            .frame(width: 42, height: 42)
        .accessibilityLabel("Popio")
    }
}

private struct ProfileHeroAvatar: View {
    let user: PopioUser?

    var body: some View {
        ProfileAvatarView(user: user, size: 132)
            .padding(5)
            .background(
                LinearGradient(
                    colors: [
                        PopioTheme.coral.opacity(0.82),
                        PopioTheme.gold,
                        PopioTheme.accent.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .padding(4)
            .background(PopioTheme.backgroundElevated, in: Circle())
            .shadow(color: ProfilePalette.shadow.opacity(0.25), radius: 18, y: 9)
    }
}

private struct InstagramProfilePill: View {
    @Environment(\.openURL) private var openURL
    let handle: String

    private var displayHandle: String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Add Instagram" : "@\(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "@")))"
    }

    private var instagramURL: URL? {
        let normalized = handle.trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))
        guard !normalized.isEmpty else { return nil }
        return URL(string: "https://instagram.com/\(normalized)")
    }

    private var instagramAppURL: URL? {
        let normalized = handle.trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))
        guard !normalized.isEmpty else { return nil }
        return URL(string: "instagram://user?username=\(normalized)")
    }

    var body: some View {
        Group {
            if let instagramURL {
                Button {
                    if let instagramAppURL {
                        openURL(instagramAppURL) { accepted in
                            if !accepted {
                                openURL(instagramURL)
                            }
                        }
                    } else {
                        openURL(instagramURL)
                    }
                } label: {
                    pillContent
                }
                .buttonStyle(.plain)
            } else {
                pillContent
            }
        }
        .accessibilityLabel("Instagram \(displayHandle)")
    }

    private var pillContent: some View {
        HStack(spacing: 7) {
            Image("instagramlogo")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)

            Text(displayHandle)
                .font(PopioFont.custom(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(ProfilePalette.orange)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.83, blue: 0.46).opacity(0.22),
                    Color(red: 0.84, green: 0.16, blue: 0.46).opacity(0.14),
                    Color(red: 0.59, green: 0.18, blue: 0.75).opacity(0.16)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.83, blue: 0.46).opacity(0.72),
                            Color(red: 0.84, green: 0.16, blue: 0.46).opacity(0.60),
                            Color(red: 0.31, green: 0.36, blue: 0.84).opacity(0.56)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct ProfileStatBlock: View {
    let systemImage: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.15), in: Circle())

            Text(value)
                .font(PopioFont.custom(size: 15.5, weight: .semibold))
                .foregroundStyle(ProfilePalette.ink)
                .monospacedDigit()

            Text(label)
                .font(PopioFont.custom(size: 10.5, weight: .medium))
                .foregroundStyle(ProfilePalette.body)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 66)
    }
}

private struct ProfileStatDivider: View {
    var body: some View {
        Rectangle()
            .fill(ProfilePalette.line)
            .frame(width: 1, height: 62)
    }
}

private struct ProfileOptionsSheet: View {
    let editProfile: () -> Void
    let signOut: () -> Void

    var body: some View {
        MiniMenuSheet(title: "Profile") {
            HStack(spacing: 10) {
                ProfileMenuButton(
                    title: "Edit Profile",
                    systemImage: "pencil",
                    action: editProfile
                )

                ProfileMenuButton(
                    title: "Sign Out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    action: signOut
                )
            }
        }
    }
}

private struct ProfileMenuButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(PopioFont.custom(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [
                    PopioTheme.coral.opacity(0.86),
                    PopioTheme.gold.opacity(0.90),
                    PopioTheme.accent.opacity(0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileActivityPicker: View {
    @Binding var selectedTab: ProfileActivityTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileActivityTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(PopioFont.custom(size: 13, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? ProfilePalette.orange : ProfilePalette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
                .background {
                    if selectedTab == tab {
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: ProfilePalette.shadow.opacity(0.55), radius: 10, x: 0, y: 5)
                    }
                }
            }
        }
        .padding(4)
        .background(ProfilePalette.orangeSoft.opacity(0.55), in: Capsule())
    }
}

private struct ProfileEventActivityRow: View {
    let event: PopioEvent
    let trailingSystemImage: String
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                EventBannerImageView(event: event)
                    .frame(width: 82, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(PopioFont.custom(size: 14, weight: .bold))
                        .foregroundStyle(ProfilePalette.ink)
                        .lineLimit(1)

                    ProfileActivityMetaRow(systemImage: "mappin", text: event.address)
                    ProfileActivityMetaRow(systemImage: "calendar", text: Self.eventDateText(for: event))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: trailingSystemImage)
                    .font(PopioFont.custom(size: 18, weight: .bold))
                    .foregroundStyle(ProfilePalette.orange)
                    .frame(width: 42, height: 42)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(ProfilePalette.line, lineWidth: 1)
                    }
            }
            .padding(.vertical, 10)

            if !isLast {
                Divider()
            }
        }
    }

    private static func eventDateText(for event: PopioEvent) -> String {
        let day = event.eventDate.formatted(.dateTime.month(.abbreviated).day().year())

        guard let startTime = event.startTime else {
            return day
        }

        return "\(day) · \(startTime.formatted(.dateTime.hour().minute()))"
    }
}

private struct ProfileChatActivityRow: View {
    let chat: ProfileChatSummary
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(PopioFont.custom(size: 15, weight: .bold))
                    .foregroundStyle(ProfilePalette.orange)

                Text(chat.event.title)
                    .font(PopioFont.custom(size: 14, weight: .bold))
                    .foregroundStyle(ProfilePalette.ink)
                    .lineLimit(1)

                Spacer()
            }

            Text(chat.latestChat.text.isEmpty ? "Latest chat message" : chat.latestChat.text)
                .font(PopioFont.custom(size: 13, weight: .medium))
                .foregroundStyle(ProfilePalette.body)
                .lineLimit(3)
        }
        .padding(14)
        .background(ProfilePalette.orangeSoft.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ProfilePalette.orange.opacity(0.18), lineWidth: 1)
        }
        .padding(.vertical, 6)
        .padding(.bottom, isLast ? 0 : 2)
    }
}

private struct ProfileActivityMetaRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 11, weight: .semibold))
                .foregroundStyle(ProfilePalette.orange)
                .frame(width: 14)

            Text(text)
                .font(PopioFont.custom(size: 12, weight: .medium))
                .foregroundStyle(ProfilePalette.body)
                .lineLimit(1)
        }
    }
}

private struct ProfileEmptyActivityRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(PopioFont.custom(size: 13, weight: .medium))
            .foregroundStyle(ProfilePalette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
    }
}

private struct EditProfileView: View {
    @EnvironmentObject private var session: AppSession
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isPresented: Bool
    let initialFocus: EditProfileFocusedField?
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var isUploadingProfilePhoto = false
    @State private var profilePhotoError: String?
    @FocusState private var focusedField: EditProfileFocusedField?

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.16))
                .frame(width: 42, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            editHeader

            ScrollView {
                VStack(spacing: 24) {
                    avatarPreview

                    VStack(spacing: 0) {
                        EditProfileNameRow(
                            firstName: $viewModel.firstName,
                            lastName: $viewModel.lastName
                        )

                        EditProfileDivider()

                        EditProfileFieldRow(
                            systemImage: "at",
                            title: "Username",
                            text: $viewModel.username,
                            placeholder: "@username",
                            capitalization: .never,
                            keyboardType: .default
                        )

                        EditProfileDivider()

                        EditProfileFieldRow(
                            systemImage: "envelope",
                            title: "Email",
                            text: $viewModel.email,
                            placeholder: "email@example.com",
                            capitalization: .never,
                            keyboardType: .emailAddress
                        )

                        EditProfileDivider()

                        EditProfileFieldRow(
                            systemImage: "camera",
                            assetImage: "instagramlogo",
                            title: "Instagram",
                            text: $viewModel.instagramHandle,
                            placeholder: "@username",
                            capitalization: .never,
                            keyboardType: .URL,
                            focusedField: $focusedField,
                            field: .instagram
                        )

                        EditProfileDivider()

                        EditProfileBioRow(text: $viewModel.bio)
                    }
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ProfilePalette.line, lineWidth: 1)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(PopioFont.footnote(.semibold))
                            .foregroundStyle(PopioTheme.coral)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PopioTheme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if let profilePhotoError {
                        Label(profilePhotoError, systemImage: "photo.badge.exclamationmark")
                            .font(PopioFont.footnote(.semibold))
                            .foregroundStyle(PopioTheme.coral)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PopioTheme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background(EditProfilePalette.background.ignoresSafeArea())
        .onAppear {
            viewModel.load(from: session.currentUser)
            guard let initialFocus else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = initialFocus
            }
        }
        .onChange(of: selectedProfilePhoto) { _, newValue in
            guard let newValue else { return }

            Task {
                await updateProfilePhoto(from: newValue)
                selectedProfilePhoto = nil
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(30)
    }

    private var editHeader: some View {
        ZStack {
            Text("Edit Profile")
                .font(PopioFont.custom(size: 22, weight: .semibold))
                .foregroundStyle(ProfilePalette.ink)

            HStack {
                Button {
                    viewModel.load(from: session.currentUser)
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(PopioFont.custom(size: 16, weight: .semibold))
                        .foregroundStyle(ProfilePalette.ink)
                        .frame(width: 44, height: 44)
                        .background(Color.white, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(ProfilePalette.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close edit profile")

                Spacer()

                Button {
                    Task {
                        await save()
                    }
                } label: {
                    Text(viewModel.isSaving ? "Saving" : "Save")
                        .font(PopioFont.custom(size: 15, weight: .semibold))
                        .foregroundStyle(ProfilePalette.orange)
                        .frame(minWidth: 78)
                        .frame(height: 44)
                        .background(ProfilePalette.orangeSoft.opacity(0.85), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
                .opacity(viewModel.isSaving ? 0.68 : 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 2)
    }

    private var avatarPreview: some View {
        PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
            ProfileAvatarView(user: session.currentUser, size: 98)
                .overlay {
                    if isUploadingProfilePhoto {
                        Circle()
                            .fill(Color.white.opacity(0.68))
                        ProgressView()
                            .tint(ProfilePalette.orange)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(PopioFont.custom(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(ProfilePalette.orange, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        }
                }
        }
        .buttonStyle(.plain)
        .disabled(isUploadingProfilePhoto)
        .accessibilityLabel("Change profile photo")
    }

    private func updateProfilePhoto(from item: PhotosPickerItem) async {
        profilePhotoError = nil
        isUploadingProfilePhoto = true
        defer { isUploadingProfilePhoto = false }

        do {
            guard let imageData = try await jpegData(from: item) else { return }
            try await session.updateProfileImage(data: imageData)
        } catch {
            profilePhotoError = error.localizedDescription
        }
    }

    private func jpegData(from item: PhotosPickerItem) async throws -> Data? {
        guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
        guard let image = UIImage(data: data) else { return data }
        return image.jpegData(compressionQuality: 0.85)
    }

    private func save() async {
        viewModel.errorMessage = nil

        guard !viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel.errorMessage = "Handle and email are required."
            return
        }

        viewModel.isSaving = true
        defer { viewModel.isSaving = false }

        do {
            try await session.updateProfile(
                username: viewModel.username,
                email: viewModel.email,
                firstName: viewModel.firstName,
                lastName: viewModel.lastName,
                bio: viewModel.bio,
                instagramHandle: viewModel.instagramHandle
            )
            viewModel.load(from: session.currentUser)
            isPresented = false
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

private enum EditProfilePalette {
    static let background = LinearGradient(
        colors: [
            PopioTheme.backgroundElevated,
            ProfilePalette.orangeSoft.opacity(0.34),
            PopioTheme.background
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

private struct EditProfileNameRow: View {
    @Binding var firstName: String
    @Binding var lastName: String

    var body: some View {
        EditProfileRowShell(systemImage: "person", title: "Full Name") {
            HStack(spacing: 8) {
                TextField("First", text: $firstName)
                    .textInputAutocapitalization(.words)

                TextField("Last", text: $lastName)
                    .textInputAutocapitalization(.words)
            }
            .font(PopioFont.custom(size: 14, weight: .medium))
            .foregroundStyle(ProfilePalette.body)
        }
    }
}

private struct EditProfileFieldRow: View {
    let systemImage: String
    var assetImage: String? = nil
    let title: String
    @Binding var text: String
    let placeholder: String
    let capitalization: TextInputAutocapitalization
    let keyboardType: UIKeyboardType
    var focusedField: FocusState<EditProfileFocusedField?>.Binding? = nil
    var field: EditProfileFocusedField? = nil

    var body: some View {
        EditProfileRowShell(systemImage: systemImage, assetImage: assetImage, title: title) {
            textField
        }
    }

    @ViewBuilder
    private var textField: some View {
        if let focusedField, let field {
            baseTextField
                .focused(focusedField, equals: field)
        } else {
            baseTextField
        }
    }

    private var baseTextField: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(capitalization)
            .keyboardType(keyboardType)
            .disableAutocorrection(true)
            .font(PopioFont.custom(size: 14, weight: .medium))
            .foregroundStyle(ProfilePalette.body)
    }
}

private struct EditProfileBioRow: View {
    @Binding var text: String

    var body: some View {
        EditProfileRowShell(systemImage: "text.bubble", title: "Bio", alignment: .top) {
            TextField("Tell people about yourself", text: $text, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .font(PopioFont.custom(size: 14, weight: .medium))
                .foregroundStyle(ProfilePalette.body)
                .lineLimit(2...4)
        }
    }
}

private struct EditProfileRowShell<Content: View>: View {
    let systemImage: String
    var assetImage: String? = nil
    let title: String
    var alignment: VerticalAlignment = .center
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: 14) {
            Group {
                if let assetImage {
                    Image(assetImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 21, height: 21)
                } else {
                    Image(systemName: systemImage)
                        .font(PopioFont.custom(size: 20, weight: .medium))
                        .foregroundStyle(ProfilePalette.orange)
                }
            }
            .frame(width: 28)

            Text(title)
                .font(PopioFont.custom(size: 14, weight: .semibold))
                .foregroundStyle(ProfilePalette.ink)
                .frame(width: 82, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 64)
        .padding(.horizontal, 18)
        .padding(.vertical, alignment == .top ? 14 : 0)
    }
}

private struct EditProfileDivider: View {
    var body: some View {
        Rectangle()
            .fill(ProfilePalette.line)
            .frame(height: 1)
            .padding(.leading, 64)
    }
}
