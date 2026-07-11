import Foundation

enum FeatureFlag: String, CaseIterable, Identifiable {
    case pushNotifications
    case premiumFeatures
    case businessAccounts
    case moderation

    var id: String { rawValue }
}

struct FeatureFlagService {
    private var enabledFlags: Set<FeatureFlag> = []

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        enabledFlags.contains(flag)
    }
}
