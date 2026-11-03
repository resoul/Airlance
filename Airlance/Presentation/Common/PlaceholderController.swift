import UIKit

final class PlaceholderController: ScreenViewController {
    private let symbol: String
    private let text: @MainActor (AppStrings) -> String
    private let icon = UIImageView()
    private let label = UILabel()

    init(
        presentationSource: PresentationContext,
        symbol: String,
        text: @escaping @MainActor (AppStrings) -> String
    ) {
        self.symbol = symbol
        self.text = text
        super.init(presentationSource: presentationSource)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let configuration = UIImage.SymbolConfiguration(pointSize: 44, weight: .light)
        icon.image = UIImage(systemName: symbol, withConfiguration: configuration)
        icon.contentMode = .center
        label.numberOfLines = 0
        label.textAlignment = .center
        view.addSubview(icon)
        view.addSubview(label)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = min(view.bounds.width - 64, 320)
        let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        icon.frame = CGRect(x: view.bounds.midX - 40, y: view.bounds.midY - 70, width: 80, height: 60)
        label.frame = CGRect(
            x: view.bounds.midX - width / 2,
            y: icon.frame.maxY + 12,
            width: width,
            height: size.height
        )
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let colors = presentation.theme.colors
        view.backgroundColor = colors.background
        icon.tintColor = colors.textSecondary
        label.text = text(presentation.strings)
        label.font = presentation.theme.fonts.body
        label.textColor = colors.textSecondary
        view.setNeedsLayout()
    }
}
