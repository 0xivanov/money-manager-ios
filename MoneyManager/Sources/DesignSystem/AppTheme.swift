import SwiftUI

enum AppColor {
    static let background = Color(red: 0.957, green: 0.973, blue: 0.941)
    static let surface = Color.white
    static let softGreenSurface = Color(red: 0.937, green: 0.965, blue: 0.925)
    static let softGreenCard = Color(red: 0.882, green: 0.941, blue: 0.890)
    static let financeGreen = Color(red: 0.082, green: 0.357, blue: 0.231)
    static let nearBlack = Color(red: 0.086, green: 0.125, blue: 0.098)
    static let mutedText = Color(red: 0.400, green: 0.463, blue: 0.420)
    static let divider = Color(red: 0.894, green: 0.918, blue: 0.886)
    static let expense = Color(red: 0.820, green: 0.263, blue: 0.263)
    static let income = Color(red: 0.114, green: 0.541, blue: 0.322)

    static func category(_ category: String) -> Color {
        switch category.lowercased() {
        case "food": Color(red: 0.933, green: 0.416, blue: 0.408)
        case "transport": Color(red: 0.455, green: 0.792, blue: 0.753)
        case "housing": Color(red: 0.384, green: 0.706, blue: 0.800)
        case "utilities": Color(red: 0.898, green: 0.655, blue: 0.227)
        case "health": Color(red: 0.145, green: 0.612, blue: 0.557)
        case "entertainment": Color(red: 0.671, green: 0.584, blue: 0.820)
        case "shopping": Color(red: 0.541, green: 0.345, blue: 0.784)
        case "travel": Color(red: 0.220, green: 0.663, blue: 0.863)
        case "education": Color(red: 0.369, green: 0.667, blue: 0.384)
        case "salary", "freelance", "gift", "investment", "refund": income
        default: Color(red: 0.478, green: 0.549, blue: 0.510)
        }
    }
}

enum AppMetric {
    static let cardRadius: CGFloat = 22
    static let controlRadius: CGFloat = 16
    static let sectionSpacing: CGFloat = 18
}

extension View {
    func appBackground() -> some View {
        background(AppColor.background.ignoresSafeArea())
    }
}

func categoryTitle(_ category: String) -> String {
    category.prefix(1).uppercased() + category.dropFirst()
}

func categorySymbol(_ category: String) -> String {
    switch category.lowercased() {
    case "food": "fork.knife"
    case "transport": "car.fill"
    case "housing": "house.fill"
    case "utilities": "bolt.fill"
    case "health": "heart.fill"
    case "entertainment": "film.fill"
    case "shopping": "bag.fill"
    case "travel": "airplane"
    case "education": "graduationcap.fill"
    case "salary": "briefcase.fill"
    case "freelance": "laptopcomputer"
    case "gift": "gift.fill"
    case "investment": "chart.line.uptrend.xyaxis"
    case "refund": "receipt.fill"
    default: "ellipsis"
    }
}

func amountColor(_ amount: Decimal) -> Color {
    if amount > .zero { return AppColor.income }
    if amount < .zero { return AppColor.expense }
    return AppColor.mutedText
}
