import Foundation

extension String {
    var priceParsingNormalized: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "　", with: " ")
    }
}

