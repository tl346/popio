import FirebaseFirestore
import Foundation

struct FirebaseEventService: EventServicing {
    private let database: Firestore

    init(database: Firestore = .firestore()) {
        self.database = database
    }

    func fetchEvents(includePending: Bool, currentUserID: String?) async throws -> [PopioEvent] {
        let documents: [QueryDocumentSnapshot]
        if includePending {
            documents = try await database.collection("events").getDocuments().documents
        } else if let currentUserID {
            async let approvedSnapshot = database.collection("events")
                .whereField("moderationStatus", isEqualTo: EventModerationStatus.approved.rawValue)
                .getDocuments()
            async let ownedSnapshot = database.collection("events")
                .whereField("createdByUserID", isEqualTo: currentUserID)
                .getDocuments()
            let (approved, owned) = try await (approvedSnapshot, ownedSnapshot)
            documents = uniqueDocuments(approved.documents + owned.documents)
        } else {
            documents = try await database.collection("events")
                .whereField("moderationStatus", isEqualTo: EventModerationStatus.approved.rawValue)
                .getDocuments().documents
        }

        return documents.compactMap { document in
            try? event(from: document)
        }
        .sorted { $0.eventDate < $1.eventDate }
    }

    func createEvent(_ event: PopioEvent) async throws {
        try await database.collection("events").document(event.id).setData(data(from: event), merge: true)
    }

    func updateEvent(_ event: PopioEvent) async throws {
        try await database.collection("events").document(event.id).setData(data(from: event), merge: false)
    }

    func deleteEvent(_ eventID: String) async throws {
        let contributions = try await database.collection("eventContributions")
            .whereField("eventID", isEqualTo: eventID)
            .getDocuments()
        let batch = database.batch()
        contributions.documents.forEach { batch.deleteDocument($0.reference) }
        batch.deleteDocument(database.collection("events").document(eventID))
        try await batch.commit()
    }

    func fetchContributions(includePending: Bool, currentUserID: String?) async throws -> [EventContribution] {
        let documents: [QueryDocumentSnapshot]
        if includePending {
            documents = try await database.collection("eventContributions").getDocuments().documents
        } else if let currentUserID {
            async let approvedSnapshot = database.collection("eventContributions")
                .whereField("moderationStatus", isEqualTo: EventModerationStatus.approved.rawValue)
                .getDocuments()
            async let ownedSnapshot = database.collection("eventContributions")
                .whereField("createdByUserID", isEqualTo: currentUserID)
                .getDocuments()
            async let chatSnapshot = database.collection("eventContributions")
                .whereField("type", isEqualTo: EventContributionType.review.rawValue)
                .getDocuments()
            let (approved, owned, chats) = try await (approvedSnapshot, ownedSnapshot, chatSnapshot)
            documents = uniqueDocuments(approved.documents + owned.documents + chats.documents)
        } else {
            documents = try await database.collection("eventContributions")
                .whereField("moderationStatus", isEqualTo: EventModerationStatus.approved.rawValue)
                .getDocuments().documents
        }

        return documents.compactMap { document in
            try? contribution(from: document)
        }
        .sorted { $0.createdDate > $1.createdDate }
    }

    func createContribution(_ contribution: EventContribution) async throws {
        try await database.collection("eventContributions").document(contribution.id).setData(data(from: contribution), merge: true)
    }

    func createReport(_ report: UserContentReport, emailSubject: String, emailBody: String) async throws {
        let batch = database.batch()
        batch.setData(
            data(from: report),
            forDocument: database.collection("contentReports").document(report.id),
            merge: false
        )
        queueAdminEmail(subject: emailSubject, body: emailBody, in: batch)
        try await batch.commit()
    }

    func createSupportSubmission(_ submission: SupportSubmission, emailSubject: String, emailBody: String) async throws {
        let batch = database.batch()
        batch.setData(
            data(from: submission),
            forDocument: database.collection("supportSubmissions").document(submission.id),
            merge: false
        )
        queueAdminEmail(subject: emailSubject, body: emailBody, in: batch)
        try await batch.commit()
    }

