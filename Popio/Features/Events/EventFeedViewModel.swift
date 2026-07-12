import Combine
import Foundation
import MapKit

enum EventSortOption: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case distance = "Distance"

    var id: String { rawValue }
}

enum EventRadiusOption: Double, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case twentyFive = 25
    case fifty = 50

    var id: Double { rawValue }

    var title: String {
        "\(Int(rawValue)) miles"
    }
}

final class EventFeedViewModel: NSObject, ObservableObject {
    @Published var locationQuery = "United States" {
        didSet {
            guard !isSelectingSuggestion else { return }
            selectedCoordinate = nil
            completer.queryFragment = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    @Published var locationSuggestions: [MKLocalSearchCompletion] = []
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    @Published var userCoordinate: CLLocationCoordinate2D?
    @Published var sortOption: EventSortOption = .distance
    @Published var radiusOption: EventRadiusOption?
    @Published var selectedCategories: Set<EventCategory> = []
    @Published var isOpenNowOnly = false
    @Published var eventNameQuery = ""

    private let completer = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()
    private var isSelectingSuggestion = false

    var effectiveCoordinate: CLLocationCoordinate2D? {
        selectedCoordinate ?? userCoordinate ?? Self.unitedStatesFallbackCoordinate
    }

    var hasActiveSearch: Bool {
        !eventNameQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var searchSummary: String {
        let name = eventNameQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if !name.isEmpty && !location.isEmpty {
            return "\(name) near \(location)"
        }

        if !name.isEmpty {
            return name
        }

        if !location.isEmpty {
            return "Near \(location)"
        }

        return "Search pop-ups"
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = Self.unitedStatesSearchRegion
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        requestUserLocation()
    }

    func filteredEvents(from events: [PopioEvent]) -> [PopioEvent] {
        let trimmedEventNameQuery = eventNameQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = events.filter { event in
            (selectedCategories.isEmpty || selectedCategories.contains(event.category))
                && (!isOpenNowOnly || isOpenNow(event))
                && (trimmedEventNameQuery.isEmpty || event.title.lowercased().contains(trimmedEventNameQuery))
                && (radiusOption == nil || distanceInMiles(for: event) <= radiusOption!.rawValue)
        }

        switch sortOption {
        case .popular:
            return filtered.sorted {
                if $0.likeCount == $1.likeCount {
                    return distanceInMiles(for: $0) < distanceInMiles(for: $1)
                }
                return $0.likeCount > $1.likeCount
            }
        case .distance:
            return filtered.sorted {
                let lhsDistance = distanceInMiles(for: $0)
                let rhsDistance = distanceInMiles(for: $1)

                if lhsDistance == rhsDistance {
                    return $0.likeCount > $1.likeCount
                }
                return lhsDistance < rhsDistance
            }
        }
    }

    func distanceInMiles(for event: PopioEvent) -> Double {
        guard let effectiveCoordinate else {
            return event.distanceInMiles
        }

        guard let eventCoordinate = event.coordinate else {
            return .greatestFiniteMagnitude
        }

        let selectedLocation = CLLocation(latitude: effectiveCoordinate.latitude, longitude: effectiveCoordinate.longitude)
        let eventLocation = CLLocation(latitude: eventCoordinate.latitude, longitude: eventCoordinate.longitude)
        return selectedLocation.distance(from: eventLocation) / 1609.344
    }

    func requestUserLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied, .restricted:
            userCoordinate = nil
            break
        @unknown default:
            break
        }
    }

    private func isOpenNow(_ event: PopioEvent, now: Date = .now) -> Bool {
        let calendar = Calendar.current
        guard calendar.isDate(event.eventDate, inSameDayAs: now) else { return false }

        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)

        let startMinutes = event.startTime.map { time in
            let components = calendar.dateComponents([.hour, .minute], from: time)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }

        let endMinutes = event.endTime.map { time in
            let components = calendar.dateComponents([.hour, .minute], from: time)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }

        switch (startMinutes, endMinutes) {
        case let (start?, end?):
            return nowMinutes >= start && nowMinutes <= end
        case let (start?, nil):
            return nowMinutes >= start
        case let (nil, end?):
            return nowMinutes <= end
        case (nil, nil):
            return true
        }
    }

    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        isSelectingSuggestion = true
        locationQuery = suggestion.title
        locationSuggestions = []
        completer.queryFragment = ""
        isSelectingSuggestion = false

        Task {
            let request = MKLocalSearch.Request(completion: suggestion)
            let search = MKLocalSearch(request: request)
            let response = try? await search.start()
            let coordinate = response?.mapItems.first?.placemark.coordinate

            await MainActor.run {
                self.selectedCoordinate = coordinate
            }
        }
    }

    func resolveTypedLocation() {
        let query = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            selectedCoordinate = nil
            locationSuggestions = []
            return
        }

        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.address, .pointOfInterest]

            let response = try? await MKLocalSearch(request: request).start()
            let coordinate = response?.mapItems.first?.placemark.coordinate
            let title = response?.mapItems.first?.placemark.title ?? response?.mapItems.first?.name

            await MainActor.run {
                self.selectedCoordinate = coordinate
                self.locationSuggestions = []

                if let title, !title.isEmpty {
                    self.isSelectingSuggestion = true
                    self.locationQuery = title
                    self.completer.queryFragment = ""
                    self.isSelectingSuggestion = false
                }
            }
        }
    }

    func clearSearch() {
        eventNameQuery = ""
        locationQuery = "United States"
        selectedCoordinate = nil
        locationSuggestions = []
        completer.queryFragment = ""
    }

    private static let unitedStatesSearchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
        span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 70)
    )

    private static let unitedStatesFallbackCoordinate = CLLocationCoordinate2D(
        latitude: 39.8283,
        longitude: -98.5795
    )
}

extension EventFeedViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results

        DispatchQueue.main.async {
            self.locationSuggestions = results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationSuggestions = []
        }
    }
}

extension EventFeedViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.userCoordinate = location.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.userCoordinate = nil
        }
    }
}
