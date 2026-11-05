import ChatHistory
import Foundation
import MediaStore

struct ChatRowThumbnail: Sendable, Hashable {
    let source: MediaSource
    let isVideo: Bool
    var fetch: (@MainActor @Sendable () async -> Void)?

    static func == (lhs: ChatRowThumbnail, rhs: ChatRowThumbnail) -> Bool {
        lhs.source == rhs.source && lhs.isVideo == rhs.isVideo
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(isVideo)
    }
}

struct ChatRowPreview: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case text(String)
        case photo
        case video
        case voice
        case videoNote
        case sticker
        case music(String)
        case file(String)
        case location(String?)
        case contact(String)
        case poll(String)
        case service(MessageService)
    }

    static let maxThumbnails = 3

    var kind: Kind
    var caption = ""
    var thumbnails: [ChatRowThumbnail] = []
    var isForwarded = false

    init(kind: Kind, caption: String = "", thumbnails: [ChatRowThumbnail] = [], isForwarded: Bool = false) {
        self.kind = kind
        self.caption = caption
        self.thumbnails = thumbnails
        self.isForwarded = isForwarded
    }

    @MainActor
    init(_ message: HistoryMessage) {
        self.init(kind: .text(""), isForwarded: message.forward != nil)
        switch message.content {
        case .text:
            kind = .text(ChatsStore.preview(of: message))
        case .photos(let photos, let caption):
            kind = photos.contains { photo in
                photo.video != nil
            } ? .video : .photo
            self.caption = caption
            thumbnails = photos.prefix(Self.maxThumbnails).map { photo in
                ChatRowThumbnail(source: photo.source, isVideo: photo.video != nil)
            }
        case .file(let file, let caption):
            kind = file.isAudio ? .music(Self.title(of: file.name)) : .file(file.name)
            self.caption = caption
        case .voice:
            kind = .voice
        case .videoNote:
            kind = .videoNote
        case .location(let location):
            kind = .location(location.title)
        case .contact(let contact):
            kind = .contact(contact.name)
        case .poll(let poll):
            kind = .poll(poll.question)
        case .service(let service):
            kind = .service(service)
        }
    }

    func text(_ strings: AppStrings) -> String {
        if !caption.isEmpty {
            return caption
        }

        switch kind {
        case .text(let text):
            return text
        case .photo:
            return strings.chatsPreviewPhoto
        case .video:
            return strings.chatsPreviewVideo
        case .voice:
            return strings.chatsPreviewVoice
        case .videoNote:
            return strings.chatsPreviewVideoNote
        case .sticker:
            return strings.chatsPreviewSticker
        case .music(let title):
            return "♪ \(title)"
        case .file(let name):
            return name
        case .location(let title):
            return title ?? strings.chatsPreviewLocation
        case .contact(let name):
            return name
        case .poll(let question):
            return question
        case .service(let service):
            return HistorySnapshot.serviceTitle(service, titles: HistorySnapshot.Titles(strings: strings))
        }
    }

    private static func title(of fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        let parts = stem.components(separatedBy: " - ")

        return parts.count == 2 ? "\(parts[0]) — \(parts[1])" : stem
    }
}

extension ChatSummary {
    func rowText(_ strings: AppStrings) -> String {
        let body = preview?.text(strings) ?? message
        guard kind == .group else {
            return body
        }

        if isLastOutgoing {
            return "\(strings.chatYou): \(body)"
        }

        return lastAuthor.map { author in
            "\(author): \(body)"
        } ?? body
    }
}
