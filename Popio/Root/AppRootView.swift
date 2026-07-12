import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            if session.currentUser == nil {
                AuthenticationView()
            } else {
                MainTabView()
            }
        }
        .background(PopioTheme.background)
        .background(KeyboardDismissRegistrar())
        .preferredColorScheme(.light)
        .popioScreenFont()
        .task {
            await session.restoreSession()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var eventFeedViewModel = EventFeedViewModel()
    @State private var selectedTab: MainTab = .popUps
    @State private var isShowingCreateEvent = false
    @State private var popUpsNavigationResetID = UUID()

    var body: some View {
        currentTabView
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CompactTabBar(
                    selectedTab: Binding(
                        get: { selectedTab },
                        set: { newTab in
                            if newTab == .popUps {
                                popUpsNavigationResetID = UUID()
                            }
                            selectedTab = newTab
                        }
                    ),
                    currentUser: session.currentUser,
                    isAdmin: session.currentUser?.isAdmin == true,
                    addAction: {
                        isShowingCreateEvent = true
                    }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(isPresented: $isShowingCreateEvent) {
                CreateEventView()
            }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .popUps:
            EventFeedView(viewModel: eventFeedViewModel)
                .id(popUpsNavigationResetID)
        case .map:
            PopUpsMapPage(viewModel: eventFeedViewModel)
        case .mvps:
            LeaderboardView()
        case .popUpRequests:
            PopUpRequestsView()
        case .profile:
            ProfileView()
        }
    }
}

private struct LeaderboardView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedScope: LeaderboardScope = .thisWeek

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                leaderboardHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(LeaderboardPalette.background)
                    .zIndex(1)

                ScrollView {
                    VStack(spacing: 18) {
                    LeaderboardScopePicker(selectedScope: $selectedScope)

                    if !session.mvpLeaderboard.isEmpty {
                        LeaderboardPodium(standings: Array(session.mvpLeaderboard.prefix(3)))
                    }

                    LeaderboardTable(standings: Array(session.mvpLeaderboard.dropFirst(3)))

                    LeaderboardCallout()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 112)
                }
                .scrollIndicators(.hidden)
            }
            .background(LeaderboardPalette.background.ignoresSafeArea())
            .navigationTitle("")
        }
    }

    private var leaderboardHeader: some View {
        HStack {
            Spacer()

            Text("Leaderboards")
                .font(PopioFont.custom(size: 20, weight: .semibold))
                .foregroundStyle(LeaderboardPalette.ink)

            Spacer()
        }
        .frame(minHeight: 44)
    }
}

private enum LeaderboardScope: String, CaseIterable {
    case thisWeek = "This Week"
    case allTime = "All Time"
}

private enum LeaderboardPalette {
    static let background = PopioTheme.background
    static let ink = PopioTheme.ink
    static let muted = PopioTheme.muted
    static let orange = PopioTheme.gold
    static let gold = PopioTheme.gold
    static let silver = PopioTheme.accent
    static let bronze = PopioTheme.coral.opacity(0.86)
    static let cardSoft = PopioTheme.surface
    static let line = PopioTheme.line
    static let shadow = PopioTheme.shadow
}

private struct LeaderboardScopePicker: View {
    @Binding var selectedScope: LeaderboardScope

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        selectedScope = scope
                    }
                } label: {
                    Text(scope.rawValue)
                        .font(PopioFont.custom(size: 15, weight: .semibold))
                        .foregroundStyle(selectedScope == scope ? LeaderboardPalette.gold : LeaderboardPalette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .background {
                    if selectedScope == scope {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: LeaderboardPalette.shadow.opacity(0.55), radius: 10, x: 0, y: 5)
                    }
                }
            }
        }
        .padding(4)
        .background(LeaderboardPalette.gold.opacity(0.12), in: Capsule())
    }
}

