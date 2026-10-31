import Photos
import UIKit

final class AttachCameraCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        let icon = UIImageView(image: UIImage(
            systemName: "camera.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 26)
        ))
        icon.tintColor = .white
        icon.contentMode = .center
        icon.frame = contentView.bounds
        icon.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(icon)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

final class AttachPhotoCell: UICollectionViewCell {
    let image = UIImageView()
    var identifier: String?
    var request: PHImageRequestID?
    var cancel: (@MainActor (PHImageRequestID) -> Void)?
    var accent = UIColor.systemBlue

    private let mark = UILabel()
    private let duration = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(white: 0.5, alpha: 0.15)
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.frame = contentView.bounds
        image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(image)
        mark.layer.cornerRadius = 12
        mark.layer.borderWidth = 1.5
        mark.layer.borderColor = UIColor.white.cgColor
        mark.clipsToBounds = true
        mark.font = .systemFont(ofSize: 13, weight: .bold)
        mark.textColor = .white
        mark.textAlignment = .center
        contentView.addSubview(mark)
        duration.font = .systemFont(ofSize: 12, weight: .semibold)
        duration.textColor = .white
        duration.textAlignment = .right
        duration.layer.shadowColor = UIColor.black.cgColor
        duration.layer.shadowOpacity = 0.5
        duration.layer.shadowRadius = 3
        duration.layer.shadowOffset = .zero
        contentView.addSubview(duration)
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mark.frame = CGRect(x: bounds.width - 30, y: 6, width: 24, height: 24)
        duration.frame = CGRect(x: 6, y: bounds.height - 22, width: bounds.width - 12, height: 16)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if let request {
            cancel?(request)
        }
        request = nil
        identifier = nil
        image.image = nil
    }

    func setDuration(_ seconds: TimeInterval?) {
        guard let seconds else {
            duration.text = nil

            return
        }

        let total = Int(seconds.rounded())
        duration.text = String(format: "%d:%02d", total / 60, total % 60)
    }

    func setNumber(_ number: Int?, animated: Bool) {
        let text = number.map(String.init) ?? ""
        let changed = mark.text != text
        mark.text = text
        mark.backgroundColor = number == nil ? UIColor(white: 0, alpha: 0.15) : accent
        accessibilityTraits = number == nil ? [] : [.selected]
        let transform = number == nil ? .identity : CGAffineTransform(scaleX: 0.9, y: 0.9)
        guard animated else {
            image.transform = transform

            return
        }

        if changed, number != nil {
            mark.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
            self.image.transform = transform
            self.mark.transform = .identity
        }
    }
}
