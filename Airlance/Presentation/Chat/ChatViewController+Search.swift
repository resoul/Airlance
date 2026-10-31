import Haptics
import UIKit

extension ChatViewController {
    var defaultRightItems: [UIBarButtonItem] {
        let search = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            primaryAction: UIAction { [weak self] _ in
                self?.startSearch()
            }
        )
        search.accessibilityLabel = presentation.strings.chatSearch

        return [UIBarButtonItem(customView: avatarButton), search]
    }

    func bindSearch() {
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.isHidden = true
        view.addSubview(searchBar)
        history.onSearchChange = { [weak self] in
            guard let self else {
                return
            }

            self.searchBar.update(self.history.search, strings: self.presentation.strings)
        }
        let aboveKeyboard = searchBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8)
        aboveKeyboard.priority = .defaultHigh
        NSLayoutConstraint.activate([
            aboveKeyboard,
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: ChatSearchBar.height),
            searchBar.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -4
            ),
        ])
        searchField.borderStyle = .none
        searchField.layer.cornerRadius = 10
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .search
        searchField.leftView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchField.leftViewMode = .always
        searchField.addAction(
            UIAction { [weak self] _ in
                self?.searchTextChanged()
            },
            for: .editingChanged
        )
        searchBar.onOlder = { [weak self] in
            self?.moveSearch(by: -1)
        }
        searchBar.onNewer = { [weak self] in
            self?.moveSearch(by: 1)
        }
    }

    func renderSearch(_ presentation: PresentationData) {
        searchBar.apply(presentation)
        searchBar.update(history.search, strings: presentation.strings)
        let colors = presentation.theme.colors
        searchField.font = presentation.theme.fonts.body
        searchField.textColor = colors.textPrimary
        searchField.tintColor = colors.accent
        searchField.backgroundColor = colors.textPrimary.withAlphaComponent(0.08)
        searchField.leftView?.tintColor = colors.textSecondary
        searchField.attributedPlaceholder = NSAttributedString(
            string: presentation.strings.chatSearchPlaceholder,
            attributes: [.foregroundColor: colors.textSecondary]
        )
    }

    func startSearch() {
        guard !history.isSelecting, history.search == nil else {
            return
        }

        inputBar.dismissKeyboard()
        history.setSearch("")
        searchField.text = ""
        searchField.frame = CGRect(x: 0, y: 0, width: view.bounds.width - 120, height: 36)
        navigationItem.titleView = searchField
        navigationItem.hidesBackButton = true
        let cancel = UIBarButtonItem(
            title: presentation.strings.chatCancel,
            primaryAction: UIAction { [weak self] _ in
                self?.endSearch()
            }
        )
        navigationItem.rightBarButtonItems = [cancel]
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        setSearchVisible(true)
        searchField.becomeFirstResponder()
    }

    func endSearch() {
        guard history.search != nil else {
            return
        }

        searchField.resignFirstResponder()
        history.setSearch(nil)
        navigationItem.titleView = titleView
        navigationItem.hidesBackButton = false
        navigationItem.rightBarButtonItems = defaultRightItems
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        setSearchVisible(false)
    }

    private func searchTextChanged() {
        let query = searchField.text ?? ""
        searchDebounce?.cancel()
        searchDebounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled, let self, self.history.search != nil else {
                return
            }

            self.history.setSearch(query)
            self.searchBar.update(self.history.search, strings: self.presentation.strings)
        }
    }

    private func moveSearch(by step: Int) {
        if history.moveSearch(by: step) {
            Haptics.play(.selection)
        } else {
            Haptics.play(.warning)
        }
        searchBar.update(history.search, strings: presentation.strings)
    }

    private func setSearchVisible(_ isVisible: Bool) {
        searchBar.isHidden = false
        searchBar.update(history.search, strings: presentation.strings)
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.searchBar.alpha = isVisible ? 1 : 0
            for bar in [self.inputBar, self.channelBar] as [UIView] {
                bar.alpha = isVisible ? 0 : 1
            }
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.searchBar.isHidden = self.history.search == nil
        }
    }
}
