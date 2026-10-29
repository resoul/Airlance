import AirlanceUI
import ChatFolders
import Observers
import ToastUI
import UIKit

final class FoldersViewController: ScreenViewController {
    enum Slot: Equatable {
        case all
        case folder(ChatFolder)
    }

    let dependencies: FoldersDependencies
    let router: AppRouter
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    var slots: [Slot] = []

    private let headerLabel = UILabel()
    private var observations: [ObservationToken] = []

    init(dependencies: FoldersDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        headerLabel.numberOfLines = 0
        headerLabel.textAlignment = .center
        view.addSubview(tableView)
        setContentScrollView(tableView, for: .bottom)

        observations = [
            dependencies.chatFolders.observe { [weak self] _ in
                self?.reload()
            },
            dependencies.chatsStore.observe { [weak self] _ in
                self?.reload()
            },
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        let width = view.bounds.width - 64
        let size = headerLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let header = tableView.tableHeaderView ?? UIView()
        if header.frame.height != size.height + 32 {
            header.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: size.height + 32)
            headerLabel.frame = CGRect(x: 32, y: 16, width: width, height: size.height)
            header.addSubview(headerLabel)
            tableView.tableHeaderView = header
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let strings = presentation.strings

        navigationItem.title = strings.settingsFolders
        headerLabel.font = theme.fonts.subheadline
        tableView.backgroundColor = theme.colors.background
        tableView.separatorColor = theme.colors.separator
        tableView.tintColor = theme.colors.accent
        updateEditButton()
        reload()
    }

    func reload() {
        guard isViewLoaded else {
            return
        }

        let list = dependencies.chatFolders.list
        var next = list.folders.map(Slot.folder)
        next.insert(.all, at: min(list.allChatsPosition, next.count))
        slots = next
        if list.folders.isEmpty, tableView.isEditing {
            tableView.setEditing(false, animated: false)
        }
        let theme = presentation.theme
        headerLabel.text = isFailed ? presentation.strings.foldersErrorLoad : presentation.strings.foldersDescription
        headerLabel.textColor = isFailed ? theme.colors.destructive : theme.colors.textSecondary
        view.setNeedsLayout()
        updateEditButton()
        tableView.reloadData()
    }

    var isFailed: Bool {
        dependencies.chatFolders.status == .failed
    }

    func chatCount(for folder: ChatFolder) -> Int {
        dependencies.chatsStore.chats.filter { chat in
            !chat.isArchived && folder.contains(chat)
        }.count
    }

    func saveOrder() {
        var ids: [String] = []
        var allChatsPosition = 0
        for slot in slots {
            switch slot {
            case .all:
                allChatsPosition = ids.count
            case .folder(let folder):
                ids.append(folder.id)
            }
        }
        let store = dependencies.chatFolders
        let failure = presentation.strings.foldersErrorReorder

        Task { [weak self] in
            do {
                try await store.reorder(ids, allChatsPosition: allChatsPosition)
            } catch {
                self?.reload()
                self?.showError(failure)
            }
        }
    }

    func showError(_ text: String) {
        Toast(text, symbol: "exclamationmark.circle.fill", style: .error).show(theme: presentation.theme, in: view)
    }

    func confirmDelete(_ folder: ChatFolder) {
        let strings = presentation.strings
        let store = dependencies.chatFolders
        let failure = strings.foldersErrorDelete
        PopupAlert.show(
            title: strings.foldersDeleteTitle,
            message: strings.foldersDeleteMessage,
            actions: [
                PopupAlertAction(title: strings.foldersDeleteConfirm, style: .destructive) { [weak self] in
                    Task {
                        do {
                            try await store.delete(id: folder.id)
                        } catch {
                            self?.showError(failure)
                        }
                    }
                },
                PopupAlertAction(title: strings.foldersCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }

    private func updateEditButton() {
        guard !dependencies.chatFolders.list.folders.isEmpty else {
            navigationItem.rightBarButtonItem = nil

            return
        }

        let strings = presentation.strings
        let editing = tableView.isEditing
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: editing ? strings.foldersDone : strings.foldersEdit,
            primaryAction: UIAction { [weak self] _ in
                self?.toggleEditing()
            }
        )
    }

    private func toggleEditing() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        updateEditButton()
    }
}
