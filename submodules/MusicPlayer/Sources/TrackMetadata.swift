import AVFoundation

public struct TrackMetadata: Sendable {
    public var title: String?
    public var artist: String?
    public var artwork: Data?
    public var duration: TimeInterval = 0

    public static func load(_ url: URL) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        var metadata = TrackMetadata()
        if let duration = try? await asset.load(.duration).seconds, duration.isFinite {
            metadata.duration = duration
        }
        guard let items = try? await asset.load(.commonMetadata) else {
            return metadata
        }

        metadata.title = await string(.commonIdentifierTitle, in: items)
        metadata.artist = await string(.commonIdentifierArtist, in: items)
        let artwork = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork).first
        metadata.artwork = try? await artwork?.load(.dataValue)

        return metadata
    }

    private static func string(_ identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> String? {
        let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first
        let value = try? await item?.load(.stringValue)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return trimmed.isEmpty ? nil : trimmed
    }
}
