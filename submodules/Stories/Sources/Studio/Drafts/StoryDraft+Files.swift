import Foundation

extension StoryDraft {
    public var files: [URL] {
        var files = [media.url]
        for entity in entities {
            if case .sticker(let sticker) = entity.content, case .image(let url) = sticker.source {
                files.append(url)
            }
        }
        files += [sound.track?.url, sound.voice?.url].compactMap(\.self)

        return files
    }

    public func rebased() -> StoryDraft {
        var draft = self
        switch media {
        case .photo(let url):
            draft.media = .photo(StoryFiles.rebase(url))
        case .video(let url):
            draft.media = .video(StoryFiles.rebase(url))
        }
        draft.entities = entities.map { entity in
            guard case .sticker(var sticker) = entity.content, case .image(let url) = sticker.source else {
                return entity
            }

            var entity = entity
            sticker.source = .image(StoryFiles.rebase(url))
            entity.content = .sticker(sticker)

            return entity
        }
        if let url = sound.track?.url {
            draft.sound.track?.url = StoryFiles.rebase(url)
        }
        if let url = sound.voice?.url {
            draft.sound.voice?.url = StoryFiles.rebase(url)
        }

        return draft
    }
}

enum StoryFiles {
    static func rebase(_ url: URL) -> URL {
        guard url.isFileURL, !FileManager.default.fileExists(atPath: url.path) else {
            return url
        }

        let parts = url.pathComponents
        guard let index = parts.firstIndex(of: "Application"), parts.count > index + 2 else {
            return url
        }

        let tail = parts[(index + 2)...].joined(separator: "/")

        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(tail)
    }

    static func remove(_ urls: [URL]) {
        for url in Set(urls) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