private struct LeaderboardPodium: View {
    let standings: [AppSession.MVPStanding]

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if let second = standing(rank: 2) {
                PodiumCard(standing: second, style: .second)
            }

            if let first = standing(rank: 1) {
                PodiumCard(standing: first, style: .first)
            }

            if let third = standing(rank: 3) {
                PodiumCard(standing: third, style: .third)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func standing(rank: Int) -> AppSession.MVPStanding? {
        standings.first { $0.rank == rank }
    }
}

private enum PodiumStyle {
    case first
    case second
    case third

    var height: CGFloat {
        switch self {
        case .first:
            return 156
        case .second, .third:
            return 134
        }
    }

    var avatarSize: CGFloat {
        switch self {
        case .first:
            return 52
        case .second, .third:
            return 44
        }
    }

    var rankColor: Color {
        switch self {
        case .first:
            return LeaderboardPalette.gold
        case .second:
            return LeaderboardPalette.silver
        case .third:
            return LeaderboardPalette.bronze
        }
    }

    var cardColor: Color {
        switch self {
        case .first:
            return Color.white
        case .second, .third:
            return Color.white
        }
    }
}

private struct PodiumCard: View {
    let standing: AppSession.MVPStanding
    let style: PodiumStyle

    var body: some View {
        VStack(spacing: style == .first ? 7 : 6) {
            rankBadge
                .offset(y: -14)
                .padding(.bottom, -14)
                .zIndex(2)

            if style == .first {
                Image(systemName: "crown.fill")
                    .font(PopioFont.custom(size: 20, weight: .bold))
                    .foregroundStyle(LeaderboardPalette.gold)
                    .offset(y: 5)
                    .padding(.top, -3)
                    .padding(.bottom, -5)
            }

            ProfileAvatarView(user: standing.user, size: style.avatarSize)

            Text(standing.user.username)
                .font(PopioFont.custom(size: style == .first ? 14 : 12, weight: .bold))
                .foregroundStyle(LeaderboardPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, style == .first ? 1 : 3)

            Text("\(standing.points.formatted()) pts")
                .font(PopioFont.custom(size: style == .first ? 15 : 12, weight: .bold))
                .foregroundStyle(LeaderboardPalette.gold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, style == .first ? 16 : 14)
        .frame(maxWidth: .infinity)
        .frame(height: style.height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(style.cardColor)
        )
        .shadow(color: LeaderboardPalette.shadow.opacity(0.65), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(standing.rank), \(standing.user.username), \(standing.points) points")
    }

    private var rankBadge: some View {
        Text("\(standing.rank)")
            .font(PopioFont.custom(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(style.rankColor, in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
            }
            .shadow(color: LeaderboardPalette.shadow.opacity(0.35), radius: 5, x: 0, y: 2)
    }
}

private struct LeaderboardTable: View {
    let standings: [AppSession.MVPStanding]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Rank")
                    .frame(width: 42, alignment: .leading)

                Text("User")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Points")
                    .frame(width: 76, alignment: .trailing)
            }
            .font(PopioFont.custom(size: 13, weight: .semibold))
            .foregroundStyle(LeaderboardPalette.muted)
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 10)

            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                LeaderboardRow(
                    standing: standing,
                    isLast: index == standings.count - 1
                )
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LeaderboardPalette.line, lineWidth: 1)
        }
        .shadow(color: LeaderboardPalette.shadow.opacity(0.65), radius: 14, x: 0, y: 7)
    }
}

private struct PopUpsMapPage: View {
    @EnvironmentObject private var session: AppSession
    @ObservedObject var viewModel: EventFeedViewModel

    var body: some View {
        EventMapView(
            events: viewModel.filteredEvents(from: session.approvedEvents),
            centerCoordinate: viewModel.effectiveCoordinate,
            userCoordinate: viewModel.userCoordinate,
            distanceProvider: viewModel.distanceInMiles(for:),
            requestUserLocation: viewModel.requestUserLocation,
            viewModel: viewModel
        )
        .environmentObject(session)
    }
}

