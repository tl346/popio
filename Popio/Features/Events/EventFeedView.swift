import MapKit
import SwiftUI
import UIKit

struct EventFeedView: View {
    @EnvironmentObject private var session: AppSession
    @ObservedObject var viewModel: EventFeedViewModel
    @State private var isSearchExpanded = false
    @FocusState private var focusedSearchField: FeedSearchField?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    InlineFeedSearchView(
                        viewModel: viewModel,
                        isExpanded: $isSearchExpanded,
                        focusedField: $focusedSearchField
                    )

                    FeedFilterBar(
                        selectedCategories: $viewModel.selectedCategories,
                        isOpenNowOnly: $viewModel.isOpenNowOnly,
                        radiusOption: $viewModel.radiusOption
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .background(PopioTheme.background)
                .overlay(alignment: .bottom) {
                    HeaderBottomFade()
                }
                .zIndex(2)

                ScrollView {
                    let events = viewModel.filteredEvents(from: session.approvedEvents)
                    let columns = [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ]

                    VStack(alignment: .leading, spacing: 18) {
                        if events.isEmpty {
                            EmptyStateView(
                                systemImage: "magnifyingglass",
                                title: "No pop-ups found",
                                message: viewModel.hasActiveSearch ? "Try changing your search filters." : "Try adjusting your filters."
                            )
                            .padding(.top, 32)
                            .padding(.bottom, 128)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(events) { event in
                                    EventCardView(
                                        event: event,
                                        distance: viewModel.distanceInMiles(for: event),
                                        session: session
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 132)
                }
                .scrollIndicators(.hidden)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        collapseSearch()
                    }
                )
            }
            .background(PopioTheme.background)
            .navigationTitle("")
            .navigationDestination(for: EventFeedRoute.self) { route in
                switch route {
                case .detail(let event):
                    EventDetailView(event: event)
                case .chat(let event):
                    EventChatView(event: event)
                }
            }
        }
    }

    private func collapseSearch() {
        withAnimation(.snappy(duration: 0.2)) {
            isSearchExpanded = false
            focusedSearchField = nil
        }
    }

}

private enum EventFeedRoute: Hashable {
    case detail(PopioEvent)
    case chat(PopioEvent)
}

private enum FeedSearchField: Hashable {
    case name
    case location
}

private extension EventCategory {
    var filterTitle: String {
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

    var filterIcon: String {
        switch self {
        case .food:
            return "fork.knife"
        case .matcha:
            return "cup.and.saucer.fill"
        case .cards:
            return "rectangle.stack"
        case .farmersMarket:
            return "basket"
        }
    }
}

private enum FeedFilterSheet: Identifiable {
    case radius
    case category

    var id: String {
        switch self {
        case .radius:
            return "radius"
        case .category:
            return "category"
        }
    }
}

private struct FeedFilterBar: View {
    @Binding var selectedCategories: Set<EventCategory>
    @Binding var isOpenNowOnly: Bool
    @Binding var radiusOption: EventRadiusOption?
    var showsSort = true
    @State private var activeSheet: FeedFilterSheet?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    activeSheet = .radius
                } label: {
                    FilterPill(
                        systemImage: "location.circle",
                        text: radiusOption.map { "\(Int($0.rawValue)) mi" } ?? "Radius",
                        isActive: radiusOption != nil,
                        showsChevron: true,
                        tint: PopioTheme.accent
                    )
                }
                .buttonStyle(.plain)

                Button {
                    activeSheet = .category
                } label: {
                    FilterPill(
                        systemImage: "tag",
                        text: categoryFilterTitle,
                        isActive: !selectedCategories.isEmpty,
                        showsChevron: true,
                        tint: PopioTheme.gold
                    )
                }
                .buttonStyle(.plain)

