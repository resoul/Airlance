import AVFoundation
import Haptics
import Stories
import Subtitles
import UIKit

extension ChatCameraFlow {
    func subtitles(for item: CameraItem) -> Subtitles? {
        guard case .video(let url, _) = item else {
            return nil
        }

        return subtitles[url]
    }

    func toolTapped() {
        guard items.indices.contains(reviewIndex) else {
            return
        }

        switch items[reviewIndex] {
        case .photo(let image):
            openEditor(image)
        case .video(let url, _):
            if subtitles[url] != nil {
                openSubtitleList(for: url)
            } else {
                recognize(url, opensList: true)
            }
        }
    }

    private func openEditor(_ image: UIImage) {
        guard editor == nil else {
            return
        }

        review?.stopVideo()
        let editor = PhotoEditorView(image: image, strings: presentation.strings)
        let index = reviewIndex
        editor.onCancel = { [weak self] in
            self?.closeEditor()
        }
        editor.onDone = { [weak self] edited in
            guard let self, self.items.indices.contains(index) else {
                return
            }

            self.items[index] = .photo(edited)
            self.closeEditor()
            self.controller.setThumbnail(self.items.last?.preview, label: "\(self.items.count)")
            self.showReview(at: index)
        }
        editor.frame = controller.view.bounds
        editor.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        editor.alpha = 0
        controller.view.addSubview(editor)
        self.editor = editor
        Haptics.play(.tap)
        UIView.animate(withDuration: 0.2) {
            editor.alpha = 1
        }
    }

    private func closeEditor() {
        guard let editor else {
            return
        }

        self.editor = nil
        editor.endEditing(true)
        UIView.animate(withDuration: 0.2) {
            editor.alpha = 0
        } completion: { _ in
            editor.removeFromSuperview()
        }
    }

    private func recognize(_ url: URL, opensList: Bool) {
        let permissions = permissions
        let language = language
        subtitleTask?.cancel()
        subtitleTask = Task { [weak self] in
            guard let self, await permissions.authorize(.transcribeVoice, from: self.controller) else {
                return
            }

            self.review?.setToolLoading(true)
            let result = await self.recognizer.recognize(url, locale: Locale(identifier: language))
            self.review?.setToolLoading(false)
            guard !Task.isCancelled else {
                return
            }

            var recognized = result ?? Subtitles(phrases: [])
            if let previous = self.subtitles[url] {
                recognized.style = previous.style
                recognized.position = previous.position
            }
            self.apply(recognized, to: url)
            if opensList {
                self.openSubtitleList(for: url)
            }
        }
    }

    private func apply(_ value: Subtitles, to url: URL) {
        subtitles[url] = value
        subtitleList?.update(value, language: language)
        if items.indices.contains(reviewIndex), case .video(let current, _) = items[reviewIndex], current == url {
            review?.setTool(for: items[reviewIndex], subtitles: value)
        }
    }

    private func openSubtitleList(for url: URL) {
        guard let value = subtitles[url], subtitleList == nil else {
            return
        }

        let list = SubtitleListController(subtitles: value, language: language, strings: .app(presentation.strings))
        list.onChange = { [weak self] changed in
            self?.apply(changed, to: url)
        }
        list.onLanguage = { [weak self] language in
            self?.language = language
            self?.recognize(url, opensList: false)
        }
        list.onAdd = { [weak self] in
            self?.addPhrase(to: url)
        }
        subtitleList = list
        let navigation = UINavigationController(rootViewController: list)
        navigation.overrideUserInterfaceStyle = .dark
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        controller.present(navigation, animated: true)
    }

    private func addPhrase(to url: URL) {
        Task { [weak self] in
            let duration = (try? await AVURLAsset(url: url).load(.duration)).map(CMTimeGetSeconds) ?? 5
            guard let self, var value = self.subtitles[url] else {
                return
            }

            value.phrases = [SubtitlePhrase(words: [SubtitleWord(text: "…", start: 0, end: max(duration, 1))])]
            value.isShown = true
            self.apply(value, to: url)
            self.subtitleList?.edit(0)
        }
    }

    func burnSubtitles() async -> [CameraItem] {
        var prepared: [CameraItem] = []
        for item in items {
            guard
                case .video(let url, let poster) = item,
                let value = subtitles[url],
                value.isShown,
                !value.isEmpty
            else {
                prepared.append(item)

                continue
            }

            let aspect = await Self.orientedSize(of: url)
            let store = media
            let burned = await StoryExport.video(url, overlay: nil, subtitles: value, aspect: aspect) { ext in
                store.reserve(.video, extension: ext).url
            }
            prepared.append(.video(burned ?? url, poster: poster))
        }

        return prepared
    }

    private static func orientedSize(of url: URL) async -> CGSize {
        guard let track = try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).first,
              let natural = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else {
            return CGSize(width: 9, height: 16)
        }

        let size = natural.applying(transform)

        return CGSize(width: abs(size.width), height: abs(size.height))
    }
}
