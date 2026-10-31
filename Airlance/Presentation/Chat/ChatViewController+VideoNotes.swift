import ChatHistory
import MediaStore
import UIKit

extension ChatViewController {
    func bindVideoNotes() {
        history.onVideoReaction = { [weak self] messageID, reactionID in
            self?.showVideoReaction(reactionID, messageID: messageID)
        }
    }

    func beginVideoNote(at point: CGPoint) {
        let style = Self.noteStyle(dependencies.videoNotes.style)
        let limit: TimeInterval = style == .moment ? 3 : 60
        startVideoRecorder(VideoNoteRecorderOptions(style: style, tapToStop: false, limit: limit)) { [weak self] note in
            self?.postAttachment(.videoNote(note))
        }
        recorderStart = point
    }

    func trackVideoNote(_ gesture: UILongPressGestureRecognizer, recorder: VideoNoteRecorderView) {
        switch gesture.state {
        case .changed:
            let point = gesture.location(in: view)
            recorder.drag(CGPoint(x: point.x - recorderStart.x, y: point.y - recorderStart.y))
        case .ended:
            recorder.release()
        case .cancelled, .failed:
            recorder.cancel()
        default:
            break
        }
    }

    func videoReactionItems(for message: HistoryMessage) -> [MenuItem] {
        guard dependencies.videoNotes.reactionsEnabled, canWrite, !message.content.isService else {
            return []
        }

        let item = MenuItem(
            title: presentation.strings.videoNotesReaction,
            symbol: "face.smiling.inverse",
            isDestructive: false,
            action: .run { [weak self] in
                self?.recordVideoReaction(to: message.id)
            }
        )

        return [item]
    }

    private func recordVideoReaction(to messageID: String) {
        let options = VideoNoteRecorderOptions(style: .reaction, tapToStop: true, limit: 5)
        let store = dependencies.historyStore
        let chatID = id
        startVideoRecorder(options) { note in
            store.addVideoReaction(note, to: messageID, in: chatID)
        }
    }

    private func startVideoRecorder(
        _ options: VideoNoteRecorderOptions,
        onNote: @escaping @MainActor (MessageVideoNote) -> Void
    ) {
        let strings = presentation.strings
        let flow = dependencies.permissionFlow
        guard flow.isAuthorized(.videoMessage) else {
            Task { [weak self] in
                guard let self else {
                    return
                }

                _ = await flow.authorize(.videoMessage, from: self)
            }

            return
        }

        let isDual = options.style == .dualCamera
        let stylized = options.style == .anonymous
        guard let camera = VideoNoteCamera(dual: isDual, stylized: stylized, store: dependencies.media) else {
            showRecordToast(strings.videoNotesNoCamera, symbol: "video.slash.fill")

            return
        }

        if options.style == .dualCamera, !camera.isDual {
            showRecordToast(strings.videoNotesDualUnsupported, symbol: "camera.on.rectangle")
        }
        view.endEditing(true)
        let recorder = VideoNoteRecorderView(camera: camera, options: options, host: view, presentation: presentation)
        let store = dependencies.media
        recorder.onSend = { result in
            if let note = Self.note(from: result, style: options.style, store: store) {
                onNote(note)
            }
        }
        recorder.onTooShort = { [weak self] in
            self?.showRecordToast(strings.videoNotesTooShort, symbol: "video.fill")
        }
        recorder.onFinish = { [weak self] in
            self?.inputBar.setRecording(false)
        }
        inputBar.setRecording(true)
        videoNoteRecorder = recorder
    }

    private static func note(
        from result: VideoNoteCamera.Result,
        style: MessageVideoNote.Style,
        store: MediaStore
    ) -> MessageVideoNote? {
        guard let main = store.adopt(result.main, kind: .video) else {
            return nil
        }

        return MessageVideoNote(
            source: .local(main),
            frontSource: result.front.flatMap { url in
                store.adopt(url, kind: .video).map(MediaSource.local)
            },
            duration: result.duration,
            style: style,
            levels: VideoNoteLevels.encode(result.levels)
        )
    }

    private static func noteStyle(_ style: VideoNoteStyle) -> MessageVideoNote.Style {
        switch style {
        case .blob:
            .blob
        case .dualCamera:
            .dualCamera
        case .anonymous:
            .anonymous
        case .moment:
            .moment
        }
    }

    private func showVideoReaction(_ reactionID: String, messageID: String) {
        guard let reaction = dependencies.historyStore.videoReaction(reactionID, messageID: messageID, in: id) else {
            return
        }

        let player = VideoReactionPlayerController(reaction: reaction, presentation: presentation)
        present(player, animated: true)
    }
}
