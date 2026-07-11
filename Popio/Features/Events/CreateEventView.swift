import Contacts
import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSession

    @State private var title = ""
    @State private var category: EventCategory = .food
    @State private var address = ""
    @State private var eventDate = Date()
    @State private var startTime: Date?
    @State private var endTime: Date?
    @State private var isDatePickerExpanded = false
    @State private var isStartTimePickerExpanded = false
    @State private var isEndTimePickerExpanded = false
    @State private var selectedTags: Set<CreateEventTag> = []
    @State private var customTags: [String] = []
    @State private var customTagText = ""
    @State private var isAddingCustomTag = false
    @State private var selectedEventPhoto: PhotosPickerItem?
    @State private var eventImageData: Data?
    @State private var bannerFocusY = 0.5
    @State private var isPublishing = false
    @State private var errorMessage: String?
    @State private var isShowingSubmissionConfirmation = false
    @State private var isShowingDuplicateEventAlert = false
    @State private var duplicateCandidate: AppSession.DuplicateEventCandidate?
    @State private var pendingResolvedAddress: ResolvedEventAddress?
    @StateObject private var addressSearch = EventAddressSearch()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    createHeader
                    eventNameAndPhotoSection
                    locationSection
                    dateTimeSection
                    categorySection
                    tagsSection
                    hostedBySection
                    errorSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 96)
            }
            .background(PopioTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                createEventButton
            }
            .onChange(of: selectedEventPhoto) { _, newValue in
                guard let newValue else { return }

                Task {
                    eventImageData = try? await jpegData(from: newValue)
                    selectedEventPhoto = nil
                }
            }
            .alert("Pop-up submitted", isPresented: $isShowingSubmissionConfirmation) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your pop-up is live and will appear in the feed and on the map.")
            }
            .alert("Is this the same event?", isPresented: $isShowingDuplicateEventAlert) {
                Button("Yes, cancel") {
                    duplicateCandidate = nil
                    pendingResolvedAddress = nil
                }

                Button("No, post anyway") {
                    Task {
                        await publishSkippingDuplicateCheck()
                    }
                }
            } message: {
                if let duplicateCandidate {
                    Text(duplicateMessage(for: duplicateCandidate))
                } else {
                    Text("A similar pop-up already exists near this location.")
                }
            }
        }
    }

    private var createHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Text("Create Event")
                    .font(PopioFont.custom(size: 21, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)

                HStack {
                    closeButton
                    Spacer()
                }
            }

            Text("Share something amazing with your community.")
                .font(PopioFont.custom(size: 13, weight: .regular))
                .foregroundStyle(PopioTheme.muted)
                .frame(maxWidth: .infinity)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(PopioFont.custom(size: 14, weight: .medium))
                .foregroundStyle(PopioTheme.ink)
                .frame(width: 40, height: 40)
                .background(Color.white, in: Circle())
                .overlay {
                    Circle()
                        .stroke(PopioTheme.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private var eventNameAndPhotoSection: some View {
        HStack(alignment: .top, spacing: 12) {
            PhotosPicker(selection: $selectedEventPhoto, matching: .images) {
                ZStack {
                    Group {
                        if let eventImageData {
                            BannerImageView(
                                imageData: eventImageData,
                                imageURL: nil,
                                category: category,
                                focusY: bannerFocusY
                            )
                        } else {
                            RemoteImagePlaceholder(category: category)
                        }
                    }
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Image(systemName: "camera.fill")
                        .font(PopioFont.custom(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.35), in: Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(eventImageData == nil ? "Add event image" : "Change event image")

            VStack(alignment: .leading, spacing: 7) {
                CreateFormLabel("Event Name", isRequired: true)

                TextField("e.g., Sunset Coffee Pop-Up", text: $title)
                    .textInputAutocapitalization(.words)
                    .font(PopioFont.custom(size: 14, weight: .regular))
                    .foregroundStyle(PopioTheme.ink)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PopioTheme.line, lineWidth: 1)
                    }

                Text("\(title.count)/80")
                    .font(PopioFont.caption(.medium))
                    .foregroundStyle(PopioTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .onChange(of: title) { _, newValue in
            if newValue.count > 80 {
                title = String(newValue.prefix(80))
            }
        }
    }

    private var locationSection: some View {
        CreateEventDividerSection(title: "Location", isRequired: true) {
            HStack(spacing: 9) {
                Image(systemName: "mappin.circle")
                    .font(PopioFont.custom(size: 16, weight: .medium))
                    .foregroundStyle(PopioTheme.ink)

                TextField("Enter a location", text: $address)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(PopioTheme.ink)
                    .onChange(of: address) { _, newValue in
                        addressSearch.updateQuery(newValue)
                    }

                Image(systemName: "location.north.line")
                    .font(PopioFont.custom(size: 15, weight: .medium))
                    .foregroundStyle(PopioTheme.ink)
            }
            .font(PopioFont.subheadline())
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }

            Text("This will help people find your event")
                .font(PopioFont.caption(.medium))
                .foregroundStyle(PopioTheme.muted)

            addressSuggestions
        }
    }

    @ViewBuilder
    private var addressSuggestions: some View {
        if !addressSearch.suggestions.isEmpty {
            let suggestions = Array(addressSearch.suggestions.prefix(5))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        addressSearch.select(suggestion)
                        address = suggestion.title
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(PopioFont.subheadline(.medium))
                                .foregroundStyle(PopioTheme.ink)

                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(PopioFont.caption())
                                    .foregroundStyle(PopioTheme.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    if index < suggestions.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
        }
    }

    private var dateTimeSection: some View {
        CreateEventDividerSection(title: "Date & Time", isRequired: true) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isDatePickerExpanded.toggle()
                }
            } label: {
                CreateCompactFieldLabel(
                    systemImage: "calendar",
                    title: eventDate.formatted(.dateTime.month(.abbreviated).day().year()),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            if isDatePickerExpanded {
                DatePicker("", selection: $eventDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(PopioTheme.gold)
                    .scaleEffect(0.82, anchor: .top)
                    .frame(height: 270, alignment: .top)
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                    .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PopioTheme.line, lineWidth: 1)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                CreateOptionalTimeField(
                    title: "Start time",
                    date: $startTime,
                    isExpanded: $isStartTimePickerExpanded
                )

                CreateOptionalTimeField(
                    title: "End time",
                    date: $endTime,
                    isExpanded: $isEndTimePickerExpanded
                )
            }
        }
    }

    private var categorySection: some View {
        CreateEventDividerSection(title: "Category", isRequired: true) {
            FlexibleCreateEventTags(items: EventCategory.allCases) { categoryOption in
                Button {
                    category = categoryOption
                } label: {
                    Label(categoryOption.createTitle, systemImage: categoryOption.createIcon)
                        .font(PopioFont.custom(size: 12, weight: .medium))
                        .foregroundStyle(category == categoryOption ? PopioTheme.gold : PopioTheme.ink)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(category == categoryOption ? PopioTheme.gold.opacity(0.10) : Color.white, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(category == categoryOption ? PopioTheme.gold : PopioTheme.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tagsSection: some View {
        CreateEventDividerSection(title: "Tags", caption: "Optional") {
            CreateEventFlowLayout(spacing: 6, rowSpacing: 6) {
                ForEach(CreateEventTag.allCases) { tag in
                    Button {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    } label: {
                        Label(tag.title, systemImage: tag.systemImage)
                            .font(PopioFont.custom(size: 12, weight: .medium))
                            .foregroundStyle(selectedTags.contains(tag) ? PopioTheme.gold : PopioTheme.ink)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(selectedTags.contains(tag) ? PopioTheme.gold.opacity(0.10) : PopioTheme.surface, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(selectedTags.contains(tag) ? PopioTheme.gold.opacity(0.68) : PopioTheme.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                ForEach(customTags.map(CustomCreateEventTag.init(title:))) { tag in
                    Button {
                        customTags.removeAll { $0 == tag.title }
                    } label: {
                        Label(tag.title, systemImage: "xmark")
                            .font(PopioFont.custom(size: 12, weight: .medium))
                            .foregroundStyle(PopioTheme.gold)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(PopioTheme.gold.opacity(0.10), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(PopioTheme.gold.opacity(0.62), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                if !isAddingCustomTag {
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            isAddingCustomTag = true
                        }
                    } label: {
                        Label("Other", systemImage: "plus")
                            .font(PopioFont.custom(size: 12, weight: .medium))
                            .foregroundStyle(PopioTheme.ink)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(PopioTheme.surface, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(PopioTheme.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if isAddingCustomTag {
                HStack(spacing: 8) {
                    TextField("Type a tag", text: $customTagText)
                        .font(PopioFont.custom(size: 13, weight: .regular))
                        .foregroundStyle(PopioTheme.ink)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(addCustomTag)
                        .onChange(of: customTagText) { _, newValue in
                            if newValue.count > 8 {
                                customTagText = String(newValue.prefix(8))
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(PopioTheme.surface, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(PopioTheme.line, lineWidth: 1)
                        }

                    Button("Add") {
                        addCustomTag()
                    }
                    .font(PopioFont.custom(size: 13, weight: .semibold))
                    .foregroundStyle(PopioTheme.gold)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hostedBySection: some View {
        CreateEventDividerSection(title: "Found By", caption: "Current profile") {
            HStack(spacing: 12) {
                ProfileAvatarView(user: session.currentUser, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(hostName)
                        .font(PopioFont.custom(size: 14, weight: .semibold))
                        .foregroundStyle(PopioTheme.ink)

                    Text(hostHandle)
                        .font(PopioFont.custom(size: 12, weight: .regular))
                        .foregroundStyle(PopioTheme.muted)
                }

                Spacer()
            }
            .padding(12)
            .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                .font(PopioFont.footnote(.semibold))
                .foregroundStyle(PopioTheme.gold)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PopioTheme.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var createEventButton: some View {
        Button {
            Task {
                await publish()
            }
        } label: {
            HStack {
                if isPublishing {
                    ProgressView()
                        .tint(.white)
                }

                Text(isPublishing ? "Creating..." : "Create Event")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [
                        PopioTheme.gold,
                        PopioTheme.gold
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isPublishing || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(isPublishing || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var hostName: String {
        guard let user = session.currentUser else { return "Popio Host" }
        let fullName = [user.firstName, user.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let displayName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? (displayName.isEmpty ? user.username : displayName) : fullName
    }

    private var hostHandle: String {
        guard let username = session.currentUser?.username.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty else {
            return "@popio"
        }
        return "@\(username)"
    }

    private func publish() async {
        errorMessage = nil
        isPublishing = true

        do {
            let resolvedAddress = try await addressSearch.resolveAddress(for: address)
            pendingResolvedAddress = resolvedAddress

            if let candidate = session.duplicateEventCandidate(
                title: title,
                latitude: resolvedAddress.coordinate.latitude,
                longitude: resolvedAddress.coordinate.longitude
            ) {
                duplicateCandidate = candidate
                isShowingDuplicateEventAlert = true
                isPublishing = false
                return
            }

            try await submitEvent(with: resolvedAddress)
            isShowingSubmissionConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isPublishing = false
    }

    private func publishSkippingDuplicateCheck() async {
        guard let resolvedAddress = pendingResolvedAddress else { return }
        errorMessage = nil
        isPublishing = true

        do {
            try await submitEvent(with: resolvedAddress)
            duplicateCandidate = nil
            pendingResolvedAddress = nil
            isShowingSubmissionConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isPublishing = false
    }

    private func submitEvent(with resolvedAddress: ResolvedEventAddress) async throws {
        try await session.createEvent(
            title: title,
            description: "",
            category: category,
            address: resolvedAddress.displayAddress,
            eventDate: eventDate,
            startTime: startTime,
            endTime: endTime,
            imageData: eventImageData,
            menuImageData: nil,
            bannerFocusY: bannerFocusY,
            tags: allSelectedTagTitles,
            latitude: resolvedAddress.coordinate.latitude,
            longitude: resolvedAddress.coordinate.longitude
        )
    }

    private func duplicateMessage(for candidate: AppSession.DuplicateEventCandidate) -> String {
        let nameScore = Int((candidate.nameSimilarity * 100).rounded())
        let locationScore = Int((candidate.locationSimilarity * 100).rounded())
        return "\"\(candidate.event.title)\" already exists nearby.\nName similarity: \(nameScore)%\nLocation similarity: \(locationScore)%"
    }

    private func jpegData(from item: PhotosPickerItem) async throws -> Data? {
        guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
        guard let image = UIImage(data: data) else { return data }
        return image.jpegData(compressionQuality: 0.85)
    }

    private var allSelectedTagTitles: [String] {
        Array(Set(selectedTags.map(\.title) + customTags)).sorted()
    }

    private func addCustomTag() {
        let trimmedTag = String(customTagText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(8))
        guard !trimmedTag.isEmpty else { return }
        guard !customTags.contains(where: { $0.caseInsensitiveCompare(trimmedTag) == .orderedSame }) else {
            customTagText = ""
            isAddingCustomTag = false
            return
        }

        customTags.append(trimmedTag)
        customTagText = ""
        isAddingCustomTag = false
    }
}

private struct CreateEventDividerSection<Content: View>: View {
    let title: String
    var isRequired = false
    var caption: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack(spacing: 4) {
                CreateFormLabel(title, isRequired: isRequired)

                if let caption {
                    Text("(\(caption))")
                        .font(PopioFont.custom(size: 12, weight: .regular))
                        .foregroundStyle(PopioTheme.muted)
                }
            }

            content
        }
    }
}

private struct CreateFormLabel: View {
    let title: String
    let isRequired: Bool

    init(_ title: String, isRequired: Bool = false) {
        self.title = title
        self.isRequired = isRequired
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(PopioFont.custom(size: 14, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)

            if isRequired {
                Text("*")
                    .font(PopioFont.custom(size: 14, weight: .semibold))
                    .foregroundStyle(PopioTheme.gold)
            }
        }
    }
}

private struct CreateCompactFieldLabel: View {
    let systemImage: String
    let title: String
    var showsChevron = false
    var showsBorder = true

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 15, weight: .medium))
                .foregroundStyle(PopioTheme.ink)

            Text(title)
                .font(PopioFont.custom(size: 14, weight: .regular))
                .foregroundStyle(PopioTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(PopioFont.custom(size: 11, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
        }
    }
}

private struct CreateOptionalTimeField: View {
    let title: String
    @Binding var date: Date?
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded, let binding = optionalDateBinding {
                HStack(spacing: 6) {
                    DatePicker(title, selection: binding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(PopioTheme.gold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            date = nil
                            isExpanded = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(PopioFont.custom(size: 17, weight: .medium))
                            .foregroundStyle(PopioTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(title)")
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PopioTheme.line, lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    fieldTitle
                }
            } else {
                Button {
                    if date == nil {
                        date = Date()
                    }
                    withAnimation(.snappy(duration: 0.18)) {
                        isExpanded = true
                    }
                } label: {
                    CreateCompactFieldLabel(
                        systemImage: "clock",
                        title: dateText,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topLeading) {
                    fieldTitle
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateText: String {
        guard let date else { return "Optional" }
        return date.formatted(.dateTime.hour().minute())
    }

    private var optionalDateBinding: Binding<Date>? {
        Binding<Date>(
            get: {
                date ?? Date()
            },
            set: { newValue in
                date = newValue
            }
        )
    }

    private var fieldTitle: some View {
        Text(title)
            .font(PopioFont.custom(size: 10, weight: .medium))
            .foregroundStyle(PopioTheme.muted)
            .padding(.horizontal, 5)
            .background(PopioTheme.background)
            .offset(x: 12, y: -7)
    }
}

private struct FlexibleCreateEventTags<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        CreateEventFlowLayout(spacing: 6, rowSpacing: 6) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

private struct CreateEventFlowLayout: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(in: maxWidth, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + CGFloat(max(0, rows.count - 1)) * rowSpacing

        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }

            y += row.height + rowSpacing
        }
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentIndices: [Subviews.Index] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = currentIndices.isEmpty ? size.width : currentWidth + spacing + size.width

            if proposedWidth > maxWidth, !currentIndices.isEmpty {
                rows.append(FlowRow(indices: currentIndices, width: currentWidth, height: currentHeight))
                currentIndices = [index]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentIndices.append(index)
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentIndices.isEmpty {
            rows.append(FlowRow(indices: currentIndices, width: currentWidth, height: currentHeight))
        }

        return rows
    }

    private struct FlowRow {
        let indices: [Subviews.Index]
        let width: CGFloat
        let height: CGFloat
    }
}

private struct CustomCreateEventTag: Identifiable {
    let title: String
    var id: String { title.lowercased() }
}

private enum CreateEventTag: String, CaseIterable, Identifiable {
    case outdoor
    case rooftop
    case petFriendly
    case cashless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outdoor:
            return "Outdoor"
        case .rooftop:
            return "Rooftop"
        case .petFriendly:
            return "Pet Friendly"
        case .cashless:
            return "Cashless"
        }
    }

    var systemImage: String {
        switch self {
        case .outdoor:
            return "sun.max"
        case .rooftop:
            return "building.2"
        case .petFriendly:
            return "pawprint"
        case .cashless:
            return "creditcard"
        }
    }
}

private extension EventCategory {
    var createTitle: String {
        switch self {
        case .food:
            return "F&B"
        case .matcha:
            return "Matcha"
        case .cards:
            return "Cards"
        case .farmersMarket:
            return "Market"
        }
    }

    var createIcon: String {
        switch self {
        case .food:
            return "fork.knife"
        case .matcha:
            return "cup.and.saucer"
        case .cards:
            return "rectangle.stack"
        case .farmersMarket:
            return "basket"
        }
    }
}

private struct CreateEventSection<Content: View>: View {
    let title: String
    let systemImage: String
    var caption: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(PopioFont.headline(.bold))
                    .foregroundStyle(PopioTheme.ink)

                if let caption {
                    Text(caption)
                        .font(PopioFont.caption(.bold))
                        .foregroundStyle(PopioTheme.muted)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(PopioTheme.backgroundElevated, in: Capsule())
                }
            }

            content
        }
        .popioCard(cornerRadius: 24, padding: 16)
    }
}

private struct ResolvedEventAddress {
    let displayAddress: String
    let coordinate: CLLocationCoordinate2D
}

@MainActor
private final class EventAddressSearch: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private var selectedSuggestion: MKLocalSearchCompletion?
    private var isSelecting = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) {
        guard !isSelecting else { return }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if selectedSuggestion?.title == trimmedQuery {
            suggestions = []
            completer.queryFragment = ""
            return
        }

        selectedSuggestion = nil
        completer.queryFragment = trimmedQuery
    }

    func select(_ suggestion: MKLocalSearchCompletion) {
        isSelecting = true
        selectedSuggestion = suggestion
        suggestions = []
        completer.queryFragment = ""
        isSelecting = false
    }

    func resolveAddress(for address: String) async throws -> ResolvedEventAddress {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            throw CreateEventError.invalidAddress
        }

        let response: MKLocalSearch.Response
        do {
            if let selectedSuggestion {
                response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: selectedSuggestion)).start()
            } else {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = trimmedAddress
                request.resultTypes = [.address, .pointOfInterest]
                response = try await MKLocalSearch(request: request).start()
            }
        } catch {
            throw CreateEventError.invalidAddress
        }

        guard let mapItem = response.mapItems.first,
              let location = mapItem.placemark.location else {
            throw CreateEventError.invalidAddress
        }

        return ResolvedEventAddress(
            displayAddress: displayAddress(for: mapItem, fallback: trimmedAddress),
            coordinate: location.coordinate
        )
    }

    private func displayAddress(for mapItem: MKMapItem, fallback: String) -> String {
        if let postalAddress = mapItem.placemark.postalAddress {
            let formatter = CNPostalAddressFormatter()
            return formatter.string(from: postalAddress)
                .replacingOccurrences(of: "\n", with: ", ")
        }

        if let title = mapItem.placemark.title, !title.isEmpty {
            return title
        }

        if let name = mapItem.name, !name.isEmpty {
            return name
        }

        return fallback
    }
}

extension EventAddressSearch: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results

        Task { @MainActor in
            self.suggestions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}

private enum CreateEventError: LocalizedError {
    case invalidAddress

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Enter a valid address or place so Popio can place this pop-up on the map."
        }
    }
}

private struct BannerCropSelector: View {
    let imageData: Data?
    @Binding var focusY: Double

    private let bannerAspectRatio = 2.4

    var body: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            GeometryReader { proxy in
                let imageRect = fittedImageRect(imageSize: uiImage.size, containerSize: proxy.size)
                let cropHeight = min(imageRect.height, imageRect.width / bannerAspectRatio)
                let cropY = imageRect.minY + max(0, imageRect.height - cropHeight) * focusY
                let cropRect = CGRect(
                    x: imageRect.minX,
                    y: cropY,
                    width: imageRect.width,
                    height: cropHeight
                )

                ZStack(alignment: .topLeading) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)

                    dimmingOverlay(imageRect: imageRect, cropRect: cropRect)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white, lineWidth: 3)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                        .frame(width: cropRect.width, height: cropRect.height)
                        .offset(x: cropRect.minX, y: cropRect.minY)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateFocusY(
                                        dragY: value.location.y,
                                        imageRect: imageRect,
                                        cropHeight: cropHeight
                                    )
                                }
                        )

                    Image(systemName: "arrow.up.and.down")
                        .font(PopioFont.custom(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.45), in: Circle())
                        .offset(
                            x: cropRect.midX - 17,
                            y: cropRect.midY - 17
                        )
                        .allowsHitTesting(false)
                }
            }
            .background(PopioTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func fittedImageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            let width = containerSize.width
            let height = width / imageAspect
            return CGRect(
                x: 0,
                y: (containerSize.height - height) / 2,
                width: width,
                height: height
            )
        } else {
            let height = containerSize.height
            let width = height * imageAspect
            return CGRect(
                x: (containerSize.width - width) / 2,
                y: 0,
                width: width,
                height: height
            )
        }
    }

    private func dimmingOverlay(imageRect: CGRect, cropRect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Color.black.opacity(0.45)
                .frame(width: imageRect.width, height: max(0, cropRect.minY - imageRect.minY))
                .offset(x: imageRect.minX, y: imageRect.minY)

            Color.black.opacity(0.45)
                .frame(width: imageRect.width, height: max(0, imageRect.maxY - cropRect.maxY))
                .offset(x: imageRect.minX, y: cropRect.maxY)
        }
        .allowsHitTesting(false)
    }

    private func updateFocusY(dragY: CGFloat, imageRect: CGRect, cropHeight: CGFloat) {
        let availableHeight = max(1, imageRect.height - cropHeight)
        let proposedY = dragY - cropHeight / 2
        let clampedY = min(max(proposedY, imageRect.minY), imageRect.maxY - cropHeight)
        focusY = Double((clampedY - imageRect.minY) / availableHeight)
    }
}
