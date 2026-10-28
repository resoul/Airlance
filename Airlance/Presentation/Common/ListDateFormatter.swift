import Foundation

struct ListDateFormatter {
    private let calendar = Calendar.current
    private let time: DateFormatter
    private let weekday: DateFormatter
    private let thisYear: DateFormatter
    private let older: DateFormatter

    init(locale: Locale) {
        time = Self.formatter(locale: locale, template: "jmm")
        weekday = Self.formatter(locale: locale, template: "EEEEEE")
        thisYear = Self.formatter(locale: locale, format: "dd/MM")
        older = Self.formatter(locale: locale, format: "dd/MM/yy")
    }

    func string(for date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return time.string(from: date)
        }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: now).day ?? 0
        if days < 7 {
            return weekday.string(from: date)
        }

        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return thisYear.string(from: date)
        }

        return older.string(from: date)
    }

    private static func formatter(locale: Locale, template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)

        return formatter
    }

    private static func formatter(locale: Locale, format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format

        return formatter
    }
}
