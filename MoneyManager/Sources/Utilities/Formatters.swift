import Foundation

enum MoneyFormat {
    private static let apiDisplay: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func decimal(from value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }

    static func inputDecimal(from value: String, locale: Locale = .current) -> Decimal? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let localeSeparator = locale.decimalSeparator ?? "."
        let fallbackSeparator = localeSeparator == "," ? "." : ","
        let containsLocaleSeparator = trimmed.contains(localeSeparator)
        let containsFallbackSeparator = trimmed.contains(fallbackSeparator)
        guard !(containsLocaleSeparator && containsFallbackSeparator) else { return nil }

        let normalized: String
        if containsLocaleSeparator {
            normalized = trimmed.replacingOccurrences(of: localeSeparator, with: ".")
        } else if containsFallbackSeparator {
            normalized = trimmed.replacingOccurrences(of: fallbackSeparator, with: ".")
        } else {
            normalized = trimmed
        }

        guard normalized.range(
            of: #"^[0-9]+(?:\.[0-9]{1,2})?$"#,
            options: .regularExpression
        ) != nil else { return nil }

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func apiAmount(_ value: Decimal) -> String {
        apiDisplay.string(from: NSDecimalNumber(decimal: value)) ?? NSDecimalNumber(decimal: value).stringValue
    }

    static func amount(_ value: Decimal, currency: String = "EUR", locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let number = NSDecimalNumber(decimal: value)
        return formatter.string(from: number) ?? "\(symbol(for: currency))\(apiAmount(value))"
    }

    static func signed(_ value: Decimal, currency: String = "EUR", locale: Locale = .current) -> String {
        let sign = value >= .zero ? "+" : "-"
        return "\(sign)\(amount(abs(value), currency: currency, locale: locale))"
    }

    static func symbol(for currency: String) -> String {
        switch currency.uppercased() {
        case "EUR": "€"
        case "USD": "$"
        case "GBP": "£"
        default: "\(currency.uppercased()) "
        }
    }
}

enum DateFormat {
    private static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let fractionalInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let monthKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static let displayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    static let dayHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter
    }()

    static func dateOnly(_ value: String) -> String {
        String(value.prefix(10))
    }

    static func monthDisplay(_ month: String) -> String {
        guard let date = isoDate.date(from: "\(month)-01") else { return month }
        return displayMonth.string(from: date)
    }

    static func todayString() -> String {
        isoDate.string(from: Date())
    }

    static func currentMonthKey() -> String {
        monthKey.string(from: Date())
    }

    static func firstDay(of month: String) -> String {
        "\(month)-01"
    }

    static func firstDayDate(of month: String) -> Date {
        isoDate.date(from: firstDay(of: month)) ?? Date()
    }

    static func lastDayDate(of month: String) -> Date {
        guard
            let firstDay = monthKey.date(from: month),
            let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: firstDay),
            let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: nextMonth)
        else { return Date() }
        return lastDay
    }

    static func apiDate(_ value: String) -> Date? {
        isoDate.date(from: dateOnly(value))
    }

    static func apiTimestamp(_ date: Date) -> String {
        internetDateTime.string(from: date)
    }

    static func apiDateTime(_ value: String) -> Date? {
        fractionalInternetDateTime.date(from: value)
            ?? internetDateTime.date(from: value)
            ?? apiDate(value)
    }

    static func dateTimeDisplay(_ value: String) -> String {
        guard let date = apiDateTime(value) else { return value }
        return date.formatted(date: .abbreviated, time: value.contains("T") ? .shortened : .omitted)
    }
}

func abs(_ value: Decimal) -> Decimal {
    value < .zero ? -value : value
}
