import ChatHistory
import UIKit

final class PollResultsController: UITableViewController {
    private let poll: MessagePoll
    private let presentation: PresentationData

    init(poll: MessagePoll, presentation: PresentationData) {
        self.poll = poll
        self.presentation = presentation
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = presentation.strings.pollResultsTitle
        tableView.backgroundColor = presentation.theme.colors.background
        tableView.rowHeight = 52
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        tableView.tableHeaderView = header()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        poll.options.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let option = poll.options[section]

        return option.voters.count + (hiddenCount(section) > 0 ? 1 : 0)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let option = poll.options[section]
        let percent = Int((poll.share(of: section) * 100).rounded())
        let mark = section == poll.correctOption ? "✓ " : ""

        return "\(mark)\(option.text) — \(percent)%"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let strings = presentation.strings
        let votes = poll.options[section].votes

        return strings.count(votes, one: strings.pollVotesOne, few: strings.pollVotesFew, many: strings.pollVotesMany)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let colors = presentation.theme.colors
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = colors.surface
        cell.selectionStyle = .none
        cell.textLabel?.font = presentation.theme.fonts.body
        let voters = poll.options[indexPath.section].voters
        guard voters.indices.contains(indexPath.row) else {
            cell.textLabel?.text = presentation.strings.pollMoreVoters(String(hiddenCount(indexPath.section)))
            cell.textLabel?.textColor = colors.textSecondary

            return cell
        }

        let person = voters[indexPath.row]
        cell.textLabel?.text = person.id == Reactions.me.id ? presentation.strings.chatYou : person.name
        cell.textLabel?.textColor = colors.textPrimary
        let avatar = MessageReceiptsRow.avatar(person, side: 32)
        cell.imageView?.image = avatar
        cell.imageView?.layer.cornerRadius = 16
        cell.imageView?.clipsToBounds = true

        return cell
    }

    private func hiddenCount(_ section: Int) -> Int {
        let option = poll.options[section]

        return max(0, option.votes - option.voters.count)
    }

    private func header() -> UIView {
        let label = UILabel()
        label.text = poll.question
        label.font = presentation.theme.fonts.headline
        label.textColor = presentation.theme.colors.textPrimary
        label.numberOfLines = 0
        let width = view.bounds.width - 40
        let height = ceil(label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: height + 24))
        label.frame = CGRect(x: 20, y: 16, width: width, height: height)
        label.autoresizingMask = [.flexibleWidth]
        container.addSubview(label)

        return container
    }
}