                Button {
                    isOpenNowOnly.toggle()
                } label: {
                    FilterPill(
                        systemImage: isOpenNowOnly ? "checkmark.circle.fill" : "clock",
                        text: "Open Now",
                        isActive: isOpenNowOnly,
                        showsChevron: false,
                        tint: PopioTheme.coral
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .radius:
                MiniMenuSheet(title: "Radius") {
                    RadiusSliderMenu(radiusOption: $radiusOption) {
                        activeSheet = nil
                    }
                }
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.hidden)
            case .category:
                MiniMenuSheet(title: "Category") {
                    CategoryChipMenu(selectedCategories: $selectedCategories) {
                        activeSheet = nil
                    }
                }
                .presentationDetents([.height(310)])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    private var categoryFilterTitle: String {
        if selectedCategories.isEmpty {
            return "All Categories"
        }

        if selectedCategories.count == 1, let category = selectedCategories.first {
            return category.rawValue
        }

        return "\(selectedCategories.count) Categories"
    }
}

private struct CategoryChipMenu: View {
    @Binding var selectedCategories: Set<EventCategory>
    let done: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 112), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                selectedCategories.removeAll()
            } label: {
                Label("All Categories", systemImage: "square.grid.2x2")
                    .font(PopioFont.custom(size: 12, weight: .medium))
                    .foregroundStyle(selectedCategories.isEmpty ? PopioTheme.gold : PopioTheme.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(selectedCategories.isEmpty ? PopioTheme.gold.opacity(0.10) : PopioTheme.surface, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(selectedCategories.isEmpty ? PopioTheme.gold.opacity(0.68) : PopioTheme.line, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(EventCategory.allCases) { category in
                    Button {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    } label: {
                        Label(category.filterTitle, systemImage: category.filterIcon)
                            .font(PopioFont.custom(size: 12, weight: .medium))
                            .foregroundStyle(selectedCategories.contains(category) ? PopioTheme.gold : PopioTheme.ink)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(selectedCategories.contains(category) ? PopioTheme.gold.opacity(0.10) : PopioTheme.surface, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(selectedCategories.contains(category) ? PopioTheme.gold.opacity(0.68) : PopioTheme.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: done) {
                Text("Done")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .foregroundStyle(.white)
            .background(PopioTheme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PopioTheme.gold.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct RadiusSliderMenu: View {
    @Binding var radiusOption: EventRadiusOption?
    let done: () -> Void

    private let options = EventRadiusOption.allCases

    private var sliderValue: Binding<Double> {
        Binding(
            get: {
                Double(options.firstIndex(of: radiusOption ?? .ten) ?? 1)
            },
            set: { newValue in
                let index = Int(newValue.rounded())
                radiusOption = options[min(max(index, 0), options.count - 1)]
            }
        )
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Label(radiusOption.map { "\(Int($0.rawValue)) miles" } ?? "No radius", systemImage: "location.circle.fill")
                    .font(PopioFont.custom(size: 16, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)

                Spacer()
            }

            Button {
                radiusOption = nil
            } label: {
                HStack {
                    Text("No radius")
                    Spacer()
                    Image(systemName: radiusOption == nil ? "checkmark.circle.fill" : "circle")
                }
                .font(PopioFont.custom(size: 14, weight: .semibold))
                .foregroundStyle(radiusOption == nil ? PopioTheme.accent : PopioTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(radiusOption == nil ? PopioTheme.accent.opacity(0.12) : Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Slider(
                value: sliderValue,
                in: 0...Double(options.count - 1),
                step: 1
            )
            .tint(PopioTheme.accent)

            HStack {
                ForEach(options) { option in
                    Text("\(Int(option.rawValue))")
                        .font(PopioFont.custom(size: 11, weight: .semibold))
                        .foregroundStyle(radiusOption == option ? PopioTheme.accent : PopioTheme.muted)

                    if option != options.last {
                        Spacer()
                    }
                }
            }

            Button(action: done) {
                Text("Done")
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .foregroundStyle(.white)
            .background(PopioTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PopioTheme.accent.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct InlineFeedSearchView: View {
    @ObservedObject var viewModel: EventFeedViewModel
    @Binding var isExpanded: Bool
    var focusedField: FocusState<FeedSearchField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                searchIcon("magnifyingglass")

                TextField("Search pop-ups", text: $viewModel.eventNameQuery)
                    .focused(focusedField, equals: .name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .font(PopioFont.subheadline())
                    .foregroundStyle(PopioTheme.ink)
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.2)) {
                            isExpanded = true
                        }
                    }

                if viewModel.hasActiveSearch {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            viewModel.clearSearch()
                            isExpanded = false
                            focusedField.wrappedValue = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(PopioFont.custom(size: 16, weight: .medium))
                            .foregroundStyle(PopioTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(focusedField.wrappedValue == .name ? PopioTheme.gold.opacity(0.58) : PopioTheme.line, lineWidth: 1)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        searchIcon("mappin.and.ellipse")

                        TextField("Search by location", text: $viewModel.locationQuery)
                            .focused(focusedField, equals: .location)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .font(PopioFont.subheadline())
                            .foregroundStyle(PopioTheme.ink)
                            .onSubmit {
                                viewModel.resolveTypedLocation()
                                viewModel.locationSuggestions = []
                                focusedField.wrappedValue = .name
                            }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(focusedField.wrappedValue == .location ? PopioTheme.gold.opacity(0.58) : PopioTheme.line, lineWidth: 1)
                    }

                    if focusedField.wrappedValue == .location && !viewModel.locationSuggestions.isEmpty {
                        let suggestions = Array(viewModel.locationSuggestions.prefix(4))

                        VStack(spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                                Button {
                                    viewModel.selectSuggestion(suggestion)
                                    focusedField.wrappedValue = .name
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(PopioFont.custom(size: 13, weight: .medium))
                                            .foregroundStyle(PopioTheme.ink)

                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(PopioFont.caption())
                                                .foregroundStyle(PopioTheme.muted)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: focusedField.wrappedValue) { _, newValue in
            if newValue != nil {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded = true
                }
            } else {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded = false
                }
            }
        }
        .shadow(color: PopioTheme.shadow.opacity(0.14), radius: 10, y: 5)
    }

    private func searchIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(PopioFont.custom(size: 15, weight: .medium))
            .foregroundStyle(PopioTheme.gold)
            .frame(width: 20)
    }
}

struct EventMapView: View {
    let events: [PopioEvent]
    let centerCoordinate: CLLocationCoordinate2D?
    let userCoordinate: CLLocationCoordinate2D?
    let distanceProvider: (PopioEvent) -> Double
    let requestUserLocation: () -> Void
    @ObservedObject var viewModel: EventFeedViewModel
    @State private var cameraPosition: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion
    @State private var selectedEvent: PopioEvent?
    @State private var isNearbyCarouselVisible = true
    @State private var isSearchExpanded = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var shouldRecenterOnUserLocation = false
    @FocusState private var focusedSearchField: FeedSearchField?

    init(
        events: [PopioEvent],
        centerCoordinate: CLLocationCoordinate2D?,
        userCoordinate: CLLocationCoordinate2D?,
        distanceProvider: @escaping (PopioEvent) -> Double,
        requestUserLocation: @escaping () -> Void,
        viewModel: EventFeedViewModel
    ) {
        self.events = events
        self.centerCoordinate = centerCoordinate
        self.userCoordinate = userCoordinate
        self.distanceProvider = distanceProvider
        self.requestUserLocation = requestUserLocation
        self.viewModel = viewModel
        let mapCenter = centerCoordinate ?? events.first?.coordinate ?? CLLocationCoordinate2D(latitude: 40.7243, longitude: -73.9982)
        let initialRegion = MKCoordinateRegion(
            center: mapCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        _cameraPosition = State(
            initialValue: .region(
                initialRegion
            )
        )
        _visibleRegion = State(initialValue: initialRegion)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    if let userCoordinate {
                        Annotation("Your location", coordinate: userCoordinate) {
                            UserLocationMapPin()
                        }
                    }

                    ForEach(eventsWithCoordinates) { event in
                        if let coordinate = event.coordinate {
                            Annotation(event.title, coordinate: coordinate) {
                                Button {
                                    selectedEvent = event
                                } label: {
                                    MapEventBubble(event: event, isSelected: selectedEvent?.id == event.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onMapCameraChange { context in
                    visibleRegion = context.region
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        collapseSearch()
                    }
                )
                .ignoresSafeArea()
                .environment(\.colorScheme, .light)

                VStack(spacing: 0) {
                    MapTopChrome(
                        viewModel: viewModel,
                        isSearchExpanded: $isSearchExpanded,
                        focusedField: $focusedSearchField
                    )
                    .ignoresSafeArea(.keyboard, edges: .bottom)

                    Spacer()
                }

                VStack {
                    Spacer()

                    HStack(alignment: .bottom) {
                        Spacer()

                        Button {
                            recenterToUserLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(PopioFont.custom(size: 17, weight: .semibold))
                                .foregroundStyle(PopioTheme.ink)
                                .frame(width: 46, height: 46)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(PopioTheme.line, lineWidth: 1)
                                }
                                .shadow(color: PopioTheme.shadow.opacity(0.45), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Recenter map to my location")
                        .padding(.trailing, 16)
                        .padding(.bottom, recenterButtonBottomPadding)
                    }
                }

                VStack {
                    Spacer()

                    if isNearbyCarouselVisible {
                        MapEventCarousel(
                            events: visibleEvents,
                            selectedEventID: selectedEvent?.id,
                            selectEvent: selectEvent,
                            reservesBottomBarSpace: !isKeyboardVisible
                        )
                        .offset(y: -keyboardBottomPadding)
                        .gesture(
                            DragGesture(minimumDistance: 12)
                                .onEnded { value in
                                    let shouldHide = value.translation.height > 48
                                        || value.predictedEndTranslation.height > 90
                                    guard shouldHide else { return }

                                    withAnimation(.snappy(duration: 0.24)) {
                                        isNearbyCarouselVisible = false
                                    }
                                }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button {
                            withAnimation(.snappy(duration: 0.24)) {
                                isNearbyCarouselVisible = true
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "chevron.up")
                                    .font(PopioFont.custom(size: 12, weight: .bold))

                                Text("Show nearby pop-ups")
                                    .font(PopioFont.custom(size: 13, weight: .bold))

                                Text("\(visibleEvents.count)")
                                    .font(PopioFont.custom(size: 11, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 24, minHeight: 24)
                                    .background(PopioTheme.gold, in: Circle())
                            }
                            .foregroundStyle(PopioTheme.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(PopioTheme.gold.opacity(0.24), lineWidth: 1)
                            }
                            .shadow(color: PopioTheme.shadow.opacity(0.5), radius: 16, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 78)
                        .offset(y: -keyboardBottomPadding)
                        .accessibilityLabel("Show nearby pop-ups")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PopioEvent.self) { event in
                EventDetailView(event: event)
            }
            .onAppear {
                selectedEvent = eventsWithCoordinates.first
                requestUserLocation()
            }
            .onChange(of: eventsWithCoordinates) { _, newValue in
                guard selectedEvent == nil || !newValue.contains(where: { $0.id == selectedEvent?.id }) else { return }
                selectedEvent = newValue.first
            }
            .onChange(of: centerCoordinateKey) { _, _ in
                recenterMap()
            }
            .onChange(of: userCoordinateKey) { _, _ in
                guard shouldRecenterOnUserLocation else { return }
                shouldRecenterOnUserLocation = false
                recenterToUserLocation()
            }
            .onChange(of: focusedSearchField) { _, newValue in
                guard newValue != nil else { return }
                withAnimation(.snappy(duration: 0.24)) {
                    isNearbyCarouselVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                updateKeyboardHeight(from: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.snappy(duration: 0.22)) {
                    keyboardHeight = 0
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var eventsWithCoordinates: [PopioEvent] {
        events.filter { $0.coordinate != nil }
    }

    private var visibleEvents: [PopioEvent] {
        let inRegion = eventsWithCoordinates.filter { event in
            guard let coordinate = event.coordinate else { return false }
            return visibleRegion.contains(coordinate)
        }

        return inRegion.isEmpty ? eventsWithCoordinates : inRegion
    }

    private var centerCoordinateKey: String {
        guard let centerCoordinate else { return "none" }
        return "\(centerCoordinate.latitude),\(centerCoordinate.longitude)"
    }

    private var userCoordinateKey: String {
        guard let userCoordinate else { return "none" }
        return "\(userCoordinate.latitude),\(userCoordinate.longitude)"
    }

    private var isKeyboardVisible: Bool {
        keyboardHeight > 0
    }

    private var keyboardBottomPadding: CGFloat {
        isKeyboardVisible ? max(0, keyboardHeight - bottomSafeAreaInset) : 0
    }

    private var recenterButtonBottomPadding: CGFloat {
        78 + keyboardBottomPadding
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        let height = max(0, UIScreen.main.bounds.height - endFrame.minY)
        withAnimation(.snappy(duration: 0.22)) {
            keyboardHeight = height
        }
    }

    private var bottomSafeAreaInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap(\.windows).first { $0.isKeyWindow }
        return keyWindow?.safeAreaInsets.bottom ?? 0
    }

    private func collapseSearch() {
        withAnimation(.snappy(duration: 0.2)) {
            isSearchExpanded = false
            focusedSearchField = nil
        }
    }

    private func selectEvent(_ event: PopioEvent) {
        selectedEvent = event

        guard let coordinate = event.coordinate else { return }
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: max(visibleRegion.span.latitudeDelta, 0.015),
                longitudeDelta: max(visibleRegion.span.longitudeDelta, 0.015)
            )
        )

        visibleRegion = region

        withAnimation(.snappy) {
            cameraPosition = .region(region)
        }
    }

    private func recenterMap() {
        guard let centerCoordinate else {
            if let first = eventsWithCoordinates.first {
                selectEvent(first)
            }
            return
        }

        let region = MKCoordinateRegion(
            center: centerCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
        )

        visibleRegion = region

        withAnimation(.snappy) {
            cameraPosition = .region(region)
        }
    }

    private func recenterToUserLocation() {
        guard let userCoordinate else {
            shouldRecenterOnUserLocation = true
            requestUserLocation()
            return
        }

        shouldRecenterOnUserLocation = false
        let region = MKCoordinateRegion(
            center: userCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
        )

        visibleRegion = region

        withAnimation(.snappy) {
            cameraPosition = .region(region)
        }
    }

}

private extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latitudeDelta = span.latitudeDelta / 2
        let longitudeDelta = span.longitudeDelta / 2

        return coordinate.latitude >= center.latitude - latitudeDelta
            && coordinate.latitude <= center.latitude + latitudeDelta
            && coordinate.longitude >= center.longitude - longitudeDelta
            && coordinate.longitude <= center.longitude + longitudeDelta
    }
}

private struct MapTopChrome: View {
    @ObservedObject var viewModel: EventFeedViewModel
    @Binding var isSearchExpanded: Bool
    var focusedField: FocusState<FeedSearchField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InlineFeedSearchView(
                viewModel: viewModel,
                isExpanded: $isSearchExpanded,
                focusedField: focusedField
            )

            FeedFilterBar(
                selectedCategories: $viewModel.selectedCategories,
                isOpenNowOnly: $viewModel.isOpenNowOnly,
                radiusOption: $viewModel.radiusOption,
                showsSort: false
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            HeaderBottomFade()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map search and filters")
    }
}

private struct HeaderBottomFade: View {
    var body: some View {
        Rectangle()
            .fill(PopioTheme.line.opacity(0.12))
            .frame(height: 1)
        .allowsHitTesting(false)
    }
}

private struct MapEventBubble: View {
    let event: PopioEvent
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: markerIcon)
                .font(PopioFont.custom(size: isSelected ? 25 : 16, weight: .bold))
                .foregroundStyle(PopioTheme.gold)
                .frame(width: isSelected ? 66 : 40, height: isSelected ? 66 : 40)
                .background(Color.white, in: Circle())
                .overlay {
                    Circle()
                        .stroke(PopioTheme.gold, lineWidth: isSelected ? 5 : 3)
                }
                .shadow(color: PopioTheme.gold.opacity(isSelected ? 0.5 : 0.25), radius: isSelected ? 22 : 10, x: 0, y: 8)

            Image(systemName: "arrowtriangle.down.fill")
                .font(PopioFont.custom(size: isSelected ? 19 : 14, weight: .bold))
                .foregroundStyle(PopioTheme.gold)
                .offset(y: -4)
        }
    }

    private var markerIcon: String {
        switch event.category {
        case .food:
            return "fork.knife"
        case .matcha:
            return "cup.and.saucer.fill"
        case .cards:
            return "rectangle.stack.fill"
        case .farmersMarket:
            return "basket.fill"
        }
    }
}

private struct UserLocationMapPin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(PopioTheme.accent.opacity(0.20))
                .frame(width: 32, height: 32)

            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)

            Circle()
                .fill(PopioTheme.accent)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                }
        }
        .shadow(color: PopioTheme.shadow.opacity(0.28), radius: 8, y: 4)
        .accessibilityLabel("Your current location")
    }
}

private struct MapEventCarousel: View {
    let events: [PopioEvent]
    let selectedEventID: String?
    let selectEvent: (PopioEvent) -> Void
    let reservesBottomBarSpace: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)

            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(PopioFont.custom(size: 20, weight: .bold))
                        .foregroundStyle(PopioTheme.gold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pop-ups near you")
                            .font(PopioFont.custom(size: 14, weight: .bold))
                            .foregroundStyle(PopioTheme.ink)
                    }
                }

                Spacer()
            }
            .padding(.leading, 14)
            .padding(.trailing, 14)

            if events.isEmpty {
                Text("Move the map or adjust filters to find nearby pop-ups.")
                    .font(PopioFont.custom(size: 11, weight: .medium))
                    .foregroundStyle(PopioTheme.muted)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(events) { event in
                            NavigationLink(value: event) {
                                MapCarouselCard(
                                    event: event,
                                    isSelected: selectedEventID == event.id
                                )
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    selectEvent(event)
                                }
                            )
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
            }

            Color.clear
                .frame(height: reservesBottomBarSpace ? 70 : 0)
        }
        .padding(.top, 6)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                .fill(PopioTheme.backgroundElevated)
        }
        .accessibilityHint("Drag down to hide nearby pop-ups")
    }
}

private struct MapCarouselCard: View {
    let event: PopioEvent
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EventBannerImageView(event: event)
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(PopioFont.custom(size: 14.5, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    EventCardMetaRow(systemImage: "calendar", text: eventTimeText)
                    EventCardMetaRow(systemImage: "mappin", text: locationText)
                }

                EventCardTagRow(tags: cardTags)

                Spacer(minLength: 0)
            }
            .padding(10)
        }
        .frame(width: 160, height: 190)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? PopioTheme.gold : PopioTheme.line.opacity(0.85), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: PopioTheme.shadow.opacity(0.12), radius: 14, y: 7)
    }

    private var eventTimeText: String {
        let date = event.eventDate.formatted(.dateTime.month(.abbreviated).day())

        switch (event.startTime, event.endTime) {
        case let (start?, end?):
            return "\(date) · \(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
        case let (start?, nil):
            return "\(date) · \(start.formatted(date: .omitted, time: .shortened))"
        case let (nil, end?):
            return "\(date) · Ends \(end.formatted(date: .omitted, time: .shortened))"
        case (nil, nil):
            return date
        }
    }

    private var locationText: String {
        "\(String(format: "%.1f", event.distanceInMiles)) mi · \(shortLocation)"
    }

    private var shortLocation: String {
        let parts = event.address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return parts.dropFirst().first ?? parts.first ?? event.address
    }

    private var cardTags: [String] {
        let baseTags = [event.category.rawValue] + event.tags
        let tags = event.hasMenuImage ? baseTags + ["Menu"] : baseTags
        return tags.reduce(into: [String]()) { uniqueTags, tag in
            guard !uniqueTags.contains(tag) else { return }
            uniqueTags.append(tag)
        }
        .prefix(2)
        .map(\.self)
    }
}

private struct FilterPill: View {
    let systemImage: String
    let text: String
    let isActive: Bool
    let showsChevron: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 11, weight: .bold))
            Text(text)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(PopioFont.caption2(.bold))
            }
        }
        .font(PopioFont.caption(.bold))
        .foregroundStyle(PopioTheme.ink)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(activeBackground, in: Capsule())
        .overlay {
            Capsule()
                .stroke(isActive ? tint.opacity(0.38) : PopioTheme.line, lineWidth: 1)
        }
    }

    private var activeBackground: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [tint.opacity(0.24), tint.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(PopioTheme.backgroundElevated)
    }
}