private struct LeaderboardRow: View {
    let standing: AppSession.MVPStanding
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(standing.rank)")
                    .font(PopioFont.custom(size: 15, weight: .bold))
                    .foregroundStyle(LeaderboardPalette.ink)
                    .monospacedDigit()
                    .frame(width: 42, alignment: .center)

                ProfileAvatarView(user: standing.user, size: 34)

                Text(standing.user.username)
                    .font(PopioFont.custom(size: 14, weight: .semibold))
                    .foregroundStyle(LeaderboardPalette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(standing.points.formatted()) pts")
                    .font(PopioFont.custom(size: 14, weight: .semibold))
                    .foregroundStyle(LeaderboardPalette.gold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: 76, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if !isLast {
                Divider()
                    .padding(.leading, 58)
                    .padding(.trailing, 14)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(standing.rank), \(standing.user.username), \(standing.points) points")
    }
}

private struct LeaderboardCallout: View {
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "trophy.fill")
                .font(PopioFont.custom(size: 25, weight: .bold))
                .foregroundStyle(LeaderboardPalette.gold)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                Text("Keep showing up!")
                    .font(PopioFont.custom(size: 15, weight: .bold))
                    .foregroundStyle(LeaderboardPalette.ink)

                Text("Check in at pop-ups and earn points. Climb the leaderboard!")
                    .font(PopioFont.custom(size: 13, weight: .medium))
                    .foregroundStyle(LeaderboardPalette.muted)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(LeaderboardPalette.cardSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: 1)
        }
        .shadow(color: LeaderboardPalette.shadow.opacity(0.45), radius: 16, x: 0, y: 8)
    }
}

private enum MainTab: CaseIterable, Hashable {
    case popUps
    case map
    case mvps
    case popUpRequests
    case profile

    var title: String {
        switch self {
        case .popUps:
            return "Pop-Ups"
        case .map:
            return "Map"
        case .mvps:
            return "Leaderboard"
        case .popUpRequests:
            return "Requests"
        case .profile:
            return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .popUps:
            return "storefront"
        case .map:
            return "mappin"
        case .mvps:
            return "trophy"
        case .popUpRequests:
            return "tray.full"
        case .profile:
            return "person.crop.circle"
        }
    }
}

