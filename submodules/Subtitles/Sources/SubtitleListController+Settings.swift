import UIKit

extension SubtitleListController {
    func settingCell(_ cell: UITableViewCell, row: Int) -> UITableViewCell {
        switch row {
        case 0:
            cell.textLabel?.text = strings.show
            let toggle = UISwitch()
            toggle.isOn = subtitles.isShown
            toggle.addAction(UIAction { [weak self, weak toggle] _ in
                self?.change { subtitles in
                    subtitles.isShown = toggle?.isOn ?? false
                }
            }, for: .valueChanged)
            cell.accessoryView = toggle
        case 1:
            cell.textLabel?.text = strings.language
            cell.accessoryView = languageButton()
        default:
            cell.textLabel?.text = strings.style
            cell.accessoryView = styleControl()
        }

        return cell
    }

    private func languageButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(Self.name(of: language) + " ▾", for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: SubtitleRecognizer.languages.map { identifier in
            UIAction(title: Self.name(of: identifier), state: identifier == language ? .on : .off) { [weak self] _ in
                self?.onLanguage?(identifier)
            }
        })
        button.sizeToFit()

        return button
    }

    private func styleControl() -> UISegmentedControl {
        let titles = SubtitleStyle.allCases.map { style in
            style.title(strings)
        }
        let control = UISegmentedControl(items: titles)
        control.selectedSegmentIndex = SubtitleStyle.allCases.firstIndex(of: subtitles.style) ?? 0
        control.addAction(UIAction { [weak self, weak control] _ in
            let index = control?.selectedSegmentIndex ?? 0
            self?.change { subtitles in
                subtitles.style = SubtitleStyle.allCases[index]
            }
        }, for: .valueChanged)
        control.sizeToFit()

        return control
    }

    private func change(_ update: (inout Subtitles) -> Void) {
        var next = subtitles
        update(&next)
        self.update(next, language: language)
        onChange?(next)
    }

    static func name(of identifier: String) -> String {
        let locale = Locale(identifier: identifier)

        return (locale.localizedString(forIdentifier: identifier) ?? identifier).capitalized(with: locale)
    }
}

extension SubtitleStyle {
    func title(_ strings: SubtitleStrings) -> String {
        switch self {
        case .shadow:
            strings.styleShadow
        case .plate:
            strings.stylePlate
        case .pop:
            strings.stylePop
        }
    }
}
