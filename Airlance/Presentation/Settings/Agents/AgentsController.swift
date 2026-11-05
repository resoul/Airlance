import AirlanceUI
import ListUI
import Observers
import Protocol
import ToastUI
import UIKit

struct AgentsDependencies {
    let presentationContext: PresentationContext
    let agents: AgentsStore
    let chatsStore: ChatsStore
}

extension ServerAgentTrigger {
    func title(_ strings: AppStrings) -> String {
        switch self {
        case .schedule:
            strings.agentsTriggerSchedule
        case .joined:
            strings.agentsTriggerJoined
        case .keyword:
            strings.agentsTriggerKeyword
        case .webhook:
            strings.agentsTriggerWebhook
        }
    }

    var symbol: String {
        switch self {
        case .schedule:
            "clock.fill"
        case .joined:
            "person.badge.plus"
        case .keyword:
            "text.bubble.fill"
        case .webhook:
            "link"
        }
    }
}

final class AgentsController: ScreenViewController {
    private let dependencies: AgentsDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private var observation: ObservationToken?

    init(dependencies: AgentsDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .add,
            primaryAction: UIAction { [weak self] _ in
                self?.open(nil)
            }
        )
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observation = dependencies.agents.observe { [weak self] _ in
            self?.render()
        }
        dependencies.agents.refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.settingsAgents
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let rows = dependencies.agents.agents.map { agent in
            SettingsOptionItem(
                id: agent.id,
                title: agent.name,
                subtitle: "\(agent.trigger.title(strings)) · \(agent.chatTitle)",
                symbol: agent.trigger.symbol,
                iconColor: .systemIndigo,
                accessory: .toggle(agent.isEnabled),
                onSelect: { [weak self] in
                    self?.open(agent.id)
                },
                onToggle: { [weak self] isOn in
                    self?.setEnabled(agent, isOn: isOn)
                }
            )
        }
        var items = rows.positioned() as [any ListItem]
        items.append(FootnoteItem(id: "hint", text: strings.agentsHint))
        listView.apply(items: items, animated: false)
    }

    private func open(_ id: String?) {
        dependencies.agents.editingID = id
        router.open(.settingsPage(.agentEdit))
    }

    private func setEnabled(_ agent: ServerAgent, isOn: Bool) {
        var next = agent
        next.isEnabled = isOn
        let agents = dependencies.agents
        Task { [weak self] in
            do {
                try await agents.save(next)
            } catch {
                self?.showFailure()
                self?.render()
            }
        }
    }

    private func showFailure() {
        guard let window = view.window else {
            return
        }

        Toast(presentation.strings.agentsFailed).show(theme: presentation.theme, in: window)
    }
}

final class AgentRunsController: ScreenViewController {
    private let dependencies: AgentsDependencies
    private let listView = ListView(theme: ListTheme())
    private let formatter = DateFormatter()
    private var runs: [ServerAgentRun] = []

    init(dependencies: AgentsDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        guard let id = dependencies.agents.editingID else {
            return
        }

        let agents = dependencies.agents
        Task { [weak self] in
            let found = (try? await agents.runs(of: id)) ?? []
            self?.runs = found
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.agentsLog
        listView.theme = .settings(presentation.theme)
        formatter.locale = presentation.strings.pack.locale
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let rows = runs.enumerated().map { index, run in
            SettingsOptionItem(
                id: "\(index)",
                title: Self.title(of: run, strings: strings),
                detail: formatter.string(from: Date(timeIntervalSince1970: TimeInterval(run.ranAtUnixMs) / 1000)),
                symbol: run.status == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                iconColor: run.status == 0 ? .systemGreen : .systemOrange
            )
        }
        var items = rows.positioned() as [any ListItem]
        if runs.isEmpty {
            items.append(FootnoteItem(id: "empty", text: strings.agentsLogEmpty))
        }
        listView.apply(items: items, animated: false)
    }

    private static func title(of run: ServerAgentRun, strings: AppStrings) -> String {
        switch run.detail {
        case "no_rights":
            strings.agentsRunNoRights
        case "rate_limited":
            strings.agentsRunLimited
        case "empty":
            strings.agentsRunEmpty
        default:
            strings.agentsRunSent
        }
    }
}
