import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var viewModel = FriendsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchField
                    requestsSection
                    friendsSection
                    suggestionsSection
                }
                .padding(16)
                .padding(.bottom, 88)
            }
            .scrollIndicators(.hidden)
            .background(PopioTheme.background)
            .navigationTitle("")
            .refreshable {
                await session.refreshRemoteData()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(PopioFont.custom(size: 15, weight: .bold))
                .foregroundStyle(PopioTheme.accent)

            TextField("Search users", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .popioField()
    }

    private var suggestionsSection: some View {
        let users = session.suggestedUsers(query: viewModel.searchText, limit: 3)

        return FriendSection(title: "Suggested Friends", systemImage: "person.crop.circle.badge.plus") {
            if users.isEmpty {
                FriendEmptyRow(text: "No suggestions right now.")
            } else {
                ForEach(users) { user in
                    UserRow(user: user, relationshipState: session.relationshipState(with: user)) {
                        session.sendFriendRequest(to: user)
                    }
                }
            }
        }
    }

    private var requestsSection: some View {
        let requests = viewModel.pendingIncomingRequests(in: session)

        return FriendSection(title: "Requests", systemImage: "bell.badge.fill") {
            if requests.isEmpty {
                FriendEmptyRow(text: "No pending requests.")
            } else {
                ForEach(requests) { request in
                    let user = session.users.first { $0.id == request.fromUserID }

                    UserDecisionRow(
                        user: user,
                        accept: { session.acceptFriendRequest(request) },
                        decline: { session.declineFriendRequest(request) }
                    )
                }
            }
        }
    }

    private var friendsSection: some View {
        let friends = viewModel.friends(in: session)

        return FriendSection(title: "Friends", systemImage: "person.2.fill") {
            if friends.isEmpty {
                FriendEmptyRow(text: "Accepted friends will appear here.")
            } else {
                ForEach(friends) { user in
                    HStack(spacing: 12) {
                        UserSummary(user: user)
                        Spacer()
                        Button {
                            session.removeFriend(user)
                        } label: {
                            Image(systemName: "xmark")
                                .font(PopioFont.custom(size: 13, weight: .bold))
                                .frame(width: 38, height: 38)
                        }
                        .foregroundStyle(PopioTheme.coral)
                        .background(PopioTheme.coral.opacity(0.10), in: Circle())
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove friend")
                    }
                }
            }
        }
    }
}

private struct FriendSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(PopioFont.headline(.bold))
                .foregroundStyle(PopioTheme.ink)

            VStack(spacing: 14) {
                content
            }
        }
        .popioCard(cornerRadius: 24, padding: 16)
    }
}

private struct FriendEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(PopioFont.subheadline(.semibold))
            .foregroundStyle(PopioTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}

private struct UserDecisionRow: View {
    let user: PopioUser?
    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UserSummary(user: user)

            HStack(spacing: 10) {
                Button(action: decline) {
                    Label("Decline", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .popioSecondaryButton(tint: PopioTheme.coral)

                Button(action: accept) {
                    Label("Accept", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .popioPrimaryButton()
            }
        }
    }
}

private struct UserRow: View {
    let user: PopioUser
    let relationshipState: AppSession.RelationshipState
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            UserSummary(user: user)
            Spacer(minLength: 8)
            relationshipAction
        }
    }

    @ViewBuilder
    private var relationshipAction: some View {
        switch relationshipState {
        case .none:
            Button(action: action) {
                Image(systemName: "person.badge.plus")
                    .font(PopioFont.custom(size: 15, weight: .bold))
                    .frame(width: 42, height: 42)
            }
            .foregroundStyle(PopioTheme.accent)
            .background(PopioTheme.accentSoft, in: Circle())
            .buttonStyle(.plain)
            .accessibilityLabel("Add friend")

        case .outgoingPending:
            FriendStatusPill(text: "Sent", systemImage: "paperplane.fill", tint: PopioTheme.muted)

        case .incomingPending:
            FriendStatusPill(text: "Respond", systemImage: "arrow.down.message.fill", tint: PopioTheme.accent)

        case .friends:
            FriendStatusPill(text: "Friends", systemImage: "checkmark.circle.fill", tint: PopioTheme.accent)
        }
    }
}

private struct FriendStatusPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(PopioFont.caption(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct UserSummary: View {
    let user: PopioUser?

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(user: user, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(user?.displayName ?? "Unknown user")
                    .font(PopioFont.headline(.bold))
                    .foregroundStyle(PopioTheme.ink)
                    .lineLimit(1)
                Text("@\(user?.username ?? "unknown")")
                    .font(PopioFont.subheadline(.semibold))
                    .foregroundStyle(PopioTheme.muted)
                    .lineLimit(1)
            }
        }
    }
}