struct EventCardView: View {
    let event: PopioEvent
    let distance: Double
    @ObservedObject var session: AppSession

    var body: some View {
        NavigationLink(value: EventFeedRoute.detail(event)) {
            VStack(alignment: .leading, spacing: 0) {
                EventBannerImageView(event: event)
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(PopioFont.custom(size: 14.5, weight: .semibold))
                        .foregroundStyle(PopioTheme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 4) {
                        EventCardMetaRow(systemImage: "calendar", text: eventDateText)
                        EventCardMetaRow(systemImage: "mappin", text: locationText)
                    }

                    EventCardTagRow(tags: cardTags)

                    Spacer(minLength: 0)
                }
                .padding(10)
            }
            .frame(height: 190)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PopioTheme.line.opacity(0.85), lineWidth: 1)
            }
            .shadow(color: PopioTheme.shadow.opacity(0.12), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var eventDateText: String {
        let date = event.eventDate.formatted(.dateTime.month(.abbreviated).day())

        switch (event.startTime, event.endTime) {
        case let (start?, end?):
            return "\(date) · \(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
        case let (start?, nil):
            return "\(date) · \(start.formatted(date: .omitted, time: .shortened))"
        case let (nil, end?):
            return "\(date) · Ends \(end.formatted(date: .omitted, time: .shortened))"
        case (nil, nil):
            return date
        }
    }

    private var locationText: String {
        "\(String(format: "%.1f", distance)) mi · \(shortLocation)"
    }

    private var shortLocation: String {
        let parts = event.address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return parts.dropFirst().first ?? parts.first ?? event.address
    }

    private var cardTags: [String] {
        let baseTags = [event.category.rawValue] + event.tags
        let tags = event.hasMenuImage ? baseTags + ["Menu"] : baseTags
        return tags.reduce(into: [String]()) { uniqueTags, tag in
            guard !uniqueTags.contains(tag) else { return }
            uniqueTags.append(tag)
        }
        .prefix(2)
        .map(\.self)
    }
}

private struct EventCardMetaRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 9.5, weight: .semibold))
                .foregroundStyle(PopioTheme.gold)
                .frame(width: 11)

            Text(text)
                .font(PopioFont.custom(size: 10, weight: .medium))
                .foregroundStyle(PopioTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct EventCardActionIcon: View {
    let systemImage: String
    let isActive: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(PopioFont.custom(size: 14, weight: .semibold))
            .foregroundStyle(isActive ? PopioTheme.gold : PopioTheme.ink.opacity(0.72))
            .frame(width: 31, height: 31)
            .background(
                (isActive ? PopioTheme.gold.opacity(0.14) : PopioTheme.backgroundElevated.opacity(0.86)),
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(isActive ? PopioTheme.gold.opacity(0.30) : PopioTheme.line, lineWidth: 1)
            }
    }
}

private struct EventCardTagRow: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(PopioFont.custom(size: 9.5, weight: .medium))
                    .foregroundStyle(PopioTheme.ink.opacity(0.78))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(PopioTheme.coralSoft.opacity(0.68), in: Capsule())
            }

            Spacer(minLength: 0)
        }
    }
}

private struct SearchSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(PopioFont.subheadline(.bold))
                .foregroundStyle(PopioTheme.ink)

            content
        }
    }
}
