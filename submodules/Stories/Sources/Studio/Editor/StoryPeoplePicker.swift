import Haptics
import UIKit

final class StoryPeoplePicker: UIView, UITableViewDataSource, UITableViewDelegate {
    var onDone: (@MainActor ([StoryMentionPeer]) -> Void)?

    private let peers: [StoryMentionPeer]
    private var chosen: Set<String>
    private var shown: [StoryMentionPeer]
    private let card = UIView()
    private let titleLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let search = UITextField()
    private let table = UITableView(frame: .zero, style: .plain)

    init(title: String, peers: [StoryMentionPeer], chosen: [StoryMentionPeer], strings: StoryStudioStrings) {
        self.peers = peers
        self.chosen = Set(chosen.map(\.id))
        shown = peers
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        card.backgroundColor = UIColor(white: 0.1, alpha: 1)
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(card)
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        doneButton.setTitle(strings.done, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.tintColor = .white
        doneButton.addAction(UIAction { [weak self] _ in
            self?.finish()
        }, for: .touchUpInside)
        setUpSearch(placeholder: strings.label(.searchPeople))
        table.backgroundColor = .clear
        table.separatorColor = UIColor(white: 1, alpha: 0.1)
        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .onDrag
        for view in [titleLabel, doneButton, search, table] {
            card.addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = bounds.height * 0.72
        card.frame = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
        titleLabel.frame = CGRect(x: 90, y: 12, width: bounds.width - 180, height: 32)
        doneButton.frame = CGRect(x: bounds.width - 96, y: 12, width: 84, height: 32)
        search.frame = CGRect(x: 16, y: 54, width: bounds.width - 32, height: 40)
        table.frame = CGRect(x: 0, y: 104, width: bounds.width, height: height - 104)
        table.contentInset.bottom = safeAreaInsets.bottom
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        shown.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peer") ?? UITableViewCell(
            style: .default,
            reuseIdentifier: "peer"
        )
        let peer = shown[indexPath.row]
        cell.backgroundColor = .clear
        cell.textLabel?.text = peer.name
        cell.textLabel?.textColor = .white
        cell.tintColor = .white
        cell.accessoryType = chosen.contains(peer.id) ? .checkmark : .none

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = shown[indexPath.row].id
        if chosen.contains(id) {
            chosen.remove(id)
        } else {
            chosen.insert(id)
        }
        Haptics.play(.selection)
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    private func setUpSearch(placeholder: String) {
        search.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.45)]
        )
        search.textColor = .white
        search.tintColor = .white
        search.backgroundColor = UIColor(white: 1, alpha: 0.1)
        search.layer.cornerRadius = 12
        search.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        search.leftViewMode = .always
        search.clearButtonMode = .whileEditing
        search.addAction(UIAction { [weak self] _ in
            self?.filter()
        }, for: .editingChanged)
    }

    private func filter() {
        let query = (search.text ?? "").trimmingCharacters(in: .whitespaces)
        shown = peers.filter { peer in
            query.isEmpty || peer.name.localizedCaseInsensitiveContains(query)
        }
        table.reloadData()
    }

    private func finish() {
        endEditing(true)
        onDone?(peers.filter { peer in
            chosen.contains(peer.id)
        })
    }
}
