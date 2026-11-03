import Haptics
import UIKit

extension StoryEditorView {
    func showWidgetForm(_ type: StoryWidgetType) {
        guard widgetForm == nil else {
            return
        }

        let form = StoryWidgetForm(type: type, strings: strings, peers: mentionPeers)
        form.onDone = { [weak self] widget in
            self?.canvas.addWidget(widget)
            self?.hideWidgetForm()
        }
        form.onCancel = { [weak self] in
            self?.hideWidgetForm()
        }
        form.onSearch = { [weak self] query in
            self?.onPlaceSearch?(query)
        }
        form.frame = bounds
        addSubview(form)
        widgetForm = form
        form.layoutIfNeeded()
        form.begin()
    }

    func setPlaces(_ places: [StoryPlace], for query: String) {
        widgetForm?.setPlaces(places, for: query)
    }

    func setDragging(_ isDragging: Bool) {
        let tools = [
            textButton, drawButton, stickerButton, adjustButton, soundButton, extraButton, closeButton, audienceButton,
            publishButton, subtitleButton,
        ]
        UIView.animate(withDuration: 0.2) {
            for view in tools {
                view.alpha = isDragging ? 0 : 1
            }
        }
    }

    private func hideWidgetForm() {
        widgetForm?.dismiss()
        widgetForm = nil
    }
}

extension StoryEditorView {
    func showPublishSheet() {
        guard publishSheet == nil else {
            return
        }

        let sheet = StoryPublishSheet(audience: audience, settings: settings, strings: strings, peers: mentionPeers)
        sheet.onDone = { [weak self] audience, settings in
            self?.settings = settings
            self?.setAudience(audience)
            self?.publishSheet?.hide()
            self?.publishSheet = nil
        }
        sheet.frame = bounds
        addSubview(sheet)
        publishSheet = sheet
        sheet.layoutIfNeeded()
        sheet.show()
    }
}
