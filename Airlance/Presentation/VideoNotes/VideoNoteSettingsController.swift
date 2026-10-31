import Observers
import UIKit

struct VideoNoteSettingsDependencies {
    let presentationContext: PresentationContext
    let settings: VideoNoteSettings
}

final class VideoNoteSettingsController: ScreenViewController, UITableViewDataSource, UITableViewDelegate {
    private let dependencies: VideoNoteSettingsDependencies
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private var observations: [ObservationToken] = []

    init(dependencies: VideoNoteSettingsDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        table.dataSource = self
        table.delegate = self
        table.frame = view.bounds
        table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(table)
        observations = dependencies.settings.observe { [weak self] in
            self?.table.reloadData()
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        title = presentation.strings.videoNotesTitle
        view.backgroundColor = presentation.theme.colors.background
        table.backgroundColor = presentation.theme.colors.background
        table.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? VideoNoteStyle.allCases.count : 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? presentation.strings.videoNotesFormat : nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let strings = presentation.strings

        return section == 0 ? strings.videoNotesFormatHint : strings.videoNotesReactionsHint
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let colors = presentation.theme.colors
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = colors.surface
        cell.textLabel?.font = presentation.theme.fonts.body
        cell.textLabel?.textColor = colors.textPrimary
        cell.detailTextLabel?.font = presentation.theme.fonts.caption
        cell.detailTextLabel?.textColor = colors.textSecondary
        cell.detailTextLabel?.numberOfLines = 0
        cell.imageView?.tintColor = colors.accent
        guard indexPath.section == 0 else {
            return reactionsCell(cell)
        }

        let style = VideoNoteStyle.allCases[indexPath.row]
        cell.textLabel?.text = style.title(presentation.strings)
        cell.detailTextLabel?.text = style.subtitle(presentation.strings)
        cell.imageView?.image = UIImage(systemName: style.symbol)
        cell.accessoryType = dependencies.settings.style == style ? .checkmark : .none
        cell.tintColor = colors.accent

        return cell
    }

    private func reactionsCell(_ cell: UITableViewCell) -> UITableViewCell {
        cell.textLabel?.text = presentation.strings.videoNotesReactions
        cell.imageView?.image = UIImage(systemName: "face.smiling.inverse")
        cell.selectionStyle = .none
        let toggle = UISwitch()
        toggle.onTintColor = presentation.theme.colors.accent
        toggle.isOn = dependencies.settings.reactionsEnabled
        toggle.addAction(
            UIAction { [weak self, weak toggle] _ in
                self?.dependencies.settings.setReactionsEnabled(toggle?.isOn ?? false)
            },
            for: .valueChanged
        )
        cell.accessoryView = toggle

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else {
            return
        }

        dependencies.settings.setStyle(VideoNoteStyle.allCases[indexPath.row])
    }
}

extension VideoNoteStyle {
    var symbol: String {
        switch self {
        case .blob:
            "drop.fill"
        case .dualCamera:
            "camera.on.rectangle.fill"
        case .anonymous:
            "theatermasks.fill"
        case .moment:
            "repeat.circle.fill"
        }
    }

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .blob:
            strings.videoNotesBlob
        case .dualCamera:
            strings.videoNotesDual
        case .anonymous:
            strings.videoNotesAnonymous
        case .moment:
            strings.videoNotesMoment
        }
    }

    func subtitle(_ strings: AppStrings) -> String {
        switch self {
        case .blob:
            strings.videoNotesBlobHint
        case .dualCamera:
            strings.videoNotesDualHint
        case .anonymous:
            strings.videoNotesAnonymousHint
        case .moment:
            strings.videoNotesMomentHint
        }
    }
}
