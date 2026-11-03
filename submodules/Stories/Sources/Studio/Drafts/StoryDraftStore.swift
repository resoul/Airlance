import UIKit

@MainActor
public final class StoryDraftStore {
    public struct Entry: Sendable {
        public let draft: StoryDraft
        public let cover: URL
    }

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func list() -> [Entry] {
        let decoder = JSONDecoder()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let files = names.filter { name in
            name.hasSuffix(".json")
        }
        let entries = files.compactMap { name -> Entry? in
            let url = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let draft = try? decoder.decode(StoryDraft.self, from: data) else {
                return nil
            }

            return Entry(draft: draft.rebased(), cover: cover(for: draft.id))
        }

        return entries.sorted { left, right in
            left.draft.createdAt > right.draft.createdAt
        }
    }

    public func contains(_ id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: file(for: id).path)
    }

    public func save(_ draft: StoryDraft, cover image: UIImage?) {
        guard let data = try? JSONEncoder().encode(draft) else {
            return
        }

        try? data.write(to: file(for: draft.id), options: .atomic)
        if let jpeg = image?.jpegData(compressionQuality: 0.8) {
            try? jpeg.write(to: cover(for: draft.id), options: .atomic)
        }
    }

    public func delete(_ id: UUID, removingFiles: Bool) {
        if removingFiles, let entry = list().first(where: { entry in
            entry.draft.id == id
        }) {
            StoryFiles.remove(entry.draft.files)
        }
        try? FileManager.default.removeItem(at: file(for: id))
        try? FileManager.default.removeItem(at: cover(for: id))
    }

    private func file(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".json")
    }

    private func cover(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".jpg")
    }
}
