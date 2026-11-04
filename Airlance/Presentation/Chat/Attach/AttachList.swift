import ListUI
import UIKit

final class AttachList: UIView {
    let list = ListView(theme: ListTheme())
    let search = SearchHeaderView()
    var bottomInset: CGFloat = 0 {
        didSet {
            updateInsets()
        }
    }
    var keyboardInset: CGFloat = 0 {
        didSet {
            updateInsets()
        }
    }

    init(presentation: PresentationData, placeholder: String) {
        super.init(frame: .zero)
        let theme = presentation.theme
        list.theme = ListTheme(
            background: .clear,
            rowBackground: .clear,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.subheadline
        )
        list.scrollView.keyboardDismissMode = .onDrag
        search.apply(presentation, placeholder: placeholder)
        list.headerView = search
        list.headerHeight = SearchHeaderView.height
        addSubview(list.view)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        list.frame = bounds
    }

    private func updateInsets() {
        list.contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: max(bottomInset, keyboardInset), right: 0)
    }
}
