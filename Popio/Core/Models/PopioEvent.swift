import CoreLocation
import Foundation

enum EventCategory: String, CaseIterable, Identifiable {
    case food = "Food"
    case matcha = "Matcha"
    case cards = "Cards"
    case farmersMarket = "Farmers Market"

    var id: String { rawValue }
}

enum EventModerationStatus: String, CaseIterable, Identifiable {
    case pending
    case approved
    case rejected

    var id: String { rawValue }
}

enum EventContributionType: String, CaseIterable, Identifiable {
    case picture = "Picture"
    case review = "Review"

    var id: String { rawValue }
}

struct EventContribution: Identifiable, Hashable {
    let id: String
    let eventID: String
    let type: EventContributionType
    let createdByUserID: String
    let creatorUsername: String
    var text: String
    var imageData: Data?
    var imageURL: URL?
    var moderationStatus: EventModerationStatus
    var moderationComment: String?
    var reviewedByUserID: String?
    var likedUserIDs: Set<String>
    var likedAtByUserID: [String: Date]
    let createdDate: Date

    var likeCount: Int {
        likedUserIDs.count
    }
}

struct PopioEvent: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var category: EventCategory
    var address: String
    var latitude: Double?
    var longitude: Double?
    var eventDate: Date
    var startTime: Date?
    var endTime: Date?
    var createdByUserID: String
    var creatorUsername: String
    var imageURL: URL?
    var imageData: Data?
    var menuImageURL: URL?
    var menuImageData: Data?
    var bannerFocusY: Double
    var tags: [String]
    var distanceInMiles: Double
    var isApproved: Bool
    var moderationStatus: EventModerationStatus
    var moderationComment: String?
    var reviewedByUserID: String?
    var likedUserIDs: Set<String>
    var likedAtByUserID: [String: Date]
    var goingUserIDs: Set<String>
    var createdDate: Date

    var likeCount: Int {
        likedUserIDs.count
    }

    var goingCount: Int {
        goingUserIDs.count
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasMenuImage: Bool {
        menuImageData != nil || menuImageURL != nil
    }
}

enum UserContentReportTargetType: String, CaseIterable, Identifiable {
    case event
    case photo
    case chatMessage
    case user

    var id: String { rawValue }
}

enum UserContentReportStatus: String, CaseIterable, Identifiable {
    case open
    case reviewed

    var id: String { rawValue }
}

struct UserContentReport: Identifiable, Hashable {
    let id: String
    let reporterUserID: String
    let reportedUserID: String
    let targetType: UserContentReportTargetType
    let targetID: String
    let reason: String
    let details: String
    var status: UserContentReportStatus
    let createdDate: Date
}

extension PopioEvent {
    static let samples: [PopioEvent] = [
        PopioEvent(
            id: "event_matcha_001",
            title: "Midtown Matcha Cart",
            description: "A rotating matcha cart serving iced strawberry matcha, hojicha, and limited pastry boxes.",
            category: .matcha,
            address: "128 Spring Street, New York, NY",
            latitude: 40.7243,
            longitude: -73.9982,
            eventDate: .now,
            startTime: .now,
            endTime: Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now,
            createdByUserID: "user_002",
            creatorUsername: "matchamap",
            imageURL: URL(string: "https://images.unsplash.com/photo-1515823064-d6e0c04616a7"),
            imageData: nil,
            menuImageURL: nil,
            menuImageData: nil,
            bannerFocusY: 0.5,
            tags: ["Outdoor", "Cashless"],
            distanceInMiles: 0.7,
            isApproved: true,
            moderationStatus: .approved,
            moderationComment: nil,
            reviewedByUserID: "user_001",
            likedUserIDs: ["user_001", "user_003"],
            likedAtByUserID: ["user_001": .now, "user_003": .now],
            goingUserIDs: ["user_001"],
            createdDate: .now
        ),
        PopioEvent(
            id: "event_cards_001",
            title: "Sunday Card Swap",
            description: "Collectors are meeting for graded cards, sealed packs, trades, and quick appraisals.",
            category: .cards,
            address: "44 Market Street, Brooklyn, NY",
            latitude: 40.7028,
            longitude: -73.9874,
            eventDate: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
            startTime: .now,
            endTime: Calendar.current.date(byAdding: .hour, value: 3, to: .now) ?? .now,
            createdByUserID: "user_003",
            creatorUsername: "cardtable",
            imageURL: URL(string: "https://images.unsplash.com/photo-1606167668584-78701c57f13d"),
            imageData: nil,
            menuImageURL: nil,
            menuImageData: nil,
            bannerFocusY: 0.5,
            tags: ["Rooftop"],
            distanceInMiles: 2.4,
            isApproved: true,
            moderationStatus: .approved,
            moderationComment: nil,
            reviewedByUserID: "user_001",
            likedUserIDs: ["user_001"],
            likedAtByUserID: ["user_001": .now],
            goingUserIDs: [],
            createdDate: .now
        )
    ]
}