    private func queueAdminEmail(subject: String, body: String, in batch: WriteBatch) {
        let emailID = UUID().uuidString
        let data: [String: Any] = [
            "to": ["popioadmin@gmail.com"],
            "message": [
                "subject": subject,
                "text": body
            ],
            "source": "popio-ios",
            "createdDate": Timestamp(date: .now)
        ]
        batch.setData(data, forDocument: database.collection("mail").document(emailID), merge: false)
    }

    func fetchMailboxMessages(for userID: String) async throws -> [MailboxMessage] {
        let snapshot = try await database.collection("mailboxMessages")
            .whereField("recipientUserID", isEqualTo: userID)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? mailboxMessage(from: document)
        }
        .sorted { $0.createdDate > $1.createdDate }
    }

    func reviewEvent(_ event: PopioEvent, mailboxMessage: MailboxMessage) async throws {
        let batch = database.batch()
        batch.setData(
            data(from: event),
            forDocument: database.collection("events").document(event.id),
            merge: true
        )
        batch.setData(
            data(from: mailboxMessage),
            forDocument: database.collection("mailboxMessages").document(mailboxMessage.id),
            merge: false
        )
        try await batch.commit()
    }

    func markMailboxMessageRead(_ messageID: String) async throws {
        try await database.collection("mailboxMessages")
            .document(messageID)
            .updateData(["isRead": true])
    }

    private func uniqueDocuments(_ documents: [QueryDocumentSnapshot]) -> [QueryDocumentSnapshot] {
        Array(Dictionary(documents.map { ($0.documentID, $0) }, uniquingKeysWith: { first, _ in first }).values)
    }

    private func event(from document: QueryDocumentSnapshot) throws -> PopioEvent {
        let data = document.data()

        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let categoryValue = data["category"] as? String,
              let category = EventCategory(rawValue: categoryValue),
              let address = data["address"] as? String,
              let eventDate = (data["eventDate"] as? Timestamp)?.dateValue(),
              let createdByUserID = data["createdByUserID"] as? String,
              let creatorUsername = data["creatorUsername"] as? String,
              let bannerFocusY = data["bannerFocusY"] as? Double,
              let distanceInMiles = data["distanceInMiles"] as? Double,
              let isApproved = data["isApproved"] as? Bool,
              let moderationStatusValue = data["moderationStatus"] as? String,
              let moderationStatus = EventModerationStatus(rawValue: moderationStatusValue) else {
            throw FirebaseEventServiceError.invalidEvent
        }

        let imageURL = (data["imageURL"] as? String).flatMap(URL.init(string:))
        let menuImageURL = (data["menuImageURL"] as? String).flatMap(URL.init(string:))
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let startTime = (data["startTime"] as? Timestamp)?.dateValue()
        let endTime = (data["endTime"] as? Timestamp)?.dateValue()
        let moderationComment = data["moderationComment"] as? String
        let reviewedByUserID = data["reviewedByUserID"] as? String
        let likedUserIDs = Set(data["likedUserIDs"] as? [String] ?? [])
        let goingUserIDs = Set(data["goingUserIDs"] as? [String] ?? [])
        let tags = data["tags"] as? [String] ?? []
        let createdDate = (data["createdDate"] as? Timestamp)?.dateValue() ?? eventDate
        let likedAtByUserID = parseLikeDates(
            from: data["likedAtByUserID"],
            fallbackLikedUserIDs: likedUserIDs,
            fallbackDate: createdDate
        )

        return PopioEvent(
            id: document.documentID,
            title: title,
            description: description,
            category: category,
            address: address,
            latitude: latitude,
            longitude: longitude,
            eventDate: eventDate,
            startTime: startTime,
            endTime: endTime,
            createdByUserID: createdByUserID,
            creatorUsername: creatorUsername,
            imageURL: imageURL,
            imageData: nil,
            menuImageURL: menuImageURL,
            menuImageData: nil,
            bannerFocusY: bannerFocusY,
            tags: tags,
            distanceInMiles: distanceInMiles,
            isApproved: isApproved,
            moderationStatus: moderationStatus,
            moderationComment: moderationComment,
            reviewedByUserID: reviewedByUserID,
            likedUserIDs: likedUserIDs,
            likedAtByUserID: likedAtByUserID,
            goingUserIDs: goingUserIDs,
            createdDate: createdDate
        )
    }

    private func data(from event: PopioEvent) -> [String: Any] {
        var data: [String: Any] = [
            "id": event.id,
            "title": event.title,
            "description": event.description,
            "category": event.category.rawValue,
            "address": event.address,
            "eventDate": Timestamp(date: event.eventDate),
            "createdByUserID": event.createdByUserID,
            "creatorUsername": event.creatorUsername,
            "bannerFocusY": event.bannerFocusY,
            "tags": event.tags,
            "distanceInMiles": event.distanceInMiles,
            "isApproved": event.isApproved,
            "moderationStatus": event.moderationStatus.rawValue,
            "likedUserIDs": Array(event.likedUserIDs),
            "likedAtByUserID": event.likedAtByUserID.mapValues { Timestamp(date: $0) },
            "goingUserIDs": Array(event.goingUserIDs),
            "createdDate": Timestamp(date: event.createdDate)
        ]

        if let latitude = event.latitude {
            data["latitude"] = latitude
        }

        if let longitude = event.longitude {
            data["longitude"] = longitude
        }

        if let startTime = event.startTime {
            data["startTime"] = Timestamp(date: startTime)
        }

        if let endTime = event.endTime {
            data["endTime"] = Timestamp(date: endTime)
        }

        if let imageURL = event.imageURL {
            data["imageURL"] = imageURL.absoluteString
        }

        if let menuImageURL = event.menuImageURL {
            data["menuImageURL"] = menuImageURL.absoluteString
        }

        if let moderationComment = event.moderationComment {
            data["moderationComment"] = moderationComment
        }

        if let reviewedByUserID = event.reviewedByUserID {
            data["reviewedByUserID"] = reviewedByUserID
        }

        return data
    }

    private func contribution(from document: QueryDocumentSnapshot) throws -> EventContribution {
        let data = document.data()

        guard let eventID = data["eventID"] as? String,
              let typeValue = data["type"] as? String,
              let type = EventContributionType(rawValue: typeValue),
              let createdByUserID = data["createdByUserID"] as? String,
              let creatorUsername = data["creatorUsername"] as? String,
              let text = data["text"] as? String,
              let moderationStatusValue = data["moderationStatus"] as? String,
              let moderationStatus = EventModerationStatus(rawValue: moderationStatusValue),
              let createdDate = (data["createdDate"] as? Timestamp)?.dateValue() else {
            throw FirebaseEventServiceError.invalidEvent
        }

        let imageURL = (data["imageURL"] as? String).flatMap(URL.init(string:))
        let moderationComment = data["moderationComment"] as? String
        let reviewedByUserID = data["reviewedByUserID"] as? String
        let likedUserIDs = Set(data["likedUserIDs"] as? [String] ?? [])
        let likedAtByUserID = parseLikeDates(
            from: data["likedAtByUserID"],
            fallbackLikedUserIDs: likedUserIDs,
            fallbackDate: createdDate
        )

        return EventContribution(
            id: document.documentID,
            eventID: eventID,
            type: type,
            createdByUserID: createdByUserID,
            creatorUsername: creatorUsername,
            text: text,
            imageData: nil,
            imageURL: imageURL,
            moderationStatus: moderationStatus,
            moderationComment: moderationComment,
            reviewedByUserID: reviewedByUserID,
            likedUserIDs: likedUserIDs,
            likedAtByUserID: likedAtByUserID,
            createdDate: createdDate
        )
    }

    private func data(from contribution: EventContribution) -> [String: Any] {
        var data: [String: Any] = [
            "id": contribution.id,
            "eventID": contribution.eventID,
            "type": contribution.type.rawValue,
            "createdByUserID": contribution.createdByUserID,
            "creatorUsername": contribution.creatorUsername,
            "text": contribution.text,
            "moderationStatus": contribution.moderationStatus.rawValue,
            "likedUserIDs": Array(contribution.likedUserIDs),
            "likedAtByUserID": contribution.likedAtByUserID.mapValues { Timestamp(date: $0) },
            "createdDate": Timestamp(date: contribution.createdDate)
        ]

        if let imageURL = contribution.imageURL {
            data["imageURL"] = imageURL.absoluteString
        }

        if let moderationComment = contribution.moderationComment {
            data["moderationComment"] = moderationComment
        }

        if let reviewedByUserID = contribution.reviewedByUserID {
            data["reviewedByUserID"] = reviewedByUserID
        }

        return data
    }

    private func parseLikeDates(
        from value: Any?,
        fallbackLikedUserIDs: Set<String>,
        fallbackDate: Date
    ) -> [String: Date] {
        let fallbackDates = Dictionary(uniqueKeysWithValues: fallbackLikedUserIDs.map { ($0, fallbackDate) })

        if let timestamps = value as? [String: Timestamp] {
            return fallbackDates.merging(timestamps.mapValues { $0.dateValue() }) { _, storedDate in storedDate }
        }

        if let timestampValues = value as? [String: Any] {
            let storedDates = timestampValues.reduce(into: [String: Date]()) { result, entry in
                if let timestamp = entry.value as? Timestamp {
                    result[entry.key] = timestamp.dateValue()
                }
            }
            return fallbackDates.merging(storedDates) { _, storedDate in storedDate }
        }

        return fallbackDates
    }

    private func data(from report: UserContentReport) -> [String: Any] {
        [
            "id": report.id,
            "reporterUserID": report.reporterUserID,
            "reportedUserID": report.reportedUserID,
            "targetType": report.targetType.rawValue,
            "targetID": report.targetID,
            "reason": report.reason,
            "details": report.details,
            "status": report.status.rawValue,
            "createdDate": Timestamp(date: report.createdDate)
        ]
    }

    private func data(from submission: SupportSubmission) -> [String: Any] {
        [
            "id": submission.id,
            "userID": submission.userID,
            "username": submission.username,
            "userEmail": submission.userEmail,
            "type": submission.type.rawValue,
            "message": submission.message,
            "createdDate": Timestamp(date: submission.createdDate)
        ]
    }

    private func mailboxMessage(from document: QueryDocumentSnapshot) throws -> MailboxMessage {
        let data = document.data()

        guard let recipientUserID = data["recipientUserID"] as? String,
              let eventID = data["eventID"] as? String,
              let eventTitle = data["eventTitle"] as? String,
              let typeValue = data["type"] as? String,
              let type = MailboxMessageType(rawValue: typeValue),
              let message = data["message"] as? String,
              let isRead = data["isRead"] as? Bool,
              let createdDate = (data["createdDate"] as? Timestamp)?.dateValue() else {
            throw FirebaseEventServiceError.invalidMailboxMessage
        }

        return MailboxMessage(
            id: document.documentID,
            recipientUserID: recipientUserID,
            eventID: eventID,
            eventTitle: eventTitle,
            type: type,
            message: message,
            isRead: isRead,
            createdDate: createdDate
        )
    }

    private func data(from message: MailboxMessage) -> [String: Any] {
        [
            "id": message.id,
            "recipientUserID": message.recipientUserID,
            "eventID": message.eventID,
            "eventTitle": message.eventTitle,
            "type": message.type.rawValue,
            "message": message.message,
            "isRead": message.isRead,
            "createdDate": Timestamp(date: message.createdDate)
        ]
    }
}

enum FirebaseEventServiceError: LocalizedError {
    case invalidEvent
    case invalidMailboxMessage

    var errorDescription: String? {
        switch self {
        case .invalidEvent:
            return "A saved pop-up could not be loaded."
        case .invalidMailboxMessage:
            return "A mailbox message could not be loaded."
        }
    }
}
