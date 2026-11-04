import DeviceContacts
import ListUI
import Observers
import UIKit

final class AttachContactsView: UIView {
    var onPick: (@MainActor (DeviceContact) -> Void)?
    var bottomInset: CGFloat = 0 {
        didSet {
            host.bottomInset = bottomInset
        }
    }
    var keyboardInset: CGFloat = 0 {
        didSet {
            host.keyboardInset = keyboardInset
        }
    }

    private let store: DeviceContactsStore
    private let host: AttachList
    private var query = ""
    private var observation: ObservationToken?

    init(store: DeviceContactsStore, presentation: PresentationData) {
        self.store = store
        host = AttachList(presentation: presentation, placeholder: presentation.strings.contactsSearch)
        super.init(frame: .zero)
        addSubview(host)
        host.search.onChange = { [weak self] query in
            self?.query = query
            self?.render()
        }
        observation = store.observe { [weak self] _ in
            self?.render()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func start() {
        if store.isLoaded {
            render()
        } else {
            store.reload()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        host.frame = bounds
    }

    private func render() {
        let contacts = store.contacts.filter { contact in
            !contact.phoneNumbers.isEmpty && (query.isEmpty || contact.matches(query))
        }
        let items = contacts.enumerated().map { index, contact in
            ContactRowItem(
                contact: contact,
                thumbnails: store.thumbnails,
                revision: store.revision,
                showsSeparator: index < contacts.count - 1,
                onSelect: { [weak self] in
                    self?.onPick?(contact)
                }
            )
        }
        host.list.apply(items: items, animated: false)
    }
}
