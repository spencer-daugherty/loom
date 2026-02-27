import SwiftUI

struct AccountStepView: View {
    @EnvironmentObject private var session: UserSessionStore

    @State private var showingEmailForm = false
    @State private var email = ""

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 20)

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 10) {
                Text("Save your weave across devices.")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Create an account to back up your plan and keep your direction synced.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    session.markAccountCreated()
                } label: {
                    Text("Continue with Apple")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("account_continueWithApple")

                Button {
                    showingEmailForm = true
                } label: {
                    Text("Use email")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("account_useEmail")
            }
            .padding(.top, 6)

            Spacer(minLength: 20)
        }
        .padding(20)
        .background(Color(.systemBackground).ignoresSafeArea())
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
}

#Preview {
    AccountStepView()
        .environmentObject(UserSessionStore())
}
