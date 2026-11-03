import MediaPlayer
import UIKit

extension AudioPlayer {
    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        command(center.playCommand) { player in
            player.resume()
        }
        command(center.pauseCommand) { player in
            player.pause()
        }
        command(center.togglePlayPauseCommand) { player in
            player.toggle()
        }
        command(center.nextTrackCommand) { player in
            player.next()
        }
        command(center.previousTrackCommand) { player in
            player.previous()
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            let time = event.positionTime
            Task { @MainActor in
                self?.seek(to: time)
            }

            return .success
        }
    }

    func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        let commands = MPRemoteCommandCenter.shared()
        guard let track = state.track else {
            center.nowPlayingInfo = nil
            commands.nextTrackCommand.isEnabled = false
            commands.previousTrackCommand.isEnabled = false

            return
        }

        commands.nextTrackCommand.isEnabled = state.hasNext
        commands.previousTrackCommand.isEnabled = true
        let rate = state.rate.rawValue
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyPlaybackDuration: state.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.position,
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? rate : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: rate,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let artist = track.artist {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                artwork
            }
        }
        center.nowPlayingInfo = info
    }

    private func command(_ command: MPRemoteCommand, _ action: @escaping @MainActor (AudioPlayer) -> Void) {
        command.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }

                action(self)
            }

            return .success
        }
    }
}
