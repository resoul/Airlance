import Foundation

extension AppStrings {
    func count(
        _ value: Int,
        one: (String) -> String,
        few: (String) -> String,
        many: (String) -> String
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = pack.locale
        formatter.numberStyle = .decimal
        let text = formatter.string(from: NSNumber(value: value)) ?? String(value)
        let language = pack.locale.language.languageCode?.identifier ?? "en"
        if language == "ro" {
            return romanianCount(value, text: text, one: one, few: few, many: many)
        }

        if language == "fr", value == 0 {
            return one(text)
        }

        guard ["uk", "ru", "be"].contains(language) else {
            return value == 1 ? one(text) : many(text)
        }

        let tens = value % 100
        switch value % 10 {
        case 1 where tens != 11:
            return one(text)
        case 2...4 where !(12...14).contains(tens):
            return few(text)
        default:
            return many(text)
        }
    }

    private func romanianCount(
        _ value: Int,
        text: String,
        one: (String) -> String,
        few: (String) -> String,
        many: (String) -> String
    ) -> String {
        guard value != 1 else {
            return one(text)
        }

        return value == 0 || (1...19).contains(value % 100) ? few(text) : many(text)
    }

    func compactCount(_ value: Int) -> String {
        guard value >= 1000 else {
            return String(value)
        }

        let (scaled, suffix) = value >= 1_000_000 ? (Double(value) / 1_000_000, "M") : (Double(value) / 1000, "K")
        let formatter = NumberFormatter()
        formatter.locale = pack.locale
        formatter.maximumFractionDigits = scaled < 10 ? 1 : 0

        return (formatter.string(from: NSNumber(value: scaled)) ?? String(Int(scaled))) + suffix
    }
}
