import AVFoundation
import Subtitles
import UIKit

extension StoryEditorView {
    var subtitles: Subtitles? {
        subtitleView.subtitles
    }

    func setUpSubtitles(isVideo: Bool) {
        subtitleButton.isHidden = !isVideo
        guard isVideo else {
            return
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        subtitleButton.setImage(UIImage(systemName: "captions.bubble", withConfiguration: configuration), for: .normal)
        subtitleButton.tintColor = .white
        subtitleButton.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        subtitleButton.accessibilityLabel = strings.subtitles
        subtitleButton.addAction(UIAction { [weak self] _ in
            self?.onSubtitles?()
        }, for: .touchUpInside)
        subtitleSpinner.color = .white
        subtitleSpinner.hidesWhenStopped = true
        subtitleButton.addSubview(subtitleSpinner)
        addSubview(subtitleButton)
        observeTime()
    }

    func observeTime() {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main
        ) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            MainActor.assumeIsolated {
                self?.subtitleView.update(time: seconds)
            }
        }
    }

    func layoutSubtitleButton() {
        subtitleButton.frame = CGRect(x: bounds.width - 60, y: closeButton.frame.minY, width: 44, height: 44)
        subtitleButton.layer.cornerRadius = 22
        subtitleSpinner.center = CGPoint(x: 22, y: 22)
    }

    func setSubtitlesLoading(_ isLoading: Bool) {
        subtitleButton.isEnabled = !isLoading
        subtitleButton.imageView?.alpha = isLoading ? 0 : 1
        if isLoading {
            subtitleSpinner.startAnimating()
        } else {
            subtitleSpinner.stopAnimating()
        }
    }

    func setSubtitles(_ subtitles: Subtitles?) {
        subtitleView.subtitles = subtitles
        let isOn = subtitles?.isShown == true && subtitles?.isEmpty == false
        let configuration = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        let symbol = isOn ? "captions.bubble.fill" : "captions.bubble"
        subtitleButton.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        subtitleButton.tintColor = isOn ? .systemYellow : .white
    }
}
