import Haptics
import UIKit

final class StoryDraftsView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    var onOpen: (@MainActor (StoryDraftStore.Entry) -> Void)?
    var onDelete: (@MainActor (StoryDraftStore.Entry) -> Void)?
    var onClose: (@MainActor () -> Void)?
    var deleteTitle = ""

    private var entries: [StoryDraftStore.Entry]
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let layout = UICollectionViewFlowLayout()
    private lazy var grid = UICollectionView(frame: .zero, collectionViewLayout: layout)

    init(entries: [StoryDraftStore.Entry], title: String) {
        self.entries = entries
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.04, alpha: 0.96)
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        closeButton.tintColor = .white
        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)
        grid.backgroundColor = .clear
        grid.dataSource = self
        grid.delegate = self
        grid.register(StoryDraftCell.self, forCellWithReuseIdentifier: StoryDraftCell.identifier)
        for view in [titleLabel, closeButton, grid] {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func remove(_ id: UUID) {
        entries.removeAll { entry in
            entry.draft.id == id
        }
        grid.reloadData()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let top = max(safeAreaInsets.top, 16) + 6
        closeButton.frame = CGRect(x: 16, y: top, width: 44, height: 44)
        titleLabel.frame = CGRect(x: 70, y: top, width: bounds.width - 140, height: 44)
        grid.frame = CGRect(x: 12, y: top + 56, width: bounds.width - 24, height: bounds.height - top - 56)
        grid.contentInset.bottom = safeAreaInsets.bottom + 12
        let width = floor((grid.bounds.width - 16) / 3)
        layout.itemSize = CGSize(width: width, height: width * 16 / 9)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoryDraftCell.identifier, for: indexPath)
        (cell as? StoryDraftCell)?.image.image = UIImage(contentsOfFile: entries[indexPath.item].cover.path)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Haptics.play(.tap)
        onOpen?(entries[indexPath.item])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let index = indexPaths.first?.item, entries.indices.contains(index) else {
            return nil
        }

        let entry = entries[index]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(
                    title: self?.deleteTitle ?? "",
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { _ in
                    self?.onDelete?(entry)
                },
            ])
        }
    }
}

final class StoryDraftCell: UICollectionViewCell {
    static let identifier = "StoryDraftCell"

    let image = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.layer.cornerRadius = 10
        image.layer.cornerCurve = .continuous
        image.backgroundColor = UIColor(white: 1, alpha: 0.08)
        contentView.addSubview(image)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        image.frame = contentView.bounds
    }
}
