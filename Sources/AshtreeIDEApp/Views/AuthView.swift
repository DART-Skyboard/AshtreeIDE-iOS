// ============================================================
//  AuthView.swift — Sign in with Apple / GitHub
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var github: GitHubService
    @State private var showGitHubFlow = false
    @State private var deviceCode = ""
    @State private var userCode = ""
    @State private var verifyUrl = ""
    @State private var interval = 5
    @State private var isPolling = false
    @State private var pollError = ""

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                AshTreeLogoMark(size: 88)
                    .padding(.bottom, 24)

                Text("ASH TREE IDE")
                    .font(.custom("Georgia-Bold", size: 24))
                    .foregroundColor(Color("AshDark"))
                    .kerning(5)

                Text("LEATR · Radical Deepscale LLC.")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color("AshMid"))
                    .kerning(2)
                    .padding(.top, 4)
                    .padding(.bottom, 52)

                // Auth buttons
                VStack(spacing: 14) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .cornerRadius(12)

                    // Sign in with GitHub
                    Button { Task { await startGitHub() } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Sign in with GitHub")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color("AshDark"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(github.isSigningIn)

                    // Continue as Guest
                    Button { continueAsGuest() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 13))
                            Text("Continue as Guest")
                                .font(.system(size: 15, weight: .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color("AshLight"))
                        .foregroundColor(Color("AshMid"))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)

                // GitHub device flow panel
                if showGitHubFlow {
                    GitHubDevicePanel(
                        userCode: userCode,
                        verifyUrl: verifyUrl,
                        isPolling: isPolling,
                        error: pollError
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.top, 24)
                    .padding(.horizontal, 32)
                }

                Spacer()

                Text("Your scripts save to your private GitHub repository.")
                    .font(.system(size: 10))
                    .foregroundColor(Color("AshMid").opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Apple Sign-In

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }.joined(separator: " ")
                // For Apple sign-in, use Keychain user identifier as username
                let userID = credential.user
                let truncated = String(userID.prefix(12))
                Task {
                    // Apple doesn't give GitHub tokens — store local session
                    await github.completeSignIn(token: "apple-\(truncated)")
                }
            }
        case .failure(let err):
            github.error = err.localizedDescription
        }
    }

    // MARK: - GitHub Device Flow

    private func startGitHub() async {
        github.isSigningIn = true
        guard let flow = await github.startDeviceFlow() else {
            github.error = "Could not start GitHub sign-in"; github.isSigningIn = false; return
        }
        userCode    = flow.userCode
        verifyUrl   = flow.verifyUrl
        deviceCode  = flow.deviceCode
        interval    = flow.interval
        withAnimation { showGitHubFlow = true }

        // Copy code to clipboard
        UIPasteboard.general.string = userCode

        // Open GitHub in browser
        if let url = URL(string: verifyUrl) { await UIApplication.shared.open(url) }

        isPolling = true
        if let token = await github.pollDeviceFlow(deviceCode: deviceCode, interval: interval) {
            await github.completeSignIn(token: token)
        } else {
            pollError = "Authorization expired. Please try again."
        }
        isPolling = false
        github.isSigningIn = false
    }

    private func continueAsGuest() {
        let guest = GitHubSession(accessToken: "guest", username: "guest",
                                  name: "Guest", avatarUrl: nil)
        // Directly set — no repo creation for guests
        Task { @MainActor in github.session = guest }
    }
}

// MARK: - GitHub Device Code Panel

struct GitHubDevicePanel: View {
    let userCode: String
    let verifyUrl: String
    let isPolling: Bool
    let error: String

    var body: some View {
        VStack(spacing: 12) {
            Text("ENTER THIS CODE ON GITHUB")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color("AshMid"))
                .kerning(2)

            Text(userCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(Color("AshDark"))
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .background(Color("AshLight"))
                .cornerRadius(10)
                .onTapGesture { UIPasteboard.general.string = userCode }

            Text("Code copied to clipboard · tap to copy again")
                .font(.system(size: 9))
                .foregroundColor(Color("AshMid").opacity(0.5))

            if isPolling {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Waiting for authorization…")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color("AshMid"))
                }
            }

            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(Color("AshLight"))
        .cornerRadius(12)
    }
}
