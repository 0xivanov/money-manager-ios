import SwiftUI

struct OpenBankingInstitutionMark: View {
    let name: String
    let logo: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let logo,
                let url = URL(string: logo),
                url.scheme?.lowercased() == "https"
            {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    fallback
                }
                .padding(7)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(AppColor.background)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.35, weight: .bold))
            .foregroundStyle(AppColor.nearBlack)
    }
}

struct OpenBankingSectionLabel: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColor.financeGreen)
            .tracking(0.8)
            .accessibilityAddTraits(.isHeader)
    }
}

struct OpenBankingLoadingCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppColor.financeGreen)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.nearBlack)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct OpenBankingRecoveryCard: View {
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AppColor.expense)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppColor.nearBlack)
            Button(actionTitle, action: action)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColor.expense)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.expense.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

enum OpenBankingDate {
    static func short(_ value: String) -> String {
        guard let date = parse(value) else { return String(value.prefix(10)) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func transaction(_ value: String) -> String {
        guard let date = DateFormat.isoDate.date(from: String(value.prefix(10))) else { return String(value.prefix(10)) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private static func parse(_ value: String) -> Date? {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = precise.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}

extension OpenBankingLoadState {
    var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
