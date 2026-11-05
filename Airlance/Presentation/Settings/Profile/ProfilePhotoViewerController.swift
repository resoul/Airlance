import AirlanceUI
@preconcurrency import AsyncDisplayKit
import AvatarUI
import Haptics
import Observers
import UIKit

private final class ProfilePhotoCell: UICollectionViewCell {
    private let avatar = AvatarNode()

    override init(frame: CGRect) {
        super.init(frame: frame)
        avatar.isUserInteractionEnabled = false
        avatar.contentCornerRadius = 0
        contentView.addSubview(avatar.view)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ descriptor: AvatarDescriptor) {
        avatar.apply(descriptor, presentation: .gallery)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = bounds.width
        avatar.frame = CGRect(x: 0, y: (bounds.height - side) / 2, width: side, height: side)
    }
}

final class ProfilePhotoViewerController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    var onChoose: (@MainActor () -> Void)?

    private let store: MyProfileStore
    private let presentationData: PresentationData
    private let layout = UICollectionViewFlowLayout()
    private let collection: UICollectionView
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let titlePill = UIView()
    private let editButton = UIButton(type: .system)
    private let strip = ProfilePhotoStrip()
    private let trashButton = UIButton(type: .system)
    private let mainButton = UIButton(type: .system)
    private let dateFormatter = DateFormatter()
    private var photos: [AvatarDescriptor] = []
    private var index: Int
    private var observation: ObservationToken?

    init(store: MyProfileStore, index: Int, presentation: PresentationData) {
        self.store = store
        self.index = index
        presentationData = presentation
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        collection.backgroundColor = .clear
        collection.isPagingEnabled = true
        collection.showsHorizontalScrollIndicator = false
        collection.contentInsetAdjustmentBehavior = .never
        collection.dataSource = self
        collection.delegate = self
        collection.register(ProfilePhotoCell.self, forCellWithReuseIdentifier: "photo")
        view.addSubview(collection)
        setUpBar()
        setUpFooter()
        observation = store.observe { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds
        let safe = view.safeAreaInsets
        collection.frame = bounds
        layout.itemSize = bounds.size
        backButton.frame = CGRect(x: 16, y: safe.top + 4, width: 44, height: 44)
        editButton.frame = CGRect(x: bounds.width - 106, y: safe.top + 4, width: 90, height: 44)
        titlePill.frame = CGRect(x: 72, y: safe.top + 4, width: bounds.width - 190, height: 44)
        titleLabel.frame = CGRect(x: 8, y: 4, width: titlePill.bounds.width - 16, height: 20)
        dateLabel.frame = CGRect(x: 8, y: 24, width: titlePill.bounds.width - 16, height: 16)
        let footer = bounds.height - safe.bottom - 56
        trashButton.frame = CGRect(x: bounds.width - 60, y: footer, width: 44, height: 44)
        mainButton.frame = CGRect(x: 76, y: footer, width: bounds.width - 152, height: 44)
        strip.frame = CGRect(x: 16, y: footer - 56, width: bounds.width - 32, height: 44)
        collection.contentOffset.x = bounds.width * CGFloat(index)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        photos.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photo", for: indexPath)
        (cell as? ProfilePhotoCell)?.show(photos[indexPath.item])

        return cell
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let width = max(scrollView.bounds.width, 1)
        index = Int((scrollView.contentOffset.x / width).rounded())
        strip.setSelected(index)
        updateChrome()
    }

    private func setUpBar() {
        let strings = presentationData.strings
        let fill = UIColor(white: 1, alpha: 0.16)
        let symbol = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: symbol), for: .normal)
        backButton.tintColor = .white
        backButton.backgroundColor = fill
        backButton.layer.cornerRadius = 22
        backButton.accessibilityLabel = strings.profileBack
        backButton.addAction(
            UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            },
            for: .touchUpInside
        )
        titlePill.backgroundColor = fill
        titlePill.layer.cornerRadius = 22
        titleLabel.font = presentationData.theme.fonts.subheadline
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        dateLabel.font = presentationData.theme.fonts.caption
        dateLabel.textColor = UIColor(white: 1, alpha: 0.6)
        dateLabel.textAlignment = .center
        titlePill.addSubview(titleLabel)
        titlePill.addSubview(dateLabel)
        editButton.setTitle(strings.profileEditAction, for: .normal)
        editButton.titleLabel?.font = presentationData.theme.fonts.body
        editButton.titleLabel?.adjustsFontSizeToFitWidth = true
        editButton.tintColor = .white
        editButton.backgroundColor = fill
        editButton.layer.cornerRadius = 22
        editButton.addAction(
            UIAction { [weak self] _ in
                self?.showMenu()
            },
            for: .touchUpInside
        )
        for subview in [backButton, titlePill, editButton] as [UIView] {
            view.addSubview(subview)
        }
    }

    private func setUpFooter() {
        let strings = presentationData.strings
        dateFormatter.locale = strings.pack.locale
        dateFormatter.dateStyle = .short
        let symbol = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        trashButton.setImage(UIImage(systemName: "trash", withConfiguration: symbol), for: .normal)
        trashButton.tintColor = .white
        trashButton.backgroundColor = UIColor(white: 1, alpha: 0.16)
        trashButton.layer.cornerRadius = 22
        trashButton.accessibilityLabel = strings.profileEditRemovePhoto
        trashButton.addAction(
            UIAction { [weak self] _ in
                self?.confirmDelete()
            },
            for: .touchUpInside
        )
        mainButton.setTitle(strings.profilePhotoMakeMain, for: .normal)
        mainButton.titleLabel?.font = presentationData.theme.fonts.body
        mainButton.tintColor = .white
        mainButton.addAction(
            UIAction { [weak self] _ in
                self?.makeMain()
            },
            for: .touchUpInside
        )
        strip.showsHorizontalScrollIndicator = false
        strip.onSelect = { [weak self] position in
            self?.select(position)
        }
        for subview in [strip, mainButton, trashButton] as [UIView] {
            view.addSubview(subview)
        }
    }

    private func reload() {
        let profile = store.profile
        guard !profile.photos.isEmpty else {
            dismiss(animated: true)

            return
        }

        photos = store.gallery(for: profile)
        index = min(index, photos.count - 1)
        collection.reloadData()
        strip.show(photos, selected: index)
        view.setNeedsLayout()
        updateChrome()
    }

    private func updateChrome() {
        let items = store.profile.photos
        titleLabel.text = store.profile.fullName
        mainButton.isHidden = index == 0
        strip.isHidden = items.count < 2
        guard items.indices.contains(index) else {
            return
        }

        let added = items[index].addedAtUnix
        dateLabel.text = added > 0 ? dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(added))) : nil
    }

    private func select(_ position: Int) {
        guard photos.indices.contains(position) else {
            return
        }

        index = position
        Haptics.play(.selection)
        collection.setContentOffset(CGPoint(x: collection.bounds.width * CGFloat(position), y: 0), animated: true)
        strip.setSelected(position)
        updateChrome()
    }

    private func makeMain() {
        let items = store.profile.photos
        guard items.indices.contains(index) else {
            return
        }

        Haptics.play(.success)
        store.makeMain(items[index])
        index = 0
        reload()
    }

    private func showMenu() {
        guard let host = view.window else {
            return
        }

        let strings = presentationData.strings
        let items = [
            PopupMenuItem(title: strings.profilePhotoChoose, symbol: "photo.on.rectangle") { [weak self] in
                self?.choose()
            },
            PopupMenuItem(title: strings.profileEditRemovePhoto, symbol: "trash", isDestructive: true) { [weak self] in
                self?.confirmDelete()
            },
        ]
        let anchor = editButton.convert(editButton.bounds, to: host)
        PopupMenu.show(items, theme: presentationData.theme, from: anchor, in: host)
    }

    private func choose() {
        let onChoose = onChoose
        dismiss(animated: true) {
            onChoose?()
        }
    }

    private func confirmDelete() {
        let strings = presentationData.strings
        PopupAlert.show(
            title: nil,
            message: strings.profilePhotoDeleteConfirm,
            actions: [
                PopupAlertAction(title: strings.profileEditRemovePhoto, style: .destructive) { [weak self] in
                    self?.delete()
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentationData.theme,
            in: view
        )
    }

    private func delete() {
        let items = store.profile.photos
        guard items.indices.contains(index) else {
            return
        }

        Haptics.play(.success)
        store.removePhoto(items[index])
    }
}
