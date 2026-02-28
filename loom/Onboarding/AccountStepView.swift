import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

struct AccountStepView: View {
    @EnvironmentObject private var session: UserSessionStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingEmailForm = false
    @State private var email = ""
    @State private var appleSignInError: String?
    @State private var showMoreOptions = false

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
                #if canImport(AuthenticationServices)
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                            appleSignInError = "Unable to complete Apple sign in."
                            return
                        }
                        session.completeSignInWithApple(credential)
                        appleSignInError = nil
                    case .failure(let error):
                        if let authError = error as? ASAuthorizationError {
                            if authError.code == .canceled {
                                // User dismissed the sheet; don't show as an error.
                                appleSignInError = nil
                            } else if authError.code == .failed {
                                appleSignInError = "Apple sign in failed. Please try again."
                            } else if authError.code == .invalidResponse {
                                appleSignInError = "Apple sign in returned an invalid response."
                            } else if authError.code == .notHandled {
                                appleSignInError = "Apple sign in could not be completed on this device."
                            } else if authError.code == .unknown {
                                appleSignInError = "Apple sign in encountered an unknown error."
                            } else {
                                appleSignInError = "Apple sign in failed with an unsupported error."
                            }
                        } else {
                            appleSignInError = error.localizedDescription
                        }
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("account_continueWithApple")
                #else
                Button {
                    appleSignInError = "Sign in with Apple is unavailable on this platform."
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
                #endif

                if !showMoreOptions {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showMoreOptions = true
                        }
                    } label: {
                        Text("Continue with more options")
                            .font(.system(size: 12.75, weight: .regular))
                            .underline()
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }

                if showMoreOptions {
                    Button {
                        session.markAccountCreated()
                    } label: {
                        HStack(spacing: 10) {
                            Spacer(minLength: 0)
                            googleGIcon
                            Text("Continue with Google")
                                .font(.headline)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
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
                            Spacer(minLength: 0)
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 32, weight: .semibold))
                            Text("Continue with Email")
                                .font(.headline)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray5))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("account_useEmail")
                }
            }
            .padding(.top, 6)

            if let appleSignInError, !appleSignInError.isEmpty {
                Text(appleSignInError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

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
            .frame(width: 40, height: 40, alignment: .center)
    }
}

#Preview {
    AccountStepView()
        .environmentObject(UserSessionStore())
}
