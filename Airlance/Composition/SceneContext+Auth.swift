import Auth
import ServerConnection
import ToastUI
import UIKit

extension SceneContext {
    func addAccount() {
        startSignIn {}
    }

    func startSignIn(onEnd: @escaping @MainActor () -> Void) {
        guard !isSigningIn else {
            onEnd()

            return
        }

        isSigningIn = true
        let signIn = AuthWebSignIn(configuration: .airlance, anchor: window)
        Task { [weak self] in
            do {
                let result = try await signIn.start()
                try await self?.finishSignIn(result)
            } catch AuthError.cancelled {
                Self.logger.debug("Sign-in cancelled")
            } catch {
                self?.showSignInError(error)
            }
            self?.isSigningIn = false
            onEnd()
        }
    }

    func revalidate() {
        guard
            let id = selectedID,
            let record = app.accounts.record(id),
            !record.isDemo,
            record.currentStatus == .active
        else {
            return
        }

        guard let server = connectServer(for: id) else {
            return
        }

        Task {
            await server.pull()
        }
    }

    private func connectServer(for id: AccountID) -> AccountServer? {
        guard
            let server = app.servers.server(for: id),
            case .success(let account) = app.accounts.context(for: id)
        else {
            return nil
        }

        let accounts = app.accounts
        server.attach(account.myProfile)
        server.onMissingProfile = {
            accounts.setStatus(.needsProfile, for: id)
        }
        server.onSessionEnded = {
            accounts.setStatus(.signedOut, for: id)
        }
        server.onSaveFailed = { [weak self] error in
            self?.showProfileError(error)
        }
        server.follow(account)

        return server
    }

    private func finishSignIn(_ result: AuthSignIn) async throws {
        let id = AccountID.user(subject: result.subject)
        try await app.auth.save(result.tokens, account: id.rawValue)
        let server = app.servers.server(for: id)
        let remote = try? await server?.fetchProfile()
        _ = app.accounts.addSignedIn(subject: result.subject, email: result.email, hasProfile: remote != nil)
        if let remote, case .success(let account) = app.accounts.context(for: id) {
            server?.attach(account.myProfile)
            server?.apply(remote)
        }
        if selectedID != id {
            show(id)
        }
    }

    private func profileErrorText(_ error: any Error) -> String {
        let strings = presentationContext.presentation.strings
        if case AccountServerError.refused(_, let message) = error {
            switch message {
            case "username_taken":
                return strings.authProfileUsernameTaken
            case "invalid_username":
                return strings.authProfileUsernameInvalid
            case "invalid_name":
                return strings.authProfileNameInvalid
            default:
                return strings.authProfileFailed(message)
            }
        }

        return strings.authProfileFailed(error.localizedDescription)
    }

    private func showProfileError(_ error: any Error) {
        let theme = presentationContext.presentation.theme
        Toast(profileErrorText(error)).show(theme: theme, in: window)
    }

    private func saveFirstProfile(
        id: AccountID,
        account: AccountContext,
        fields: AuthProfileFields
    ) async -> String? {
        guard let server = app.servers.server(for: id) else {
            return nil
        }

        do {
            let remote = try await server.saveProfile(ServerProfile(fields))
            server.attach(account.myProfile)
            server.apply(remote)
            app.accounts.setStatus(.active, for: id)

            return nil
        } catch AuthError.sessionEnded, ServerConnectionError.unauthorized {
            app.accounts.setStatus(.signedOut, for: id)

            return nil
        } catch {
            return profileErrorText(error)
        }
    }

    private func showSignInError(_ error: any Error) {
        let presentation = presentationContext.presentation
        let detail = (error as? AuthError)?.detail ?? error.localizedDescription
        Toast(presentation.strings.authSignInFailed(detail)).show(theme: presentation.theme, in: window)
    }

    func gateNeeded(_ id: AccountID) -> Bool {
        app.accounts.record(id).map { record in
            record.currentStatus != .active
        } ?? false
    }

    func showWelcome() {
        window.rootViewController = AuthGate.entry(
            step: .welcome,
            playsIntro: ParticleSplashView.claimFirstShow(),
            presentationContext: presentationContext,
            onContinue: { [weak self] onEnd in
                self?.startSignIn(onEnd: onEnd)
            },
            onOther: nil
        )
    }

    func showGate(for id: AccountID, account: AccountContext) -> Bool {
        switch app.accounts.record(id)?.currentStatus {
        case .signedOut:
            let other = app.accounts.records.first { record in
                record.id != id
            }?.id
            window.rootViewController = AuthGate.entry(
                step: .sessionEnded(canSwitch: other != nil),
                playsIntro: ParticleSplashView.claimFirstShow(),
                presentationContext: presentationContext,
                onContinue: { [weak self] onEnd in
                    self?.startSignIn(onEnd: onEnd)
                },
                onOther: { [weak self] in
                    if let other {
                        self?.switchAccount(to: other)
                    }
                }
            )
        case .needsProfile:
            window.rootViewController = AuthGate.profile(
                presentationContext: presentationContext
            ) { [weak self] fields in
                await self?.saveFirstProfile(id: id, account: account, fields: fields)
            }
        default:
            return false
        }

        return true
    }
}
