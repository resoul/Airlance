import AVFoundation
import Subtitles
import UIKit

extension CameraReviewView {
    func setUpTool(_ strings: AppStrings) {
        toolButton.tintColor = .white
        toolButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        toolButton.addAction(UIAction { [weak self] _ in
            self?.onTool?()
        }, for: .touchUpInside)
        toolSpinner.color = .white
        toolSpinner.hidesWhenStopped = true
        toolButton.addSubview(toolSpinner)
        addSubview(toolButton)
        toolStrings = (strings.cameraEdit, strings.subtitlesTitle)
    }

    func layoutTool(top: CGFloat) {
        toolButton.frame = CGRect(x: bounds.midX - 20, y: top, width: 40, height: 40)
        toolButton.layer.cornerRadius = 20
        toolSpinner.center = CGPoint(x: 20, y: 20)
        let video = playerLayer.videoRect
        subtitleView.frame = player == nil || video.isEmpty ? bounds : video
    }

    func setTool(for item: CameraItem, subtitles: Subtitles?) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        switch item {
        case .photo:
            let image = UIImage(systemName: "pencil.tip.crop.circle", withConfiguration: configuration)
            toolButton.setImage(image, for: .normal)
            toolButton.tintColor = .white
            toolButton.accessibilityLabel = toolStrings.edit
            subtitleView.subtitles = nil
        case .video:
            let isOn = subtitles?.isShown == true && subtitles?.isEmpty == false
            let symbol = isOn ? "captions.bubble.fill" : "captions.bubble"
            toolButton.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
            toolButton.tintColor = isOn ? .systemYellow : .white
            toolButton.accessibilityLabel = toolStrings.subtitles
            subtitleView.subtitles = subtitles
        }
        setNeedsLayout()
    }

    func setToolLoading(_ isLoading: Bool) {
        toolButton.isEnabled = !isLoading
        toolButton.imageView?.alpha = isLoading ? 0 : 1
        if isLoading {
            toolSpinner.startAnimating()
        } else {
            toolSpinner.stopAnimating()
        }
    }

    func setSending(_ isSending: Bool) {
        sendButton.isEnabled = !isSending
        toolButton.isEnabled = !isSending
    }

    func observeTime() {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main
        ) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }

                let video = self.playerLayer.videoRect
                if !video.isEmpty, self.subtitleView.frame != video {
                    self.subtitleView.frame = video
                }
                self.subtitleView.update(time: seconds)
            }
        }
    }
}
