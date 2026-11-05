import Foundation

public enum PhoneDigits {
    private static let callingCodes = [
        "UA": "380", "RU": "7", "KZ": "7", "BY": "375", "PL": "48", "DE": "49", "FR": "33", "IT": "39", "ES": "34",
        "RO": "40", "MD": "373", "GB": "44", "US": "1", "CA": "1", "TR": "90", "IL": "972", "GE": "995", "LT": "370",
        "LV": "371", "EE": "372", "CZ": "420", "SK": "421", "HU": "36", "NL": "31", "BE": "32", "AT": "43", "CH": "41",
        "PT": "351", "GR": "30", "SE": "46", "NO": "47", "FI": "358", "DK": "45", "IE": "353", "BG": "359",
    ]

    public static func international(_ raw: String, region: String?) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isASCII).filter(\.isNumber)
        if trimmed.hasPrefix("+") {
            return digits
        }

        if digits.hasPrefix("00") {
            return String(digits.dropFirst(2))
        }

        guard let region, let code = callingCodes[region.uppercased()] else {
            return digits
        }

        if digits.hasPrefix(code), digits.count > 10 {
            return digits
        }

        return code + (digits.hasPrefix("0") ? String(digits.dropFirst()) : digits)
    }

    public static var currentRegion: String? {
        Locale.current.region?.identifier
    }
}
