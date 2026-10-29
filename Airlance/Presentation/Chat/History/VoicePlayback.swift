import AVFoundation
import LiquidUI
import UIKit

@MainActor
final class VoicePlayback: NSObject, AVAudioPlayerDelegate {
    var onChange: (@MainActor (_ messageID: String, _ progress: CGFloat, _ isPlaying: Bool) -> Void)?

    private(set) var messageID: String?
    private var player: AVAudioPlayer?
    private lazy var driver = DisplayLinkDriver { [weak self] _ in
        self?.report()
    }

    func toggle(_ messageID: String, url: URL) {
        if messageID == self.messageID, let player {
            if player.isPlaying {
                player.pause()
                driver.stop()
            } else {
                play(player)
            }
            report()

            return
        }

        stop()
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }

        player.delegate = self
        player.prepareToPlay()
        self.player = player
        self.messageID = messageID
        play(player)
        report()
    }

    func stop() {
        guard let messageID else {
            return
        }

        player?.stop()
        player = nil
        self.messageID = nil
        driver.stop()
        onChange?(messageID, 0, false)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }

    private func play(_ player: AVAudioPlayer) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        driver.start()
    }

    private func report() {
        guard let messageID, let player else {
            return
        }

        let progress = player.duration > 0 ? CGFloat(player.currentTime / player.duration) : 0
        onChange?(messageID, progress, player.isPlaying)
    }
}
