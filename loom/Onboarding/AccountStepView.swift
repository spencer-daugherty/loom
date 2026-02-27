import SwiftUI

struct AccountStepView: View {
    @EnvironmentObject private var session: UserSessionStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingEmailForm = false
    @State private var email = ""

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Text("End Stress. Live Fulfilled.")
                    .font(.system(size: 39, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Join the project.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    session.markAccountCreated()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Continue with Apple")
                            .font(.headline)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(colorScheme == .dark ? .white : .black)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account_continueWithApple")

                Button {
                    session.markAccountCreated()
                } label: {
                    HStack(spacing: 10) {
                        googleGIcon
                        Text("Continue with Google")
                            .font(.headline)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account_continueWithGoogle")

                Button {
                    showingEmailForm = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Continue with Email")
                            .font(.headline)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account_useEmail")
            }
            .padding(.top, 6)

            Text("By continuing you agree to Loom's Terms of Service and Privacy Policy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground).ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            Group {
                if colorScheme == .dark {
                    Image("logo")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.white)
                } else {
                    Image("logo")
                        .resizable()
                }
            }
            .scaledToFit()
            .frame(height: 40)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(isPresented: $showingEmailForm) {
            NavigationStack {
                Form {
                    Section("Email") {
                        TextField("name@example.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                    }
                }
                .navigationTitle("Create account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEmailForm = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") {
                            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            showingEmailForm = false
                            session.markAccountCreated()
                        }
                    }
                }
            }
        }
    }

    private var googleGIcon: some View {
        Image("GoogleLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20, alignment: .center)
    }
}

#Preview {
    AccountStepView()
        .environmentObject(UserSessionStore())
}
