import ChatFolders
import UIKit

enum FolderEditorSection: Int, CaseIterable {
    case name
    case included
    case excluded
    case color
    case delete
}

enum FolderEditorEntry: Equatable {
    case add
    case category(ChatFolderCategory)
    case exclusion(ChatFolderExclusion)
    case chat(String)
}

final class FolderEditorViewController: ScreenViewController {
    let dependencies: FoldersDependencies
    let router: AppRouter
    let isNew: Bool
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    let nameCell = FolderNameCell()
    let colorCell = FolderColorCell()
    let iconView = FolderIconView()
    var draft: ChatFolder

    init(folderID: String?, dependencies: FoldersDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        if let folderID, let folder = dependencies.chatFolders.folder(id: folderID) {
            draft = folder
            isNew = false
        } else {
            draft = ChatFolder(name: "")
            isNew = true
        }
        super.init(presentationSource: dependencies.presentationContext)
    }

    var sections: [FolderEditorSection] {
        isNew ? FolderEditorSection.allCases.filter { section in
            section != .delete
        } : FolderEditorSection.allCases
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        setContentScrollView(tableView, for: .bottom)

        nameCell.field.text = draft.name
        nameCell.onNameChange = { [weak self] name in
            self?.draft.name = name
            self?.updateSave()
        }
        nameCell.onEmojiTap = { [weak self] in
            self?.pickEmoji()
        }
        colorCell.onSelect = { [weak self] color in
            self?.draft.color = color
            self?.updateStyle()
        }
        updateStyle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        if tableView.tableHeaderView == nil || tableView.tableHeaderView?.bounds.width != view.bounds.width {
            iconView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 112)
            tableView.tableHeaderView = iconView
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let strings = presentation.strings

        navigationItem.title = isNew ? strings.folderNew : strings.folderEditTitle
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            primaryAction: UIAction { [weak self] _ in
                self?.save()
            }
        )
        tableView.backgroundColor = theme.colors.background
        tableView.separatorColor = theme.colors.separator
        nameCell.apply(theme, placeholder: strings.folderName)
        colorCell.apply(theme)
        updateSave()
        tableView.reloadData()
    }

    func entries(_ section: FolderEditorSection) -> [FolderEditorEntry] {
        switch section {
        case .included:
            [.add] + ChatFolderCategory.allCases.filter(draft.categories.contains).map(FolderEditorEntry.category)
                + draft.included.sorted().map(FolderEditorEntry.chat)
        case .excluded:
            [.add] + ChatFolderExclusion.allCases.filter(draft.exclusions.contains).map(FolderEditorEntry.exclusion)
                + draft.excluded.sorted().map(FolderEditorEntry.chat)
        case .name, .color, .delete:
            []
        }
    }

    func remove(_ entry: FolderEditorEntry, from section: FolderEditorSection) {
        switch (entry, section) {
        case (.category(let category), _):
            draft.categories.remove(category)
        case (.exclusion(let exclusion), _):
            draft.exclusions.remove(exclusion)
        case (.chat(let id), .included):
            draft.included.remove(id)
        case (.chat(let id), _):
            draft.excluded.remove(id)
        case (.add, _):
            return
        }
        updateSave()
        tableView.reloadData()
    }

    func chatName(_ id: String) -> String {
        dependencies.chatsStore.chats.first { chat in
            chat.id == id
        }?.name ?? id
    }

    func updateStyle() {
        let tint = FolderStyle.color(draft.color) ?? presentation.theme.colors.accent
        nameCell.setEmoji(draft.emoji, tint: presentation.theme.colors.textSecondary)
        iconView.update(emoji: draft.emoji, tint: tint)
        colorCell.select(draft.color)
    }

    func updateSave() {
        let hasName = !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = hasName && !draft.isEmpty
    }

    private func save() {
        view.endEditing(true)
        let store = dependencies.chatFolders
        let folder = draft
        let router = router

        Task {
            try? await store.save(folder)
            router.back()
        }
    }
}
