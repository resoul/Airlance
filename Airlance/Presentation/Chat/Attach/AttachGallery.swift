import Haptics
import Photos
import UIKit

final class AttachGallery: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    private static let limit = 30

    var onSelectionChange: (@MainActor (Int) -> Void)?
    var onCamera: (@MainActor () -> Void)?
    var onManage: (@MainActor () -> Void)?

    private(set) var selection: [String] = []
    private let collection: UICollectionView
    private let layout = UICollectionViewFlowLayout()
    private let limitedBar = UIView()
    private let limitedText = UILabel()
    private let manage = UIButton(type: .system)
    private var library: AttachLibrary?
    private var colors: ThemeColorsBox?

    override init(frame: CGRect) {
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = true
        collection.dataSource = self
        collection.delegate = self
        collection.register(AttachCameraCell.self, forCellWithReuseIdentifier: "camera")
        collection.register(AttachPhotoCell.self, forCellWithReuseIdentifier: "photo")
        addSubview(collection)
        limitedBar.isHidden = true
        limitedText.numberOfLines = 2
        limitedBar.addSubview(limitedText)
        manage.addAction(
            UIAction { [weak self] _ in
                self?.onManage?()
            },
            for: .touchUpInside
        )
        limitedBar.addSubview(manage)
        addSubview(limitedBar)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        let colors = presentation.theme.colors
        self.colors = ThemeColorsBox(accent: colors.accent, fill: colors.background)
        limitedBar.backgroundColor = colors.background
        limitedText.text = presentation.strings.attachLimited
        limitedText.font = presentation.theme.fonts.caption
        limitedText.textColor = colors.textSecondary
        manage.setTitle(presentation.strings.attachManage, for: .normal)
        manage.titleLabel?.font = HistoryStyle.bold(presentation.theme.fonts.caption)
        manage.tintColor = colors.accent
    }

    func show(_ library: AttachLibrary, limited: Bool) {
        self.library = library
        library.onChange = { [weak self] in
            self?.libraryChanged()
        }
        limitedBar.isHidden = !limited
        setNeedsLayout()
        collection.reloadData()
    }

    func asset(for identifier: String) -> PHAsset? {
        guard let library else {
            return nil
        }

        for index in 0..<library.count where library.identifier(at: index) == identifier {
            return library.asset(at: index)
        }

        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let barHeight: CGFloat = limitedBar.isHidden ? 0 : 44
        limitedBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 44)
        limitedText.frame = CGRect(x: 14, y: 0, width: bounds.width - 120, height: 44)
        manage.frame = CGRect(x: bounds.width - 100, y: 0, width: 90, height: 44)
        collection.frame = CGRect(x: 0, y: barHeight, width: bounds.width, height: bounds.height - barHeight)
        let side = floor((bounds.width - 4) / 3)
        if layout.itemSize.width != side {
            layout.itemSize = CGSize(width: side, height: side)
        }
    }

    private func number(of identifier: String) -> Int? {
        selection.firstIndex(of: identifier).map { index in
            index + 1
        }
    }

    private func libraryChanged() {
        guard let library else {
            return
        }

        let present = Set((0..<library.count).map(library.identifier(at:)))
        let kept = selection.filter(present.contains)
        collection.reloadData()
        if kept != selection {
            selection = kept
            onSelectionChange?(selection.count)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        1 + (library?.count ?? 0)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let reuse = indexPath.item == 0 || library == nil ? "camera" : "photo"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuse, for: indexPath)
        guard let photo = cell as? AttachPhotoCell, let library else {
            return cell
        }

        let index = indexPath.item - 1
        let identifier = library.identifier(at: index)
        photo.identifier = identifier
        photo.accent = colors?.accent ?? .systemBlue
        photo.setNumber(number(of: identifier), animated: false)
        photo.setDuration(library.duration(at: index))
        let pixelSide = layout.itemSize.width * traitCollection.displayScale
        photo.request = library.thumbnail(at: index, pixelSide: pixelSide) { [weak photo] image in
            if photo?.identifier == identifier {
                photo?.image.image = image
            }
        }
        photo.cancel = { [weak library] request in
            library?.cancel(request)
        }

        return photo
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item > 0, let library else {
            onCamera?()

            return
        }

        let identifier = library.identifier(at: indexPath.item - 1)
        if let position = selection.firstIndex(of: identifier) {
            selection.remove(at: position)
        } else {
            guard selection.count < Self.limit else {
                Haptics.play(.warning)

                return
            }

            selection.append(identifier)
        }
        Haptics.play(.selection)
        for case let cell as AttachPhotoCell in collectionView.visibleCells {
            if let identifier = cell.identifier {
                cell.setNumber(number(of: identifier), animated: true)
            }
        }
        onSelectionChange?(selection.count)
    }
}

struct ThemeColorsBox {
    let accent: UIColor
    let fill: UIColor
}
