import AVFoundation
import CameraUI
import Haptics
import Subtitles
import UIKit

@MainActor
public protocol StoryStudioContext: AnyObject {
    var strings: StoryStudioStrings { get }
    var subtitleStrings: SubtitleStrings { get }
    var locale: Locale { get }
    var autoSubtitles: Bool { get }
    var mentionPeers: [StoryMentionPeer] { get }

    var draftsDirectory: URL { get }

    func makeFileURL(extension ext: String) -> URL
    func authorizeTranscription(from presenter: UIViewController) async -> Bool
    func authorizeMicrophone(from presenter: UIViewController) async -> Bool
    func searchPlaces(_ query: String) async -> [StoryPlace]
    func publish(_ result: StoryResult)
}

@MainActor
public final class StoryStudio {
    public static let videoLimit: TimeInterval = 60

    public var onClose: (@MainActor () -> Void)?
    public var onPublished: (@MainActor () -> Void)?
    public var seed: StorySeed?

    let controller: CameraViewController
    let context: any StoryStudioContext
    let recognizer = SubtitleRecognizer()
    var language: String
    var media: StudioMedia?
    var draft: StoryDraft?
    var editor: StoryEditorView?
    weak var subtitleList: SubtitleListController?
    var subtitleTask: Task<Void, Never>?
    var placeTask: Task<Void, Never>?
    let trackPicker = StoryTrackPicker()
    let collageButton = UIButton(type: .system)
    var collage: StoryCollageOverlay?
    var isEditingPublished = false
    let drafts: StoryDraftStore

    public init(controller: CameraViewController, context: any StoryStudioContext) {
        self.controller = controller
        self.context = context
        drafts = StoryDraftStore(directory: context.draftsDirectory)
        language = SubtitleRecognizer.language(for: context.locale)
        controller.onCapture = { [weak self] capture in
            if self?.collage != nil {
                self?.addToCollage(capture)
            } else {
                self?.captured(capture)
            }
        }
        controller.onPick = { [weak self] captures in
            self?.picked(captures)
        }
        controller.onClose = { [weak self] in
            self?.onClose?()
        }
        setUpCollage()
        setUpDrafts()
    }

    func captured(_ capture: CameraCapture) {
        switch capture {
        case .photo(let image):
            let url = context.makeFileURL(extension: "jpg")
            try? image.jpegData(compressionQuality: 0.92)?.write(to: url)
            edit(.photo(image), draft: seeded(StoryDraft(media: .photo(url))))
        case .video(let url):
            Task { [weak self] in
                let poster = await Self.poster(of: url)
                guard let self else {
                    return
                }

                self.edit(.video(url, poster: poster), draft: self.seeded(StoryDraft(media: .video(url))))
            }
        }
    }

    func edit(_ media: StudioMedia, draft: StoryDraft) {
        self.media = media
        self.draft = draft
        let editor = StoryEditorView(media: media, strings: context.strings, draft: draft)
        editor.onClose = { [weak self] in
            self?.closeRequested()
        }
        editor.onPublish = { [weak self] audience in
            self?.publish(audience)
        }
        editor.onSubtitles = { [weak self] in
            self?.subtitlesTapped()
        }
        editor.onCutout = { [weak self] in
            self?.cutout()
        }
        editor.mentionPeers = context.mentionPeers
        editor.onPickTrack = { [weak self] in
            self?.pickTrack()
        }
        editor.onRecordVoice = { [weak self] in
            self?.recordVoice()
        }
        editor.onPlaceSearch = { [weak self] query in
            self?.searchPlaces(query)
        }
        editor.frame = controller.view.bounds
        editor.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        editor.alpha = 0
        controller.view.addSubview(editor)
        controller.isCaptureEnabled = false
        self.editor = editor
        UIView.animate(withDuration: 0.25) {
            editor.alpha = 1
        }
        if context.autoSubtitles, case .video = media {
            recognizeSubtitles(opensList: false)
        }
    }

    func closeEditor(removingFiles: Bool) {
        guard let editor else {
            return
        }

        Haptics.play(.tap)
        placeTask?.cancel()
        subtitleTask?.cancel()
        recognizer.cancel()
        if removingFiles, let draft = composedDraft() {
            StoryFiles.remove(draft.files)
        }
        editor.stopVideo()
        self.editor = nil
        media = nil
        draft = nil
        controller.isCaptureEnabled = true
        refreshDrafts()
        UIView.animate(withDuration: 0.2) {
            editor.alpha = 0
        } completion: { _ in
            editor.removeFromSuperview()
        }
    }

