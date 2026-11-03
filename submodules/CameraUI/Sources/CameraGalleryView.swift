import Haptics
import UIKit

final class CameraGalleryView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    private static let columns: CGFloat = 4
    private static let spacing: CGFloat = 2
    private static let headerHeight: CGFloat = 52

    var onPick: (@MainActor ([Int]) -> Void)?
    var onClose: (@MainActor () -> Void)?

    private let gallery: any CameraGallery
    private let limit: Int
    private let dim = UIView()
    private let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
    private let header = UIView()
    private let grabber = UIView()
    private let titleLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let layout = UICollectionViewFlowLayout()
    private lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private var selected: [String] = []
    private var doneTitle = ""

    init(gallery: any CameraGallery, strings: CameraStrings, limit: Int) {
        self.gallery = gallery
        self.limit = limit
        super.init(frame: .zero)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        addSubview(dim)
        panel.clipsToBounds = true
        panel.layer.cornerRadius = 22
        panel.layer.cornerCurve = .continuous
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(panel)
        setUpHeader(strings)
        layout.minimumInteritemSpacing = Self.spacing
        layout.minimumLineSpacing = Self.spacing
        collection.backgroundColor = .clear
        collection.dataSource = self
        collection.delegate = self
        collection.register(CameraGalleryCell.self, forCellWithReuseIdentifier: CameraGalleryCell.identifier)
        panel.contentView.addSubview(collection)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setUpHeader(_ strings: CameraStrings) {
        grabber.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        grabber.layer.cornerRadius = 2.5
        titleLabel.text = strings.gallery
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        doneButton.setTitle(strings.galleryDone, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        doneButton.tintColor = .systemYellow
        doneButton.isHidden = true
        doneButton.addAction(UIAction { [weak self] _ in
            self?.done()
        }, for: .touchUpInside)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        for view in [grabber, titleLabel, doneButton, spinner] {
            header.addSubview(view)
        }
        header.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        panel.contentView.addSubview(header)
        doneTitle = strings.galleryDone
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dim.frame = bounds
        let height = bounds.height * 0.72
        panel.frame = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
        header.frame = CGRect(x: 0, y: 0, width: bounds.width, height: Self.headerHeight)
        grabber.frame = CGRect(x: bounds.width / 2 - 18, y: 8, width: 36, height: 5)
        titleLabel.frame = CGRect(x: 18, y: 16, width: bounds.width / 2, height: 28)
        doneButton.frame = CGRect(x: bounds.width - 150, y: 14, width: 134, height: 32)
        doneButton.contentHorizontalAlignment = .right
        spinner.center = CGPoint(x: bounds.width - 30, y: 30)
        collection.frame = CGRect(
            x: 0,
            y: Self.headerHeight,
            width: bounds.width,
            height: height - Self.headerHeight
        )
        collection.contentInset.bottom = safeAreaInsets.bottom
        let side = floor((bounds.width - Self.spacing * (Self.columns - 1)) / Self.columns)
        layout.itemSize = CGSize(width: side, height: side)
    }

    func show() {
        dim.alpha = 0
        panel.transform = CGAffineTransform(translationX: 0, y: bounds.height)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0) {
            self.dim.alpha = 1
            self.panel.transform = .identity
        }
    }

    func hide(completion: @escaping @MainActor () -> Void) {
        UIView.animate(withDuration: 0.25) {
            self.dim.alpha = 0
            self.panel.transform = CGAffineTransform(translationX: 0, y: self.panel.bounds.height)
        } completion: { _ in
            completion()
        }
    }

    func reload() {
        collection.reloadData()
    }

    func setLoading(_ isLoading: Bool) {
        isLoading ? spinner.startAnimating() : spinner.stopAnimating()
        doneButton.alpha = isLoading ? 0 : 1
        collection.isUserInteractionEnabled = !isLoading
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        gallery.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraGalleryCell.identifier, for: indexPath)
        guard let cell = cell as? CameraGalleryCell else {
            return cell
        }

        let identifier = gallery.identifier(at: indexPath.item)
        let number = selected.firstIndex(of: identifier).map { index in
            index + 1
        }
        cell.configure(
            identifier: identifier,
            duration: gallery.duration(at: indexPath.item),
            number: number,
            isMultiple: limit > 1
        )
        let side = layout.itemSize.width * max(traitCollection.displayScale, 1)
        gallery.thumbnail(at: indexPath.item, side: side) { [weak cell] image in
            cell?.setImage(image, for: identifier)
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Haptics.play(.selection)
        guard limit > 1 else {
            onPick?([indexPath.item])

            return
        }

        let identifier = gallery.identifier(at: indexPath.item)
        if let index = selected.firstIndex(of: identifier) {
            selected.remove(at: index)
        } else if selected.count < limit {
            selected.append(identifier)
        }
        doneButton.isHidden = selected.isEmpty
        doneButton.setTitle(selected.isEmpty ? doneTitle : "\(doneTitle) (\(selected.count))", for: .normal)
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    private func done() {
        let indices = selected.compactMap { identifier in
            (0..<gallery.count).first { index in
                gallery.identifier(at: index) == identifier
            }
        }
        onPick?(indices)
    }

    @objc
    private func dimTapped() {
        onClose?()
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        let translation = max(0, gesture.translation(in: self).y)
        switch gesture.state {
        case .changed:
            panel.transform = CGAffineTransform(translationX: 0, y: translation)
        case .ended, .cancelled:
            if translation > 120 || gesture.velocity(in: self).y > 900 {
                onClose?()
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.panel.transform = .identity
                }
            }
        default:
            break
        }
    }
}

final class CameraGalleryCell: UICollectionViewCell {
    static let identifier = "CameraGalleryCell"

    private let imageView = UIImageView()
    private let durationLabel = UILabel()
    private let badge = UILabel()
    private var assetID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        durationLabel.textColor = .white
        durationLabel.textAlignment = .right
        durationLabel.shadowColor = UIColor.black.withAlphaComponent(0.6)
        durationLabel.shadowOffset = CGSize(width: 0, height: 1)
        badge.font = .systemFont(ofSize: 13, weight: .bold)
        badge.textAlignment = .center
        badge.clipsToBounds = true
        badge.layer.cornerRadius = 11
        badge.layer.borderWidth = 1.5
        badge.layer.borderColor = UIColor.white.cgColor
        for view in [imageView, durationLabel, badge] {
            contentView.addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(identifier: String, duration: TimeInterval?, number: Int?, isMultiple: Bool) {
        if assetID != identifier {
            imageView.image = nil
        }
        assetID = identifier
        durationLabel.text = duration.map { duration in
            let seconds = Int(duration.rounded())

            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        badge.isHidden = !isMultiple
        badge.text = number.map(String.init)
        badge.backgroundColor = number == nil ? UIColor.black.withAlphaComponent(0.2) : .systemYellow
        badge.textColor = .black
        imageView.alpha = number == nil ? 1 : 0.75
    }

    func setImage(_ image: UIImage?, for identifier: String) {
        guard identifier == assetID else {
            return
        }

        imageView.image = image
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
        durationLabel.frame = CGRect(x: 4, y: bounds.height - 20, width: bounds.width - 8, height: 16)
        badge.frame = CGRect(x: bounds.width - 28, y: 6, width: 22, height: 22)
    }
}
