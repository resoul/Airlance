import Observers
import Permissions
import PermissionsAPI
import UIKit

struct PermissionsDependencies {
    let presentationContext: PresentationContext
    let permissionStore: PermissionStore
}

final class PermissionsViewController: ScreenViewController {
    private let dependencies: PermissionsDependencies
    private let rows: [PermissionRowView]
    private var snapshot: PermissionSnapshot
    private var permissionObservation: ObservationToken?

    init(dependencies: PermissionsDependencies) {
        let store = dependencies.permissionStore

        self.dependencies = dependencies
        snapshot = store.snapshot
        rows = store.snapshot.permissions.map { permission in
            PermissionRowView(permission: permission) { permission in
                Self.perform(permission, store: store)
            }
        }
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        setUpViews()

        permissionObservation = dependencies.permissionStore.observe { [weak self] snapshot in
            self?.snapshot = snapshot
            self?.render()
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        render()
    }

    private static func perform(_ permission: Permission, store: PermissionStore) {
        guard store.status(permission) == .notDetermined else {
            store.openSettings(for: permission)

            return
        }

        Task {
            await store.request(permission)
        }
    }

    private func setUpViews() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        setContentScrollView(scrollView, for: .bottom)

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let content = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    private func render() {
        navigationItem.title = presentation.strings.permissionsTitle

        for (permission, row) in zip(snapshot.permissions, rows) {
            row.render(status: snapshot.status(of: permission), data: presentation)
        }
    }
}
