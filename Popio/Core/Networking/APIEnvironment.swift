import Foundation

enum APIEnvironment: String, CaseIterable, Identifiable {
    case local
    case staging
    case production

    var id: String { rawValue }
}
