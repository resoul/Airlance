import ChatHistory
import ChatStorage
import Foundation
import MediaStore

extension ChatHistoryStore {
    func serverAttachments(of message: HistoryMessage) -> [StoredAttachment]? {
        switch message.content {
        case .text:
            return []
        case .photos(let photos, _):
            let items = photos.compactMap(Self.attachment(of:))

            return items.count == photos.count ? items : nil
        case .voice(let voice):
            return Self.single(.voice, voice.source, durationMs: Int(voice.duration * 1000), waveform: voice.waveform)
        case .videoNote(let note):
            return Self.single(.videoNote, note.source, durationMs: Int(note.duration * 1000), waveform: note.levels)
        case .file(let file, _):
            return Self.local(file.source).map { media in
                let item = StoredAttachment(
                    kind: file.isAudio ? .music : .file,
                    localKind: media.kind.rawValue,
                    localName: media.name,
                    name: file.name,
                    size: file.size
                )

                return [item]
            }
        case .location, .service, .poll, .contact:
            return nil
        }
    }

    private static func single(
        _ kind: StoredAttachmentKind,
        _ source: MediaSource,
        durationMs: Int,
        waveform: [UInt8]
    ) -> [StoredAttachment]? {
        local(source).map { media in
            let item = StoredAttachment(
                kind: kind,
                localKind: media.kind.rawValue,
                localName: media.name,
                durationMs: durationMs,
                waveform: waveform
            )

            return [item]
        }
    }

    private static func attachment(of photo: MessagePhoto) -> StoredAttachment? {
        guard let image = local(photo.source) else {
            return nil
        }

        if let video = photo.video {
            guard let media = local(video.source) else {
                return nil
            }

            return StoredAttachment(
                kind: .video,
                localKind: media.kind.rawValue,
                localName: media.name,
                thumbLocalName: image.name,
                width: photo.width,
                height: photo.height,
                durationMs: Int(video.duration * 1000)
            )
        }

        return StoredAttachment(
            kind: .photo,
            localKind: image.kind.rawValue,
            localName: image.name,
            thumbLocalName: image.name,
            width: photo.width,
            height: photo.height
        )
    }

    private static func local(_ source: MediaSource) -> LocalMedia? {
        guard case .local(let media) = source else {
            return nil
        }

        return media
    }

    func content(of stored: StoredMessage) -> MessageContent {
        guard let server, let first = stored.attachments.first else {
            return .text(stored.text)
        }

        let account = server.account
        switch first.kind {
        case .photo, .video:
            return .photos(stored.attachments.map { item in
                Self.photo(item, account: account)
            }, caption: stored.text)
        case .voice:
            let voice = MessageVoice(
                source: .local(first.localMedia(account: account)),
                duration: TimeInterval(first.durationMs) / 1000,
                waveform: first.waveform
            )

            return .voice(voice)
        case .videoNote:
            return .videoNote(MessageVideoNote(
                source: .local(first.localMedia(account: account)),
                duration: TimeInterval(first.durationMs) / 1000,
                style: .blob,
                levels: first.waveform
            ))
        case .file, .music:
            let media = first.localMedia(account: account)
            let file = MessageFile(
                name: first.name,
                size: first.size,
                source: .local(media),
                isDownloaded: Self.exists(media)
            )

            return .file(file, caption: stored.text)
        }
    }

    private static func photo(_ item: StoredAttachment, account: String) -> MessagePhoto {
        let media = item.localMedia(account: account)
        let poster = item.thumbMedia(account: account)
        let isVideo = item.kind == .video
        let shown = isVideo ? poster ?? media : media
        let video = isVideo ? MessageVideo(source: .local(media), duration: TimeInterval(item.durationMs) / 1000) : nil

        return MessagePhoto(
            id: item.mediaID.isEmpty ? item.localName : item.mediaID,
            width: item.width,
            height: item.height,
            source: .local(shown),
            video: video,
            size: item.size,
            isDownloaded: exists(media)
        )
    }

    private static func exists(_ media: LocalMedia) -> Bool {
        FileManager.default.fileExists(atPath: MediaStore.url(for: media).path)
    }

    func fetchMissingMedia(_ stored: StoredMessage) {
        guard let server, let fetcher = serverMediaFetcher else {
            return
        }

        let id = stored.sender == server.me ? stored.clientID : "\(stored.sender):\(stored.clientID)"
        serverAttachmentsByMessage[id] = stored.attachments
        for item in stored.attachments {
            if let thumb = item.thumbMedia(account: server.account), !item.thumbMediaID.isEmpty {
                fetcher.fetch(item.thumbMediaID, to: thumb) { [weak self] in
                    self?.changed(stored.chatID)
                }
            }
            guard item.fetchesItself else {
                continue
            }

            fetcher.fetch(item.mediaID, to: item.localMedia(account: server.account)) { [weak self] in
                self?.markServerMediaReady(id, in: stored.chatID)
            }
        }
    }

    func downloadServerMedia(_ messageID: String, in id: String) -> Bool {
        guard let server, let fetcher = serverMediaFetcher, let items = serverAttachmentsByMessage[messageID] else {
            return false
        }

        for item in items {
            fetcher.fetch(item.mediaID, to: item.localMedia(account: server.account)) { [weak self] in
                self?.markServerMediaReady(messageID, in: id)
            }
        }

        return true
    }

    private func markServerMediaReady(_ messageID: String, in id: String) {
        markDownloaded(messageID, in: id)
        changed(id)
    }
}

extension StoredAttachment {
    func localMedia(account: String) -> LocalMedia {
        let kind = LocalMedia.Kind(rawValue: localKind) ?? defaultLocalKind
        let name = localName.isEmpty ? mediaID + "." + fileExtension : localName

        return LocalMedia(account: account, kind: kind, name: name)
    }

    func thumbMedia(account: String) -> LocalMedia? {
        if !thumbLocalName.isEmpty {
            return LocalMedia(account: account, kind: .image, name: thumbLocalName)
        }

        return thumbMediaID.isEmpty ? nil : LocalMedia(account: account, kind: .image, name: thumbMediaID + ".jpg")
    }

    var fetchesItself: Bool {
        switch kind {
        case .photo, .voice, .videoNote:
            !mediaID.isEmpty
        case .video, .file, .music:
            false
        }
    }

    private var defaultLocalKind: LocalMedia.Kind {
        switch kind {
        case .photo:
            .image
        case .video, .videoNote:
            .video
        case .voice:
            .voice
        case .file, .music:
            .file
        }
    }

    private var fileExtension: String {
        switch kind {
        case .photo:
            return "jpg"
        case .video, .videoNote:
            return "mp4"
        case .voice:
            return "m4a"
        case .file, .music:
            let ext = (name as NSString).pathExtension

            return ext.isEmpty ? "bin" : ext
        }
    }
}
