import SwiftUI

struct AuthView: View {
    @Bindable var store: MoneyManagerStore
    @State private var isPasswordVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 52)

                VStack(spacing: 9) {
                    Text("Money Manager")
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundStyle(AppColor.nearBlack)
                    Text("Track spending, spot patterns, stay in control.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.mutedText)
                        .multilineTextAlignment(.center)
                }

                PreviewBalanceCard()

                VStack(alignment: .leading, spacing: 14) {
                    LabeledInput(title: "Email") {
                        TextField("you@example.com", text: $store.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    LabeledInput(title: "Password") {
                        HStack {
                            Group {
                                if isPasswordVisible {
                                    TextField("••••••••", text: $store.password)
                                } else {
                                    SecureField("••••••••", text: $store.password)
                                }
                            }
                            .textInputAutocapitalization(.never)

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(AppColor.mutedText)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ErrorBanner(message: store.error)

                    PrimaryButton(
                        title: store.isRegisterMode ? "Create account" : "Log in",
                        isLoading: store.isLoading,
                        action: store.submitAuth
                    )

                    SecondaryButton(
                        title: store.isRegisterMode ? "Already have an account? Log in" : "Create account",
                        action: store.toggleAuthMode
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .appBackground()
    }
}

private struct PreviewBalanceCard: View {
    var body: some View {
        AppCard(padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("May 2026")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.mutedText)
                VStack(alignment: .leading, spacing: 4) {
                    Text("€3,921.50")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(AppColor.nearBlack)
                    Text("+€3,921.50")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.income)
                }

                Divider().overlay(AppColor.divider)

                HStack(spacing: 12) {
                    CategoryBadge(category: "food", size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Food")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.nearBlack)
                        Text("Top category")
                            .font(.caption)
                            .foregroundStyle(AppColor.mutedText)
                    }
                    Spacer()
                    Text("-€127.70")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.expense)
                }
            }
        }
    }
}

private struct LabeledInput<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.nearBlack)
            content
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetric.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppMetric.controlRadius, style: .continuous)
                        .stroke(AppColor.divider, lineWidth: 1)
                }
        }
    }
}
