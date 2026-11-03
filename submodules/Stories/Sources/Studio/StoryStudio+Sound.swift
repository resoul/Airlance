import AVFoundation
import Haptics
import UIKit

extension StoryStudio {
    func pickTrack() {
        trackPicker.onPick = { [weak self] url in
            self?.importTrack(url)
        }
        trackPicker.present(from: controller)
    }

    func recordVoice() {
        let context = context
        let controller = controller
        Task { [weak self] in
            guard await context.authorizeMicrophone(from: controller) else {
                return
            }

            self?.editor?.startRecording(to: context.makeFileURL(extension: "m4a"))
        }
    }

    private func importTrack(_ url: URL) {
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased()
        let target = context.makeFileURL(extension: ext)
        try? FileManager.default.removeItem(at: target)
        guard (try? FileManager.default.moveItem(at: url, to: target)) != nil else {
            Haptics.play(.error)

            return
        }

        let fallback = url.deletingPathExtension().lastPathComponent
        Task { [weak self] in
            let track = await Self.track(at: target, fallback: fallback)
            guard let track else {
                try? FileManager.default.removeItem(at: target)
                Haptics.play(.error)

                return
            }

            self?.editor?.setTrack(track)
        }
    }

    private static func track(at url: URL, fallback: String) async -> StoryTrack? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration).seconds, duration > 0.5,
              (try? await asset.loadTracks(withMediaType: .audio).first) != nil else {
            return nil
        }

        let metadata = (try? await asset.load(.commonMetadata)) ?? []
        let title = await string(metadata, .commonIdentifierTitle)
        let artist = await string(metadata, .commonIdentifierArtist)

        return StoryTrack(url: url, title: title ?? fallback, artist: artist, duration: duration)
    }

    private static func string(_ metadata: [AVMetadataItem], _ identifier: AVMetadataIdentifier) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier).first else {
            return nil
        }

        let value = try? await item.load(.stringValue)

        return value?.isEmpty == false ? value : nil
    }
}
