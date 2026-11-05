import AirlanceUI
import Protocol
import ToastUI
import UIKit

final class AgentEditController: ScreenViewController {
    private static let hookBase = "https://api.airlance.org/hooks/"

    private let dependencies: AgentsDependencies
    private let router: AppRouter
    private let form = AgentFormView()
    private var agent: ServerAgent
    private var isSaving = false

    private var chats: [AgentChatOption] {
        dependencies.chatsStore.chats.compactMap { chat in
            chat.isServer && chat.isAdmin && chat.kind != .person ? AgentChatOption(id: chat.id, title: chat.name) : nil
        }
    }

    init(dependencies: AgentsDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        agent = dependencies.agents.agent(dependencies.agents.editingID) ?? ServerAgent(clientID: UUID().uuidString)
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in
                self?.save()
            }
        )
        form.fill(agent, chats: chats)
        view.addSubview(form)
        if !agent.id.isEmpty {
            navigationItem.leftItemsSupplementBackButton = true
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"),
                menu: moreMenu()
            )
        }
        if chats.isEmpty, agent.id.isEmpty {
            showToast(presentation.strings.agentsNoChats)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        form.frame = view.bounds
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        view.backgroundColor = presentation.theme.groupedBackground
        navigationItem.title = agent.id.isEmpty ? presentation.strings.agentsNew : agent.name
        form.apply(presentation)
    }

    private func moreMenu() -> UIMenu {
        let strings = presentation.strings
        var items = [
            UIAction(title: strings.agentsLog, image: UIImage(systemName: "list.bullet.rectangle")) { [router] _ in
                router.open(.settingsPage(.agentRuns))
            },
        ]
        if agent.trigger == .webhook {
            items.append(UIAction(
                title: strings.agentsHookRotate,
                image: UIImage(systemName: "arrow.triangle.2.circlepath")
            ) { [weak self] _ in
                self?.save(rotate: true)
            })
        }
        items.append(UIAction(
            title: strings.agentsDelete,
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.confirmDelete()
        })

        return UIMenu(children: items)
    }

    private func save(rotate: Bool = false) {
        guard !isSaving else {
            return
        }

        isSaving = true
        form.endEditing(true)
        let draft = form.draft(from: agent)
        let isNewHook = draft.trigger == .webhook && (draft.id.isEmpty || agent.trigger != .webhook)
        let agents = dependencies.agents
        Task { [weak self] in
            do {
                let token = try await agents.save(draft, rotateWebhook: rotate || isNewHook)
                self?.saved(token: token)
            } catch {
                self?.isSaving = false
                self?.showToast(self?.presentation.strings.agentsFailed ?? "")
            }
        }
    }

    private func saved(token: String) {
        isSaving = false
        guard !token.isEmpty else {
            router.back()

            return
        }

        showHook(Self.hookBase + token)
    }

    private func showHook(_ url: String) {
        let strings = presentation.strings
        let router = router
        PopupAlert.show(
            title: strings.agentsHookTitle,
            message: "\(url)\n\n\(strings.agentsHookOnce)",
            actions: [
                PopupAlertAction(title: strings.linkCopy) {
                    UIPasteboard.general.string = url
                    router.back()
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel) {
                    router.back()
                },
            ],
            theme: presentation.theme,
            in: view
        )
    }

    private func confirmDelete() {
        let strings = presentation.strings
        PopupAlert.show(
            title: nil,
            message: strings.agentsDeleteConfirm,
            actions: [
                PopupAlertAction(title: strings.agentsDelete, style: .destructive) { [weak self] in
                    self?.delete()
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }

    private func delete() {
        let id = agent.id
        let agents = dependencies.agents
        Task { [weak self] in
            do {
                try await agents.delete(id)
                self?.router.back()
            } catch {
                self?.showToast(self?.presentation.strings.agentsFailed ?? "")
            }
        }
    }

    private func showToast(_ text: String) {
        guard let window = view.window ?? UIApplication.shared.connectedScenes.compactMap({ scene in
            (scene as? UIWindowScene)?.keyWindow
        }).first else {
            return
        }

        Toast(text).show(theme: presentation.theme, in: window)
    }
}
