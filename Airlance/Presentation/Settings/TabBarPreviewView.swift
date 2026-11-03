import AirlanceUI
import Theme
import UIKit

final class TabBarPreviewView: UIView {
    private let capsule = UIView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        capsule.layer.cornerCurve = .continuous
        capsule.layer.cornerRadius = 30
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        addSubview(capsule)
        capsule.addSubview(stack)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capsule.frame = bounds.inset(by: UIEdgeInsets(top: 16, left: 20, bottom: 8, right: 20))
        stack.frame = capsule.bounds.insetBy(dx: 8, dy: 6)
    }

    func update(_ items: [TabBarItem], selected: Int, theme: AppTheme) {
        capsule.backgroundColor = theme.colors.surface
        stack.arrangedSubviews.forEach { view in
            view.removeFromSuperview()
        }
        for (index, item) in items.enumerated() {
            let isSelected = index == selected
            let color = isSelected ? theme.colors.accent : theme.colors.textSecondary
            stack.addArrangedSubview(itemView(item, isSelected: isSelected, color: color, theme: theme))
        }
    }

    private func itemView(_ item: TabBarItem, isSelected: Bool, color: UIColor, theme: AppTheme) -> UIView {
        let icon = UIImageView(image: (isSelected ? item.selectedImage : nil) ?? item.image)
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let label = UILabel()
        label.text = item.title
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = color
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        let column = UIStackView(arrangedSubviews: [icon, label])
        column.axis = .vertical
        column.spacing = 3
        column.alignment = .center
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true

        return column
    }
}
