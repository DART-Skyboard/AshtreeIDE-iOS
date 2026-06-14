// ============================================================
//  IDEWelcomeView.swift — Sign-in screen
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//  Matches ArcLake ArcWelcomeView pattern exactly.
// ============================================================

import SwiftUI
import AuthenticationServices

struct IDEWelcomeView: View {
    @EnvironmentObject var authVM:  IDEAuthViewModel
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @State private var showDeviceFlow = false
    @State private var pulseAnim = false

    var hasStoredGitHub: Bool {
        guard let t = KeychainHelper.load(key: "ide_github_pat") else { return false }
        return !t.isEmpty
    }
    var storedGitHubUser: String {
        KeychainHelper.load(key: "ide_github_username") ?? "GitHub"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0d1b3e"), Color(hex: "#050a10")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo orb ──────────────────────────────────────────
                ZStack {
                    Circle()
                        .stroke(themeVM.accent.opacity(0.08), lineWidth: 1)
                        .frame(width: pulseAnim ? 200 : 168, height: pulseAnim ? 200 : 168)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                                   value: pulseAnim)
                    Circle()
                        .fill(Color(hex: "#0d1b3e").opacity(0.5))
                        .frame(width: 148, height: 148)
                    Circle()
                        .stroke(themeVM.accent.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 148, height: 148)

                    if let logo = UIImage(named: "AppLogo") {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    } else {
                        IDELogoMark(size: 140, accent: themeVM.accent)
                    }
                }
                .onAppear { pulseAnim = true }

                Spacer().frame(height: 28)

                VStack(spacing: 5) {
                    Text("ASH TREE IDE")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .kerning(6)
                    Text("LEATR · Lead Edge · Radical Deepscale")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // ── Auth buttons ──────────────────────────────────────
                VStack(spacing: 12) {

                    // ① Sign in with Apple (always first per Apple HIG)
                    if !authVM.savedAccounts.filter({ $0.provider == "apple" }).isEmpty {
                        // Resume Apple account
                        let acc = authVM.savedAccounts.first { $0.provider == "apple" }!
                        Button {
                            authVM.signInWithApple()
                        } label: {
                            HStack {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 16, weight: .semibold))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(acc.username)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Apple · tap to sign in")
                                        .font(.system(size: 10))
                                        .opacity(0.7)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(.white)
                            .cornerRadius(14)
                        }
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            if case .success(let auth) = result {
                                authVM.authorizationController(
                                    controller: ASAuthorizationController(authorizationRequests: []),
                                    didCompleteWithAuthorization: auth)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 56)
                        .cornerRadius(14)
                    }

                    // ② GitHub — resume or new
                    if hasStoredGitHub {
                        Button {
                            Task { await authVM.startGitHubDeviceFlow() }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Continue as \(storedGitHubUser)")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("GitHub · already authorized")
                                        .font(.system(size: 10))
                                        .foregroundColor(themeVM.accent)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(themeVM.accent)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(Color(hex: "#161b22"))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(themeVM.accent.opacity(0.4), lineWidth: 1))
                            .cornerRadius(14)
                        }
                    } else {
                        Button {
                            showDeviceFlow = true
                            Task { await authVM.startGitHubDeviceFlow() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Sign in with GitHub")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "#161b22"))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15), lineWidth: 1))
                            .cornerRadius(14)
                        }
                    }

                    // ③ Use a different GitHub account
                    if hasStoredGitHub {
                        Button("Use a different GitHub account") {
                            showDeviceFlow = true
                            Task { await authVM.startGitHubDeviceFlow() }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .underline()
                    }

                    // ④ Continue as Guest
                    Button {
                        authVM.continueAsGuest()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 13))
                            Text("Continue as Guest")
                                .font(.system(size: 15, weight: .regular))
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 28)

                // Device flow panel
                if let flow = authVM.deviceFlow {
                    IDEDeviceFlowPanel(flow: flow)
                        .padding(.top, 20)
                        .padding(.horizontal, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Apple Sign In error (e.g. "Sign Up Not Completed" = Apple server issue)
                if let appleErr = authVM.appleErrorMessage {
                    VStack(spacing: 4) {
                        Text("⚠ Apple Sign In")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                        Text(appleErr)
                            .font(.system(size: 10))
                            .foregroundColor(.orange.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
                }
                if let err = authVM.error {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                }

                Spacer()

                Text("Your scripts save to your private GitHub repository.")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - Device Flow Panel

struct IDEDeviceFlowPanel: View {
    let flow: IDEDeviceFlow
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text("ENTER ON GITHUB.COM/LOGIN/DEVICE")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .kerning(1.5)

            Text(flow.userCode)
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundColor(themeVM.accent)
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .background(Color(hex: "#0d1117"))
                .cornerRadius(10)
                .onTapGesture { UIPasteboard.general.string = flow.userCode }

            Text("Code copied to clipboard · tap to copy again")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))

            if flow.isPolling {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7).tint(themeVM.accent)
                    Text("Waiting for authorization…")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            if let err = flow.error {
                Text(err).font(.system(size: 11)).foregroundColor(.red).multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(Color(hex: "#161b22"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
