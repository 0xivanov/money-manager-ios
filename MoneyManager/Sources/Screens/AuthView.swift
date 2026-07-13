import SwiftUI

struct AuthView: View {
    @Bindable var store: MoneyManagerStore
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 42)

                AppLogo(size: 58)

                VStack(alignment: .leading, spacing: 7) {
                    Text(store.isRegisterMode ? "Create your account" : "Welcome back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppColor.nearBlack)
                    Text(store.isRegisterMode ? "Start building a complete view of your money." : "Your complete financial picture is waiting.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.mutedText)
                }

                VStack(alignment: .leading, spacing: 14) {
                    LabeledInput(title: "Email") {
                        TextField("you@example.com", text: $store.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .onSubmit { focusedField = .password }
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
                            .autocorrectionDisabled()
                            .textContentType(store.isRegisterMode ? .newPassword : .password)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .password)
                            .onSubmit(store.submitAuth)

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(AppColor.mutedText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                        }
                    }

                    ErrorBanner(message: store.error)

                    PrimaryButton(
                        title: store.isRegisterMode ? "Create account" : "Sign in",
                        isLoading: store.isLoading,
                        action: store.submitAuth
                    )

                    Button(action: store.toggleAuthMode) {
                        HStack(spacing: 4) {
                            Text(store.isRegisterMode ? "Already have an account?" : "New to Money Manager?")
                                .foregroundStyle(AppColor.mutedText)
                            Text(store.isRegisterMode ? "Sign in" : "Create account")
                                .fontWeight(.bold)
                                .foregroundStyle(AppColor.financeGreen)
                        }
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 22)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(AppColor.financeGreen)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Private by design")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColor.nearBlack)
                        Text("Your session is encrypted and financial credentials are never stored by Money Manager.")
                            .font(.caption)
                            .foregroundStyle(AppColor.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .background(AppColor.softGreenSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .appBackground()
    }
}

private struct BrandBenefitPanel: View {
    var body: some View {
        AppCard(color: AppColor.softGreenSurface, padding: 22) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your money, clearly organized")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColor.nearBlack)

                FeatureRow(icon: "chart.pie.fill", title: "Understand spending", detail: "See where your money goes each month.")
                FeatureRow(icon: "plus.forwardslash.minus", title: "Keep a clean ledger", detail: "Record income and expenses in seconds.")
                FeatureRow(icon: "lock.shield.fill", title: "Private by design", detail: "Your session is protected in the iOS Keychain.")
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppColor.financeGreen)
                .frame(width: 28, height: 28)
                .background(AppColor.softGreenCard)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.nearBlack)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
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
                .padding(.vertical, 14)
                .frame(minHeight: 54)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetric.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppMetric.controlRadius, style: .continuous)
                        .stroke(AppColor.divider, lineWidth: 1)
                }
        }
    }
}
