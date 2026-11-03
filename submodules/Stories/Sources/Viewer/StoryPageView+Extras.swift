import UIKit

extension StoryPageView {
    func setUpContent() {
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false
        plainHost.isUserInteractionEnabled = false
        addSubview(plainHost)
        secureField.layoutIfNeeded()
        if let canvas = secureField.subviews.first {
            canvas.isUserInteractionEnabled = false
            addSubview(canvas)
            secureCanvas = canvas
        }
        plainHost.addSubview(media)
        plainHost.addSubview(widgets)
    }

    func setUpExtras() {
        let symbol = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        moreButton.setImage(UIImage(systemName: "ellipsis", withConfiguration: symbol), for: .normal)
        moreButton.tintColor = .white
        moreButton.isHidden = true
        addSubview(moreButton)
        bottomGradient.colors = [UIColor.clear.cgColor, UIColor(white: 0, alpha: 0.55).cgColor]
        layer.insertSublayer(bottomGradient, above: (secureCanvas ?? plainHost).layer)
        captionLabel.font = .systemFont(ofSize: 15, weight: .medium)
        captionLabel.textColor = .white
        captionLabel.numberOfLines = 3
        captionLabel.textAlignment = .center
        addSubview(captionLabel)
    }

    func apply(_ item: StoryItem) {
        captionLabel.text = item.caption
        captionLabel.isHidden = item.caption.isEmpty
        bottomGradient.isHidden = item.caption.isEmpty
        moreButton.isHidden = author.peer.isSelf ? !item.isEditable : item.isProtected
        setProtected(item.isProtected)
    }

    func layoutContent() {
        secureCanvas?.frame = bounds
        plainHost.frame = bounds
        media.frame = bounds
        widgets.frame = bounds
        let width = bounds.width - 48
        let height = ceil(captionLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        let bottom = bounds.height - max(safeAreaInsets.bottom, 16) - 16
        captionLabel.frame = CGRect(x: 24, y: bottom - height, width: width, height: height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bottomGradient.frame = CGRect(x: 0, y: bottom - height - 80, width: bounds.width, height: bounds.height)
        CATransaction.commit()
    }

    private func setProtected(_ isProtected: Bool) {
        let target = isProtected ? secureCanvas ?? plainHost : plainHost
        guard media.superview !== target else {
            return
        }

        target.addSubview(media)
        target.addSubview(widgets)
        setNeedsLayout()
    }
}
