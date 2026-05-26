import Foundation

enum AppUpdateRequirement: Equatable {
    case none
    case optional
    case required
}

struct AppVersionPolicy: Decodable, Equatable {
    let platform: String
    let minimumSupportedVersion: String
    let latestVersion: String
    let updateTitle: String
    let updateMessage: String
    let releaseNotes: [String]
    let appStoreURL: URL?
    let policyUpdatedAt: Date

    func requirement(for currentVersion: String) -> AppUpdateRequirement {
        if Self.compare(currentVersion, minimumSupportedVersion) == .orderedAscending {
            return .required
        }

        if Self.compare(currentVersion, latestVersion) == .orderedAscending {
            return .optional
        }

        return .none
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue < rightValue { return .orderedAscending }
            if leftValue > rightValue { return .orderedDescending }
        }

        return .orderedSame
    }

    private static func components(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { part in
                let numericPrefix = part.prefix { $0.isNumber }
                return Int(numericPrefix) ?? 0
            }
    }
}
