import AVFoundation

extension AudioPlayer {
    func activateSession(then action: @escaping @MainActor () -> Void) {
        let isVoice = state.track?.kind == .voice
        Task {
            await AudioSessionQueue.perform {
                let session = AVAudioSession.sharedInstance()
                let mode: AVAudioSession.Mode = isVoice ? .spokenAudio : .default
                if session.category != .playback || session.mode != mode {
                    try? session.setCategory(.playback, mode: mode)
                }
                try? session.setActive(true)
            }
            action()
        }
    }

    func deactivateSession() {
        AudioSessionQueue.run {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func observeSession() {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            MainActor.assumeIsolated {
                self?.interrupted(type, shouldResume: shouldResume)
            }
        }
        let route = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let reason = raw.flatMap(AVAudioSession.RouteChangeReason.init)
            MainActor.assumeIsolated {
                if reason == .oldDeviceUnavailable {
                    self?.pause()
                }
            }
        }
        sessionTokens = [interruption, route]
    }

    private func interrupted(_ type: AVAudioSession.InterruptionType?, shouldResume: Bool) {
        switch type {
        case .began:
            wasInterrupted = state.isPlaying
            if state.isPlaying {
                player.pause()
                state.isPlaying = false
                changed()
            }
        case .ended:
            if wasInterrupted, shouldResume {
                resume()
            }
            wasInterrupted = false
        default:
            break
        }
    }
}
