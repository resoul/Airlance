import Haptics
import UIKit

final class FolderEmojiPickerViewController: ScreenViewController {
    var onPick: ((String?) -> Void)?

    private let collectionView: UICollectionView

    init(source: PresentationContext) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 52, height: 52)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(presentationSource: source)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FolderEmojiCell.self, forCellWithReuseIdentifier: "emoji")
        view.addSubview(collectionView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = view.bounds
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.folderIcon
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: presentation.strings.folderNoIcon,
            primaryAction: UIAction { [weak self] _ in
                self?.pick(nil)
            }
        )
        collectionView.backgroundColor = presentation.theme.colors.background
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        FolderStyle.emoji.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "emoji", for: indexPath)
        (cell as? FolderEmojiCell)?.label.text = FolderStyle.emoji[indexPath.item]
        cell.contentView.backgroundColor = presentation.theme.colors.surface

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        pick(FolderStyle.emoji[indexPath.item])
    }

    private func pick(_ emoji: String?) {
        Haptics.play(.selection)
        onPick?(emoji)
        dismiss(animated: true)
    }
}

extension FolderEmojiPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
}

final class FolderEmojiCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 28)
        label.textAlignment = .center
        contentView.layer.cornerRadius = 12
        contentView.addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }
}