private struct CompactTabBar: View {
    @Binding var selectedTab: MainTab
    let currentUser: PopioUser?
    let isAdmin: Bool
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.popUps)
            tabButton(.map)
            addButton
            tabButton(.mvps)
            if isAdmin {
                tabButton(.popUpRequests)
            }
            tabButton(.profile)
        }
        .padding(.horizontal, 9)
        .padding(.top, 1)
        .padding(.bottom, 0)
        .offset(y: 3)
        .background {
            Color.white
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(height: 1)
            .allowsHitTesting(false)
        }
    }

    private func tabButton(_ tab: MainTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            tabIcon(for: tab)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .foregroundStyle(selectedTab == tab ? PopioTheme.gold : PopioTheme.muted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }

    @ViewBuilder
    private func tabIcon(for tab: MainTab) -> some View {
        if tab == .profile {
            ProfileAvatarView(user: currentUser, size: 26)
                .overlay {
                    Circle()
                        .stroke(selectedTab == .profile ? PopioTheme.gold : Color.white.opacity(0.95), lineWidth: 2)
                }
        } else {
            Image(systemName: tab.systemImage)
                .font(PopioFont.custom(size: 18, weight: .semibold))
                .frame(width: 38, height: 38)
        }
    }

    private var addButton: some View {
        Button {
            addAction()
        } label: {
            Image(systemName: "plus.app.fill")
                .font(PopioFont.custom(size: 25, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .foregroundStyle(PopioTheme.gold)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add pop-up")
    }

}

private struct PopUpRequestsView: View {
    @EnvironmentObject private var session: AppSession
    @State private var reviewComments: [String: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                if session.pendingEventRequests.isEmpty && session.pendingContributionRequests.isEmpty {
                    EmptyStateView(
                        systemImage: "checkmark.seal",
                        title: "No pending requests",
                        message: "Submitted pop-ups and content waiting for review will appear here."
                    )
                    .listRowBackground(Color.clear)
                } else {
                    if !session.pendingEventRequests.isEmpty {
                        Section("Pop-Ups") {
                            ForEach(session.pendingEventRequests) { event in
                                eventRequestRow(for: event)
                            }
                        }
                    }

                    if !session.pendingContributionRequests.isEmpty {
                        Section("Pictures and Reviews") {
                            ForEach(session.pendingContributionRequests) { contribution in
                                contributionRequestRow(for: contribution)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PopioTheme.background)
            .navigationTitle("")
        }
    }

    private func eventRequestRow(for event: PopioEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EventBannerImageView(event: event)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.title)
                        .font(PopioFont.headline())
                    Spacer()
                    CategoryBadge(category: event.category)
                }

                Text("@\(event.creatorUsername)")
                    .font(PopioFont.subheadline(.semibold))
                    .foregroundStyle(PopioTheme.muted)

                if event.hasMenuImage {
                    Label("Menu photo attached", systemImage: "menucard.fill")
                        .font(PopioFont.caption(.semibold))
                        .foregroundStyle(PopioTheme.accent)
                }

                Label(event.address, systemImage: "mappin.and.ellipse")
                    .font(PopioFont.caption(.semibold))
                    .foregroundStyle(PopioTheme.muted)
            }

            TextField("Review comment", text: Binding(
                get: { reviewComments[event.id, default: ""] },
                set: { reviewComments[event.id] = $0 }
            ), axis: .vertical)
            .lineLimit(2...4)
            .popioField()

            HStack(spacing: 10) {
                Button {
                    session.reviewEvent(event, status: .rejected, comment: reviewComments[event.id, default: ""])
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .popioSecondaryButton(tint: PopioTheme.gold)

                Button {
                    session.reviewEvent(event, status: .approved, comment: reviewComments[event.id, default: ""])
                } label: {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .popioPrimaryButton()
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(PopioTheme.backgroundElevated)
    }

    private func contributionRequestRow(for contribution: EventContribution) -> some View {
        let event = session.events.first { $0.id == contribution.eventID }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(contribution.type.rawValue)
                    .font(PopioFont.headline())
                Spacer()
                Text(event?.title ?? "Unknown event")
                    .font(PopioFont.caption(.semibold))
                    .foregroundStyle(PopioTheme.muted)
            }

            Text("@\(contribution.creatorUsername)")
                .font(PopioFont.subheadline(.semibold))
                .foregroundStyle(PopioTheme.muted)

            if contribution.type == .picture {
                BannerImageView(
                    imageData: contribution.imageData,
                    imageURL: contribution.imageURL,
                    category: event?.category ?? .food,
                    focusY: 0.5
                )
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !contribution.text.isEmpty {
                Text(contribution.text)
                    .font(PopioFont.subheadline())
                    .foregroundStyle(PopioTheme.ink)
            }

            TextField("Review comment", text: Binding(
                get: { reviewComments[contribution.id, default: ""] },
                set: { reviewComments[contribution.id] = $0 }
            ), axis: .vertical)
            .lineLimit(2...4)
            .popioField()

            HStack(spacing: 10) {
                Button {
                    session.reviewContribution(
                        contribution,
                        status: .rejected,
                        comment: reviewComments[contribution.id, default: ""]
                    )
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .popioSecondaryButton(tint: PopioTheme.gold)

                Button {
                    session.reviewContribution(
                        contribution,
                        status: .approved,
                        comment: reviewComments[contribution.id, default: ""]
                    )
                } label: {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .popioPrimaryButton()
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(PopioTheme.backgroundElevated)
    }
}
