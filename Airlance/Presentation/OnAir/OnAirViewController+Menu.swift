import UIKit

extension OnAirViewController {
    func updateFilterItem() {
        let strings = presentation.strings
        let mine = UIAction(
            title: strings.onAirMyChannels,
            image: UIImage(systemName: "checkmark.circle"),
            state: onlyMine ? .on : .off
        ) { [weak self] _ in
            self?.onlyMine.toggle()
            self?.filtersChanged(animated: false)
        }
        let all = UIAction(title: strings.onAirFilterAll, state: category == nil ? .on : .off) { [weak self] _ in
            self?.category = nil
            self?.filtersChanged(animated: false)
        }
        let categories = OnAirCategory.allCases.map { item in
            UIAction(title: strings.onAirTitle(item), state: category == item ? .on : .off) { [weak self] _ in
                self?.category = item
                self?.filtersChanged(animated: false)
            }
        }
        let menu = UIMenu(title: strings.onAirFilter, children: [
            UIMenu(options: .displayInline, children: [mine]),
            all,
            UIMenu(options: .displayInline, children: categories),
        ] + newsMenu())
        let isFiltered = onlyMine || category != nil || (section == .news && newsOptions != OnAirNewsOptions())
        let symbol = isFiltered
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: symbol), menu: menu)
    }

    private func newsMenu() -> [UIMenuElement] {
        guard section == .news else {
            return []
        }

        let strings = presentation.strings
        let options = newsOptions
        let latest = UIAction(
            title: strings.onAirLatestOnly,
            image: UIImage(systemName: "person.2.wave.2"),
            state: options.latestOnly ? .on : .off
        ) { [weak self] _ in
            self?.newsOptions.latestOnly.toggle()
            self?.filtersChanged(animated: true)
        }
        let seen = UIAction(
            title: strings.onAirShowSeen,
            image: UIImage(systemName: "eye"),
            state: options.showsSeen ? .on : .off
        ) { [weak self] _ in
            self?.newsOptions.showsSeen.toggle()
            self?.filtersChanged(animated: true)
        }

        return [UIMenu(options: .displayInline, children: [latest, seen])]
    }
}
