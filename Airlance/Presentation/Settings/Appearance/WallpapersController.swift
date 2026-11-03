import Haptics
import ListUI
import Observers
import PhotosUI
import Theme
import UIKit

final class WallpapersController: ScreenViewController, UIColorPickerViewControllerDelegate,
    PHPickerViewControllerDelegate {
    static let kinds: [ChatWallpaper] = [
        .none, .aurora, .sunset, .mint, .night, .frost, .love, .holiday, .games, .school, .space,
    ]

    private let dependencies: AppearanceDependencies
    private let listView = ListView(theme: ListTheme())
    private let grid = ThemeCardsView(layout: .grid(columns: 3), aspect: 1.5)
    private var shown: [ChatWallpaper] = []
    private var observation: ObservationToken?

    init(dependencies: AppearanceDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        grid.onSelect = { [weak self] index in
            guard let self, self.shown.indices.contains(index) else {
                return
            }

            self.set(self.shown[index])
        }
        observation = dependencies.themeStore.observeSettings { [weak self] _ in
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let changed = listView.frame.width != view.bounds.width
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        if changed {
            render()
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.themeWallpapers
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded, view.bounds.width > 0 else {
            return
        }

        let strings = presentation.strings
        let theme = presentation.theme
        let chat = dependencies.themeStore.settings.chat
        shown = ([.color, .photo].contains(chat.wallpaper) ? [chat.wallpaper] : []) + Self.kinds
        let models = shown.map { kind in
            ThemeCardModel(
                wallpaper: kind.resolved(for: theme.appearance, color: chat.wallpaperColor),
                background: theme.colors.background,
                outgoing: theme.chat.outgoingColors,
                incoming: theme.colors.surface,
                caption: strings.title(for: kind)
            )
        }
        grid.apply(models, selected: shown.firstIndex(of: chat.wallpaper), theme: theme)
        var hasher = Hasher()
        hasher.combine(chat.wallpaper)
        hasher.combine(chat.wallpaperColor)
        hasher.combine(theme.appearance == .dark)
        let width = view.bounds.width - 32
        let items: [any ListItem] = [SpacerItem(id: "top", height: 8)] + actionRows().positioned() + [
            FootnoteItem(id: "hint", text: strings.themeWallpapersHint),
            SpacerItem(id: "gap", height: 12),
            ViewHostItem(
                id: "grid",
                height: grid.height(for: width, count: shown.count, captions: true),
                content: grid,
                revision: hasher.finalize()
            ),
            SpacerItem(id: "bottom", height: 24),
        ]
        listView.apply(items: items, animated: false)
    }

    private func actionRows() -> [SettingsOptionItem] {
        let strings = presentation.strings

        let color = SettingsOptionItem(
            id: "color",
            title: strings.themeWallpaperColor,
            isAction: true,
            onSelect: { [weak self] in
                self?.pickColor()
            }
        )
        let photo = SettingsOptionItem(
            id: "photo",
            title: strings.themeWallpaperPhoto,
            isAction: true,
            onSelect: { [weak self] in
                self?.pickPhoto()
            }
        )

        return [color, photo]
    }

    private func set(_ kind: ChatWallpaper, color: UInt32? = nil) {
        let store = dependencies.themeStore
        var chat = store.settings.chat
        chat.wallpaper = kind
        if let color {
            chat.wallpaperColor = color
        }
        Task {
            try? await store.setChat(chat)
        }
    }

    private func pickColor() {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = UIColor(rgb: dependencies.themeStore.settings.chat.wallpaperColor)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func pickPhoto() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        set(.color, color: viewController.selectedColor.rgb)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            let box = WallpaperImageBox(image: object as? UIImage)
            Task { @MainActor in
                self?.savePhoto(box.image)
            }
        }
    }

    private func savePhoto(_ image: UIImage?) {
        guard let image, ChatWallpaperFiles.save(image.downscaled(maxSide: 2400)) else {
            Haptics.play(.error)

            return
        }

        set(.photo, color: UInt32.random(in: 0...0xFFFFFF))
        Haptics.play(.success)
    }
}

private struct WallpaperImageBox: @unchecked Sendable {
    let image: UIImage?
}

extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        guard scale < 1 else {
            return self
        }

        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
