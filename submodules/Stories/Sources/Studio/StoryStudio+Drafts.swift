import Haptics
import UIKit

extension StoryStudio {
    func setUpDrafts() {
        controller.onThumbnail = { [weak self] in
            self?.showDrafts()
        }
        refreshDrafts()
    }

    func refreshDrafts() {
        let latest = drafts.list().first
        controller.setThumbnail(
            latest.flatMap { entry in
                UIImage(contentsOfFile: entry.cover.path)
            },
            label: context.strings.label(.drafts)
        )
    }

    func closeRequested() {
        if isEditingPublished {
            closeEditor(removingFiles: false)
            controller.close()

            return
        }

        let strings = context.strings
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: strings.label(.saveDraft), style: .default) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveDraft()
            }
        })
        sheet.addAction(UIAlertAction(title: strings.label(.discardStory), style: .destructive) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.discardStory()
            }
        })
        sheet.addAction(UIAlertAction(title: strings.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = editor?.closeButton
        controller.present(sheet, animated: true)
    }

    func open(_ draft: StoryDraft) {
        Task { [weak self] in
            switch draft.media {
            case .photo(let url):
                guard let image = UIImage(contentsOfFile: url.path) else {
                    Haptics.play(.error)

                    return
                }

                self?.edit(.photo(image), draft: draft)
            case .video(let url):
                let poster = await Self.poster(of: url)
                self?.edit(.video(url, poster: poster), draft: draft)
            }
        }
    }

    private func saveDraft() {
        guard let draft = composedDraft() else {
            return
        }

        drafts.save(draft, cover: editor?.coverImage(width: 360))
        Haptics.play(.success)
        closeEditor(removingFiles: false)
    }

    private func discardStory() {
        if let draft, drafts.contains(draft.id) {
            drafts.delete(draft.id, removingFiles: false)
        }
        closeEditor(removingFiles: true)
    }

    private func showDrafts() {
        let entries = drafts.list()
        guard !entries.isEmpty, controller.isCaptureEnabled else {
            return
        }

        let view = StoryDraftsView(entries: entries, title: context.strings.label(.drafts))
        view.deleteTitle = context.strings.label(.discardStory)
        view.frame = controller.view.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.onClose = { [weak view] in
            view?.removeFromSuperview()
        }
        view.onOpen = { [weak self, weak view] entry in
            view?.removeFromSuperview()
            self?.open(entry.draft)
        }
        view.onDelete = { [weak self, weak view] entry in
            self?.drafts.delete(entry.draft.id, removingFiles: true)
            view?.remove(entry.draft.id)
            self?.refreshDrafts()
        }
        controller.view.addSubview(view)
    }
}
