import Foundation

extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}

extension String {
    /// Returns a condensed string, with no extra whitespaces and no new lines.
    var condensed: String {
        replacingOccurrences(of: "[\\s\n]+", with: " ", options: .regularExpression, range: nil)
    }

    /// Returns a condensed string, with no whitespaces at all and no new lines.
    var extraCondensed: String {
        replacingOccurrences(of: "[\\s\n]+", with: "", options: .regularExpression, range: nil)
    }
}
