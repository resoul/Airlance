import AirlanceUI
@preconcurrency import AsyncDisplayKit
import ListUI
import Observers
import UIKit

struct CallsDependencies {
    let presentationContext: PresentationContext
    let callsStore: CallsStore
    let storiesStore: StoriesStore
}

final class CallsViewController: ScreenViewController {
    private enum Filter: Int {
        case all
        case missed
    }

    private let dependencies: CallsDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private let filterControl = UISegmentedControl(items: ["", ""])
    private let emptyLabel = UILabel()
    private var filter = Filter.all
    private var isEditingCalls = false
    private var dateFormatter = ListDateFormatter(locale: .current)
    private var observations: [ObservationToken] = []

    init(dependencies: CallsDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        filterControl.selectedSegmentIndex = Filter.all.rawValue
        filterControl.addAction(
            UIAction { [weak self] _ in
                self?.filterChanged()
            },
            for: .valueChanged
        )
        navigationItem.titleView = filterControl

        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)

        observations = [
            dependencies.callsStore.observe { [weak self] _ in
                self?.render()
            },
            dependencies.storiesStore.observe { [weak self] _ in
                self?.render(animated: false)
            },
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        emptyLabel.frame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 24, dy: 0)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let strings = presentation.strings

        dateFormatter = ListDateFormatter(locale: strings.pack.locale)
        filterControl.setTitle(strings.callsAll, forSegmentAt: Filter.all.rawValue)
        filterControl.setTitle(strings.callsMissed, forSegmentAt: Filter.missed.rawValue)
        filterControl.selectedSegmentTintColor = theme.colors.surface
        filterControl.setTitleTextAttributes(
            [.font: theme.fonts.subheadline, .foregroundColor: theme.colors.textPrimary],
            for: .normal
        )
        listView.theme = ListTheme(
            background: theme.colors.background,
            rowBackground: theme.colors.background,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.subheadline
        )
        emptyLabel.font = theme.fonts.body
        emptyLabel.textColor = theme.colors.textSecondary
        render(animated: false)
    }

    private func filterChanged() {
        filter = Filter(rawValue: filterControl.selectedSegmentIndex) ?? .all
        render()
    }

    private func setEditing(_ editing: Bool) {
        isEditingCalls = editing
        render()
    }

    private func confirmDeleteAll() {
        let strings = presentation.strings
        PopupAlert.show(
            title: nil,
            message: strings.callsDeleteAllConfirm,
            actions: [
                PopupAlertAction(title: strings.callsDeleteAll, style: .destructive) { [weak self] in
                    self?.dependencies.callsStore.deleteAll()
                    self?.setEditing(false)
                },
                PopupAlertAction(title: strings.callsCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }

    private func render(animated: Bool = true) {
        guard isViewLoaded else {
            return
        }

        let entries = dependencies.callsStore.entries
        let visible = filter == .missed ? entries.filter(\.isMissed) : entries
        if entries.isEmpty, isEditingCalls {
            isEditingCalls = false
        }

        listView.apply(items: items(for: visible), animated: animated)
        updateBarItems(hasEntries: !entries.isEmpty)

        let strings = presentation.strings
        emptyLabel.text = filter == .missed ? strings.callsEmptyMissed : strings.callsEmpty
        emptyLabel.isHidden = !visible.isEmpty
    }

    private func items(for entries: [CallEntry]) -> [any ListItem] {
        let strings = presentation.strings
        let now = Date()
        let store = dependencies.callsStore
        let stories = dependencies.storiesStore
        let rows: [any ListItem] = entries.enumerated().map { index, entry in
            CallRowItem(
                entry: entry,
                subtitle: strings.subtitle(for: entry),
                dateText: dateFormatter.string(for: entry.date, now: now),
                isEditing: isEditingCalls,
                showsSeparator: index < entries.count - 1,
                story: stories.story(for: entry.peerID),
                onDelete: {
                    store.delete(entry.id)
                },
                onInfo: {
                }
            )
        }
        guard filter == .all, !entries.isEmpty else {
            return rows
        }

        let newCall = ActionRowItem(
            id: "newCall",
            title: strings.callsNewCall,
            symbol: "phone.badge.plus"
        ) { [router] in
            router.selectTab(.contacts)
        }

        return [newCall, SectionHeaderItem(id: "recent", title: strings.callsRecent)] + rows
    }

    private func updateBarItems(hasEntries: Bool) {
        let strings = presentation.strings
        if isEditingCalls {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                systemItem: .done,
                primaryAction: UIAction { [weak self] _ in
                    self?.setEditing(false)
                }
            )
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: strings.callsDeleteAll,
                primaryAction: UIAction { [weak self] _ in
                    self?.confirmDeleteAll()
                }
            )

            return
        }

        let edit = UIBarButtonItem(
            title: strings.callsEdit,
            primaryAction: UIAction { [weak self] _ in
                self?.setEditing(true)
            }
        )
        edit.isEnabled = hasEntries
        navigationItem.leftBarButtonItem = edit
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "phone.badge.plus"),
            primaryAction: UIAction { [router] _ in
                router.selectTab(.contacts)
            }
        )
    }
}
