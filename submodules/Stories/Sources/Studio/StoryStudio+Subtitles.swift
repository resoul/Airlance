import AVFoundation
import Subtitles
import UIKit

extension StoryStudio {
    func subtitlesTapped() {
        if editor?.subtitles != nil {
            openSubtitleList()
        } else {
            recognizeSubtitles(opensList: true)
        }
    }

    func recognizeSubtitles(opensList: Bool) {
        guard case .video(let url, _) = media, let editor else {
            return
        }

        let context = context
        let language = language
        subtitleTask?.cancel()
        subtitleTask = Task { [weak self, weak editor] in
            guard let self, await context.authorizeTranscription(from: self.controller) else {
                return
            }

            editor?.setSubtitlesLoading(true)
            let result = await self.recognizer.recognize(url, locale: Locale(identifier: language))
            guard !Task.isCancelled, let editor, editor === self.editor else {
                return
            }

            editor.setSubtitlesLoading(false)
            var subtitles = result ?? Subtitles(phrases: [])
            if let previous = editor.subtitles {
                subtitles.style = previous.style
                subtitles.position = previous.position
            }
            self.apply(subtitles)
            if opensList || result == nil && self.subtitleList != nil {
                self.openSubtitleList()
            }
        }
    }

    private func apply(_ subtitles: Subtitles) {
        editor?.setSubtitles(subtitles)
        subtitleList?.update(subtitles, language: language)
    }

    private func openSubtitleList() {
        guard let subtitles = editor?.subtitles else {
            return
        }
        guard subtitleList == nil else {
            subtitleList?.update(subtitles, language: language)

            return
        }

        let list = SubtitleListController(subtitles: subtitles, language: language, strings: context.subtitleStrings)
        list.onChange = { [weak self] subtitles in
            self?.editor?.setSubtitles(subtitles)
        }
        list.onLanguage = { [weak self] language in
            self?.language = language
            self?.recognizeSubtitles(opensList: false)
        }
        list.onAdd = { [weak self] in
            self?.addPhrase()
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

    private func addPhrase() {
        guard case .video(let url, _) = media else {
            return
        }

        Task { [weak self] in
            let duration = (try? await AVURLAsset(url: url).load(.duration)).map(CMTimeGetSeconds) ?? 5
            guard let self, var subtitles = self.editor?.subtitles else {
                return
            }

            let phrase = SubtitlePhrase(words: [SubtitleWord(text: "…", start: 0, end: max(duration, 1))])
            subtitles.phrases = [phrase]
            subtitles.isShown = true
            self.apply(subtitles)
            self.subtitleList?.edit(0)
        }
    }
}
