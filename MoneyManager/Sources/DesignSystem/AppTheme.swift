import SwiftUI
import UIKit

enum AppColor {
    static let background = adaptive(light: (0.984, 0.980, 0.969), dark: (0.043, 0.043, 0.039))
    static let surface = adaptive(light: (1.000, 1.000, 1.000), dark: (0.098, 0.098, 0.090))
    static let elevatedSurface = adaptive(light: (1.000, 1.000, 1.000), dark: (0.129, 0.129, 0.118))
    static let softGreenSurface = adaptive(light: (0.847, 0.988, 0.910), dark: (0.031, 0.216, 0.125))
    static let softGreenCard = adaptive(light: (0.847, 0.988, 0.910), dark: (0.035, 0.286, 0.161))
    static let financeGreen = adaptive(light: (0.016, 0.420, 0.231), dark: (0.125, 0.851, 0.510))
    static let filledButton = adaptive(light: (0.016, 0.420, 0.231), dark: (0.125, 0.851, 0.510))
    static let nearBlack = adaptive(light: (0.043, 0.043, 0.039), dark: (0.973, 0.969, 0.953))
    static let mutedText = adaptive(light: (0.361, 0.384, 0.369), dark: (0.682, 0.718, 0.694))
    static let divider = adaptive(light: (0.902, 0.894, 0.867), dark: (0.200, 0.200, 0.184))
    static let expense = adaptive(light: (0.663, 0.212, 0.169), dark: (1.000, 0.420, 0.380))
    static let income = adaptive(light: (0.016, 0.420, 0.231), dark: (0.125, 0.851, 0.510))
    static let stocks = adaptive(light: (0.082, 0.286, 0.835), dark: (0.176, 0.353, 0.906))
    static let crypto = adaptive(light: (0.957, 0.596, 0.071), dark: (1.000, 0.651, 0.122))
    static let invertedSurface = adaptive(light: (0.043, 0.043, 0.039), dark: (0.973, 0.969, 0.953))
    static let inverseText = adaptive(light: (1.000, 1.000, 1.000), dark: (0.043, 0.043, 0.039))
    static let primaryText = adaptive(light: (1.000, 1.000, 1.000), dark: (0.043, 0.043, 0.039))

    static func category(_ category: String) -> Color {
        switch category.lowercased() {
        case "food": return Color(red: 0.933, green: 0.416, blue: 0.408)
        case "transport": return Color(red: 0.455, green: 0.792, blue: 0.753)
        case "housing": return Color(red: 0.384, green: 0.706, blue: 0.800)
        case "utilities": return Color(red: 0.898, green: 0.655, blue: 0.227)
        case "health": return Color(red: 0.145, green: 0.612, blue: 0.557)
        case "entertainment": return Color(red: 0.671, green: 0.584, blue: 0.820)
        case "shopping": return Color(red: 0.541, green: 0.345, blue: 0.784)
        case "travel": return Color(red: 0.220, green: 0.663, blue: 0.863)
        case "education": return Color(red: 0.369, green: 0.667, blue: 0.384)
        case "salary", "freelance", "gift", "investment", "refund": return income
        default:
            let palette: [Color] = [
                Color(red: 0.784, green: 0.365, blue: 0.467),
                Color(red: 0.267, green: 0.584, blue: 0.741),
                Color(red: 0.718, green: 0.486, blue: 0.208),
                Color(red: 0.420, green: 0.588, blue: 0.337),
                Color(red: 0.565, green: 0.431, blue: 0.753),
                Color(red: 0.176, green: 0.604, blue: 0.553),
                Color(red: 0.820, green: 0.431, blue: 0.275),
                Color(red: 0.357, green: 0.502, blue: 0.702)
            ]
            return palette[stableCategoryIndex(category, count: palette.count)]
        }
    }

    private static func adaptive(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let components = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: components.0, green: components.1, blue: components.2, alpha: 1)
        })
    }
}

enum AppMetric {
    static let cardRadius: CGFloat = 22
    static let controlRadius: CGFloat = 18
    static let sectionSpacing: CGFloat = 16
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
    case "food": return "fork.knife"
    case "transport": return "car.fill"
    case "housing": return "house.fill"
    case "utilities": return "bolt.fill"
    case "health": return "heart.fill"
    case "entertainment": return "film.fill"
    case "shopping": return "bag.fill"
    case "travel": return "airplane"
    case "education": return "graduationcap.fill"
    case "salary": return "briefcase.fill"
    case "freelance": return "laptopcomputer"
    case "gift": return "gift.fill"
    case "investment": return "chart.line.uptrend.xyaxis"
    case "refund": return "receipt.fill"
    default:
        let symbols = [
            "tag.fill", "leaf.fill", "cup.and.saucer.fill", "figure.walk",
            "paintpalette.fill", "wrench.and.screwdriver.fill", "pawprint.fill", "shippingbox.fill"
        ]
        return symbols[stableCategoryIndex(category, count: symbols.count)]
    }
}

private func stableCategoryIndex(_ category: String, count: Int) -> Int {
    let value = category.lowercased().utf8.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
        (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
    return Int(value % UInt64(count))
}

func amountColor(_ amount: Decimal) -> Color {
    if amount > .zero { return AppColor.income }
    if amount < .zero { return AppColor.expense }
    return AppColor.mutedText
}