    private func publish(_ audience: StoryAudience) {
        guard let editor, let media, var draft else {
            return
        }

        editor.setPublishing(true)
        subtitleTask?.cancel()
        recognizer.cancel()
        draft = composedDraft() ?? draft
        draft.audience = audience
        self.draft = draft
        let overlay = editor.overlay
        let subtitles = editor.subtitles.flatMap { subtitles in
            subtitles.isShown && !subtitles.isEmpty ? subtitles : nil
        }
        Task { [weak self] in
            let result = await self?.export(media, draft: draft, overlay: overlay, subtitles: subtitles)
            self?.finish(result, draft: draft)
        }
    }

    private func export(
        _ media: StudioMedia,
        draft: StoryDraft,
        overlay: UIImage?,
        subtitles: Subtitles?
    ) async -> StoryDraft.Media? {
        let context = context
        let makeURL: @MainActor (String) -> URL = { ext in
            context.makeFileURL(extension: ext)
        }
        let options = StoryRenderOptions(draft)
        switch media {
        case .photo(let image):
            let aspect = draft.aspect
            let photo = StoryExport.photo(image, overlay: overlay, aspect: aspect, options: options, makeURL: makeURL)
            guard let photo, draft.sound.hasAudio else {
                return photo.map(StoryDraft.Media.photo)
            }

            return await StoryStill.photo(photo, sound: draft.sound, aspect: draft.aspect, makeURL: makeURL)
                .map(StoryDraft.Media.video)
        case .video(let url, _):
            return await StoryExport.video(
                url,
                overlay: overlay,
                subtitles: subtitles,
                aspect: draft.aspect,
                options: options,
                makeURL: makeURL
            )
                .map(StoryDraft.Media.video)
        }
    }

    func composedDraft() -> StoryDraft? {
        guard let editor, var draft else {
            return nil
        }

        draft.entities = editor.canvas.entities
        draft.subtitles = editor.subtitles
        draft.audience = editor.audience
        draft.aspect = editor.bounds.size
        draft.adjustments = editor.adjustments
        draft.mediaTransform = editor.mediaTransform
        draft.trim = editor.trim
        draft.coverTime = editor.coverTime
        draft.sound = editor.sound
        draft.settings = editor.settings

        return draft
    }

    private func finish(_ media: StoryDraft.Media?, draft: StoryDraft) {
        guard let media else {
            editor?.setPublishing(false)
            Haptics.play(.error)

            return
        }

        editor?.stopVideo()
        Task { [weak self] in
            guard let self else {
                return
            }

            let cover = await self.cover(for: media, draft: draft)
            self.context.publish(StoryResult(media: media, draft: draft, cover: cover))
            if self.drafts.contains(draft.id) {
                self.drafts.delete(draft.id, removingFiles: false)
            }
            Haptics.play(.success)
            self.onPublished?()
            self.controller.close(sending: true)
        }
    }

    func cover(for media: StoryDraft.Media, draft: StoryDraft) async -> URL? {
        guard case .video(let url) = media else {
            return nil
        }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        let time = max(0, draft.coverTime - (draft.trim?.start ?? 0))
        guard let image = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image,
              let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else {
            return nil
        }

        let target = context.makeFileURL(extension: "jpg")

        return (try? data.write(to: target)) == nil ? nil : target
    }

    private func cutout() {
        guard let editor, case .photo(let image) = media else {
            return
        }

        editor.setCutoutLoading(true)
        Task { [weak self, weak editor] in
            let lifted = await StoryCutout.lift(from: image)
            editor?.setCutoutLoading(false)
            guard let self, let lifted, let data = lifted.pngData() else {
                Haptics.play(.error)

                return
            }

            let target = self.context.makeFileURL(extension: "png")
            guard (try? data.write(to: target)) != nil else {
                return
            }

            editor?.canvas.addSticker(StorySticker(source: .image(target), width: 0.55))
            Haptics.play(.success)
        }
    }

    static func poster(of url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1080, height: 1920)
        let image = try? await generator.image(at: .zero).image

        return image.map(UIImage.init(cgImage:))
    }
}
