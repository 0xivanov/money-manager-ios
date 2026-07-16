import SwiftUI

struct AppCard<Content: View>: View {
    let color: Color
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(color: Color = AppColor.surface, padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.color = color
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous)
                .stroke(AppColor.divider, lineWidth: 1)
        }
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let tint: Color
    var hidesValue = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mutedText)
            PrivacyValueText(value: value, isHidden: hidesValue)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous)
                .stroke(AppColor.divider, lineWidth: 1)
        }
    }
}

struct PrivacyValueText: View {
    let value: String
    let isHidden: Bool
    var hiddenAccessibilityLabel = "Portfolio balance hidden"

    var body: some View {
        if isHidden {
            Text("••••••")
                .accessibilityLabel(hiddenAccessibilityLabel)
        } else {
            Text(value)
        }
    }
}

struct PortfolioPrivacyPlaceholder: View {
    var height: CGFloat
    var tint = AppColor.financeGreen

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "eye.slash.fill")
                .font(.title2)
                .foregroundStyle(tint)
            Text("Portfolio balances hidden")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mutedText)
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Portfolio balances hidden")
    }
}

struct InvestmentPriceStatus: View {
    let positions: [InvestmentPosition]
    var color = AppColor.mutedText

    var body: some View {
        if let updatedAt = InvestmentPriceTimestampFormat.latestUpdate(in: positions) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let relative = InvestmentPriceTimestampFormat.relativeElapsed(
                    since: updatedAt,
                    now: context.date
                )
                Text("Prices · updated \(relative)")
                    .font(.caption)
                    .foregroundStyle(color)
                    .accessibilityLabel("Prices updated \(relative)")
            }
        }
    }
}

struct CategoryBadge: View {
    let category: String
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColor.category(category).opacity(0.13))
            Image(systemName: categorySymbol(category))
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(AppColor.category(category))
        }
        .frame(width: size, height: size)
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppColor.financeGreen : AppColor.mutedText)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(isSelected ? AppColor.softGreenCard : AppColor.surface)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isSelected ? AppColor.softGreenCard : AppColor.divider, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                }
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(AppColor.primaryText)
            .background(AppColor.filledButton)
            .clipShape(RoundedRectangle(cornerRadius: AppMetric.controlRadius, style: .continuous))
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = AppColor.financeGreen
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                }
                Text(title)
                    .font(.headline.weight(.semibold))
            }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(tint)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetric.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppMetric.controlRadius, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct ErrorBanner: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColor.expense)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .accessibilityIdentifier("error-banner")
        }
    }
}

struct MonthNavigator: View {
    let month: String
    let canGoNext: Bool
    let previous: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Text(DateFormat.monthDisplay(month))
                    .font(.headline)
                    .foregroundStyle(AppColor.nearBlack)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    Button(action: previous) {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous month")

                    Spacer()

                    Button(action: next) {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoNext)
                    .accessibilityLabel("Next month")
                }
            }

            Rectangle()
                .fill(AppColor.divider)
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct AppLogo: View {
    var size: CGFloat = 72

    var body: some View {
        Image("BrandMark")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ScreenHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppColor.nearBlack)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}
