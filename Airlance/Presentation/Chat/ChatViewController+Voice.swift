import ChatHistory
import ToastUI
import UIKit

extension ChatViewController {
    func bindVoice() {
        inputBar.onHold = { [weak self] gesture in
            self?.recordGesture(gesture)
        }
    }

    private func recordGesture(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state != .began, let videoRecorder = videoNoteRecorder {
            trackVideoNote(gesture, recorder: videoRecorder)

            return
        }

        switch gesture.state {
        case .began:
            beginRecording(gesture)
        case .changed:
            let point = gesture.location(in: view)
            recorder?.drag(CGPoint(x: point.x - recorderStart.x, y: point.y - recorderStart.y))
        case .ended:
            recorder?.release()
        case .cancelled, .failed:
            recorder?.cancel()
        default:
            break
        }
    }

    private func beginRecording(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: view)
        guard !inputBar.isVideoMessage else {
            beginVideoNote(at: point)

            return
        }

        let flow = dependencies.permissionFlow
        guard flow.isAuthorized(.voiceMessage) else {
            Task { [weak self] in
                guard let self else {
                    return
                }

                _ = await flow.authorize(.voiceMessage, from: self)
            }

            return
        }

        let store = dependencies.media
        Task { [weak self] in
            let recording = await VoiceRecording.start(store: store)
            guard let self, let recording else {
                return
            }

            guard gesture.state == .began || gesture.state == .changed else {
                recording.cancel()
                self.showRecordToast(self.presentation.strings.chatHoldToRecord, symbol: "mic.fill")

                return
            }

            self.showRecorder(recording, at: point)
        }
    }

    private func showRecorder(_ recording: VoiceRecording, at point: CGPoint) {
        let strings = presentation.strings
        view.endEditing(true)
        let recorder = VoiceRecorderView(
            recording: recording,
            host: view,
            buttonCenter: inputBar.convert(inputBar.actionCenter, to: view),
            bar: inputBar.frame,
            texts: VoiceRecorderTexts(slideHint: strings.chatRecordSlide, cancel: strings.chatCancel),
            theme: presentation.theme
        )
        recorder.onSend = { [weak self] voice in
            self?.sendVoice(voice)
        }
        recorder.onTooShort = { [weak self] in
            self?.showRecordToast(strings.chatHoldToRecord, symbol: "mic.fill")
        }
        recorder.onFinish = { [weak self] in
            self?.inputBar.setRecording(false)
        }
        inputBar.setRecording(true)
        self.recorder = recorder
        recorderStart = point
    }

    func showRecordToast(_ text: String, symbol: String) {
        Toast(text, symbol: symbol).show(theme: presentation.theme, in: view)
    }
}
