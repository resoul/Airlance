import Device
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

    private var hasVolumeZoom: Bool {
        DeviceFeatures.volumeCaptureButtons
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            VideoNoteStyle.allCases.count
        case 1:
            1
        default:
            hasVolumeZoom ? 2 : 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            presentation.strings.videoNotesFormat
        case 2:
            presentation.strings.videoNotesCamera
        default:
            nil
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let strings = presentation.strings

        switch section {
        case 0:
            return strings.videoNotesFormatHint
        case 1:
            return strings.videoNotesReactionsHint
        default:
            return nil
        }
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
            switch (indexPath.section, indexPath.row) {
            case (1, _):
                return reactionsCell(cell)
            case (_, 0):
                return autoSubtitlesCell(cell)
            default:
                return volumeZoomCell(cell)
            }
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

        return toggleCell(cell, isOn: dependencies.settings.reactionsEnabled) { [weak self] isOn in
            self?.dependencies.settings.setReactionsEnabled(isOn)
        }
    }

    private func autoSubtitlesCell(_ cell: UITableViewCell) -> UITableViewCell {
        cell.textLabel?.text = presentation.strings.videoNotesAutoSubtitles
        cell.detailTextLabel?.text = presentation.strings.videoNotesAutoSubtitlesHint
        cell.imageView?.image = UIImage(systemName: "captions.bubble.fill")

        return toggleCell(cell, isOn: dependencies.settings.autoSubtitlesEnabled) { [weak self] isOn in
            self?.dependencies.settings.setAutoSubtitlesEnabled(isOn)
        }
    }

    private func volumeZoomCell(_ cell: UITableViewCell) -> UITableViewCell {
        cell.textLabel?.text = presentation.strings.videoNotesVolumeZoom
        cell.detailTextLabel?.text = presentation.strings.videoNotesVolumeZoomHint
        cell.imageView?.image = UIImage(systemName: "plus.forwardslash.minus")

        return toggleCell(cell, isOn: dependencies.settings.volumeZoomEnabled) { [weak self] isOn in
            self?.dependencies.settings.setVolumeZoomEnabled(isOn)
        }
    }

    private func toggleCell(
        _ cell: UITableViewCell,
        isOn: Bool,
        onChange: @escaping @MainActor (Bool) -> Void
    ) -> UITableViewCell {
        cell.selectionStyle = .none
        let toggle = UISwitch()
        toggle.onTintColor = presentation.theme.colors.accent
        toggle.isOn = isOn
        toggle.addAction(
            UIAction { [weak toggle] _ in
                onChange(toggle?.isOn ?? false)
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
