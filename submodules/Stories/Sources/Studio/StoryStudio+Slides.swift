import AVFoundation
import CameraUI
import Haptics
import UIKit

extension StoryStudio {
    func publishSlides(_ captures: [CameraCapture]) {
        controller.isCaptureEnabled = false
        let shade = UIView(frame: controller.view.bounds)
        shade.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        shade.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.center = CGPoint(x: shade.bounds.midX, y: shade.bounds.midY)
        spinner.autoresizingMask = [
            .flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin,
        ]
        spinner.startAnimating()
        shade.addSubview(spinner)
        controller.view.addSubview(shade)
        let aspect = controller.view.bounds.size
        Task { [weak self] in
            var results: [StoryResult] = []
            for capture in captures {
                if let result = await self?.slide(capture, aspect: aspect) {
                    results.append(result)
                }
            }
            guard let self else {
                return
            }

            shade.removeFromSuperview()
            guard !results.isEmpty else {
                self.controller.isCaptureEnabled = true
                Haptics.play(.error)

                return
            }

            for result in results {
                self.context.publish(result)
            }
            Haptics.play(.success)
            self.onPublished?()
            self.controller.close(sending: true)
        }
    }

    private func slide(_ capture: CameraCapture, aspect: CGSize) async -> StoryResult? {
        let context = context
        let makeURL: @MainActor (String) -> URL = { ext in
            context.makeFileURL(extension: ext)
        }
        switch capture {
        case .photo(let image):
            guard let url = StoryExport.photo(image, overlay: nil, aspect: aspect, makeURL: makeURL) else {
                return nil
            }

            var draft = makeDraft(.photo(url))
            draft.aspect = aspect

            return StoryResult(media: .photo(url), draft: draft)
        case .video(let url):
            var draft = makeDraft(.video(url))
            draft.aspect = aspect
            let duration = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
            var options = StoryRenderOptions()
            if duration > Self.videoLimit {
                options.trim = StoryTrim(start: 0, end: Self.videoLimit)
                draft.trim = options.trim
            }
            guard let output = await StoryExport.video(
                url,
                overlay: nil,
                subtitles: nil,
                aspect: aspect,
                options: options,
                makeURL: makeURL
            ) else {
                return nil
            }

            let media = StoryDraft.Media.video(output)

            return StoryResult(media: media, draft: draft, cover: await cover(for: media, draft: draft))
        }
    }
}
