import Foundation

enum MoneyFormat {
    static let display: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func decimal(from value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }

    static func amount(_ value: Decimal, currency: String = "EUR") -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatted = display.string(from: number) ?? "0.00"
        return "\(symbol(for: currency))\(formatted)"
    }

    static func signed(_ value: Decimal, currency: String = "EUR") -> String {
        let sign = value >= .zero ? "+" : "-"
        return "\(sign)\(amount(abs(value), currency: currency))"
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
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let dayHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
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

    static func apiDate(_ value: String) -> Date? {
        isoDate.date(from: dateOnly(value))
    }
}

func abs(_ value: Decimal) -> Decimal {
    value < .zero ? -value : value
}
