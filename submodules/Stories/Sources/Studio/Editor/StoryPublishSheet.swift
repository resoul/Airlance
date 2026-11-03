import Haptics
import UIKit

final class StoryPublishSheet: UIView {
    var onDone: (@MainActor (StoryAudience, StoryPublishSettings) -> Void)?

    private(set) var audience: StoryAudience
    private(set) var settings: StoryPublishSettings
    private let strings: StoryStudioStrings
    private let peers: [StoryMentionPeer]
    private let dim = UIView()
    private let card = UIView()
    private let caption = UITextField()
    private let audienceRows: [StoryAudience: StorySheetRow]
    private let peopleRow: StorySheetRow
    private let lifetime: UISegmentedControl
    private let pinRow: StorySheetRow
    private let protectRow: StorySheetRow
    private let doneButton = UIButton(type: .system)
    private let header = UILabel()
    private let lifetimeHeader = UILabel()

    init(
        audience: StoryAudience,
        settings: StoryPublishSettings,
        strings: StoryStudioStrings,
        peers: [StoryMentionPeer]
    ) {
        self.audience = audience
        self.settings = settings
        self.strings = strings
        self.peers = peers
        audienceRows = Dictionary(uniqueKeysWithValues: StoryAudience.allCases.map { option in
            (option, StorySheetRow(symbol: option.symbol, title: option.title(strings)))
        })
        peopleRow = StorySheetRow(symbol: "person.2.slash", title: "")
        lifetime = UISegmentedControl(items: StoryLifetime.allCases.map { option in
            "\(option.rawValue) " + strings.label(.hoursShort)
        })
        pinRow = StorySheetRow(symbol: "pin.fill", title: strings.label(.pinToProfile), hasToggle: true)
        protectRow = StorySheetRow(symbol: "eye.slash.fill", title: strings.label(.protectContent), hasToggle: true)
        super.init(frame: .zero)
        setUp()
        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        dim.alpha = 0
        card.transform = CGAffineTransform(translationX: 0, y: bounds.height / 2)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.dim.alpha = 1
            self.card.transform = .identity
        }
    }

    func hide() {
        endEditing(true)
        UIView.animate(withDuration: 0.22) {
            self.dim.alpha = 0
            self.card.transform = CGAffineTransform(translationX: 0, y: self.card.bounds.height)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dim.frame = bounds
        let inner = bounds.width - 40
        var y: CGFloat = 18
        caption.frame = CGRect(x: 20, y: y, width: inner, height: 44)
        y += 60
        header.frame = CGRect(x: 20, y: y, width: inner, height: 20)
        y += 26
        for option in StoryAudience.allCases {
            audienceRows[option]?.frame = CGRect(x: 20, y: y, width: inner, height: StorySheetRow.height)
            y += StorySheetRow.height
        }
        peopleRow.isHidden = audience == .closeFriends
        if !peopleRow.isHidden {
            peopleRow.frame = CGRect(x: 20, y: y, width: inner, height: StorySheetRow.height)
            y += StorySheetRow.height
        }
        y += 12
        lifetimeHeader.frame = CGRect(x: 20, y: y, width: inner, height: 20)
        lifetime.frame = CGRect(x: 20, y: y + 26, width: inner, height: 34)
        y += 74
        pinRow.frame = CGRect(x: 20, y: y, width: inner, height: StorySheetRow.height)
        protectRow.frame = CGRect(x: 20, y: y + StorySheetRow.height, width: inner, height: StorySheetRow.height)
        y += StorySheetRow.height * 2 + 14
        doneButton.frame = CGRect(x: 20, y: y, width: inner, height: 50)
        let height = doneButton.frame.maxY + max(safeAreaInsets.bottom, 16)
        card.frame = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
    }

    private func apply() {
        for (option, row) in audienceRows {
            row.isChecked = option == audience
        }
        let isSelected = audience == .selected
        let people = isSelected ? settings.selected : settings.excluded
        let names = people.map(\.name).joined(separator: ", ")
        peopleRow.setTitle(strings.label(isSelected ? .choosePeople : .exceptPeople))
        peopleRow.setDetail(people.isEmpty ? strings.label(.nobody) : names)
        lifetime.selectedSegmentIndex = StoryLifetime.allCases.firstIndex(of: settings.lifetime) ?? 2
        pinRow.toggle.isOn = settings.isPinned
        protectRow.toggle.isOn = settings.isProtected
        caption.text = settings.caption
        doneButton.isEnabled = !isSelected || !settings.selected.isEmpty
        doneButton.alpha = doneButton.isEnabled ? 1 : 0.4
        setNeedsLayout()
    }

    private func choose(_ option: StoryAudience) {
        Haptics.play(.selection)
        audience = option
        apply()
    }

    private func pickPeople() {
        let isSelected = audience == .selected
        let picker = StoryPeoplePicker(
            title: strings.label(isSelected ? .choosePeople : .exceptPeople),
            peers: peers,
            chosen: isSelected ? settings.selected : settings.excluded,
            strings: strings
        )
        picker.onDone = { [weak self, weak picker] chosen in
            if isSelected {
                self?.settings.selected = chosen
            } else {
                self?.settings.excluded = chosen
            }
            self?.apply()
            picker?.removeFromSuperview()
        }
        picker.frame = bounds
        addSubview(picker)
    }

    private func finish() {
        settings.caption = (caption.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        settings.isPinned = pinRow.toggle.isOn
        settings.isProtected = protectRow.toggle.isOn
        let index = lifetime.selectedSegmentIndex
        settings.lifetime = StoryLifetime.allCases.indices.contains(index) ? StoryLifetime.allCases[index] : .hours24
        onDone?(audience, settings)
    }
}

extension StoryPublishSheet {
    private func setUp() {
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        addSubview(dim)
        card.backgroundColor = UIColor(white: 0.1, alpha: 1)
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(card)
        setUpCaption()
        for (label, text) in [(header, strings.audience), (lifetimeHeader, strings.label(.lifetime))] {
            label.text = text.uppercased()
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.textColor = UIColor(white: 1, alpha: 0.5)
        }
        lifetime.selectedSegmentTintColor = .white
        lifetime.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        lifetime.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        doneButton.setTitle(strings.done, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.backgroundColor = .white
        doneButton.tintColor = .black
        doneButton.layer.cornerRadius = 25
        bindRows()
        let views: [UIView] = [caption, header, peopleRow, lifetimeHeader, lifetime, pinRow, protectRow, doneButton]
        for view in views + StoryAudience.allCases.compactMap({ option in
            audienceRows[option]
        }) {
            card.addSubview(view)
        }
    }

    private func setUpCaption() {
        caption.attributedPlaceholder = NSAttributedString(
            string: strings.label(.captionPlaceholder),
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.45)]
        )
        caption.textColor = .white
        caption.tintColor = .white
        caption.font = .systemFont(ofSize: 16)
        caption.backgroundColor = UIColor(white: 1, alpha: 0.1)
        caption.layer.cornerRadius = 12
        caption.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        caption.leftViewMode = .always
        caption.returnKeyType = .done
        caption.addAction(UIAction { [weak self] _ in
            self?.caption.resignFirstResponder()
        }, for: .editingDidEndOnExit)
    }

    private func bindRows() {
        for (option, row) in audienceRows {
            row.addAction(UIAction { [weak self] _ in
                self?.choose(option)
            }, for: .touchUpInside)
        }
        peopleRow.addAction(UIAction { [weak self] _ in
            self?.pickPeople()
        }, for: .touchUpInside)
        doneButton.addAction(UIAction { [weak self] _ in
            self?.finish()
        }, for: .touchUpInside)
    }

    @objc
    private func dimTapped() {
        finish()
    }
}
