import ChatHistory
import Foundation

enum ChatFileFixtures {
    private static let prefix = "bundle-file:"
    private static let files = [
        (name: "Звіт за жовтень.pdf", resource: "file-report.pdf"),
        (name: "Бриф — екран профілю.docx", resource: "file-brief.docx"),
        (name: "Кошторис.csv", resource: "file-budget.csv"),
        (name: "Нотатки з дзвінка.txt", resource: "file-notes.txt"),
    ]
    private static let captions = ["Глянь, будь ласка", "Як домовлялись", "Остання версія"]
    private static let places = [
        MessageLocation(latitude: 50.4501, longitude: 30.5234, title: "Майдан Незалежності", address: "Київ"),
        MessageLocation(
            latitude: 50.4565,
            longitude: 30.5138,
            title: "Пейзажна алея",
            address: "вул. Велика Житомирська, Київ"
        ),
        MessageLocation(
            latitude: 50.4146,
            longitude: 30.5634,
            title: "Ботанічний сад імені Гришка",
            address: "вул. Тимірязєвська, 1, Київ"
        ),
        MessageLocation(latitude: 50.4433, longitude: 30.5210),
        MessageLocation(latitude: 49.8419, longitude: 24.0315, title: "Площа Ринок", address: "Львів"),
    ]

    static func file(pick: Int, isOutgoing: Bool) -> MessageContent {
        let entry = files[pick % files.count]
        let url = Bundle.main.url(forResource: entry.resource, withExtension: nil)
        let size = url.flatMap { url in
            try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
        } ?? 0
        let file = MessageFile(
            name: entry.name,
            size: size,
            source: prefix + entry.resource,
            isDownloaded: isOutgoing || pick % 3 == 0
        )
        let caption = pick % 4 == 1 ? captions[pick / 4 % captions.count] : ""

        return .file(file, caption: caption)
    }

    static func location(pick: Int) -> MessageContent {
        .location(places[pick % places.count])
    }

    static func localCopy(of file: MessageFile) -> URL? {
        guard
            file.source.hasPrefix(prefix),
            let source = Bundle.main.url(forResource: String(file.source.dropFirst(prefix.count)), withExtension: nil)
        else {
            return nil
        }

        let manager = FileManager.default
        let directory = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Files", isDirectory: true)
        let target = directory.appendingPathComponent(file.name.replacingOccurrences(of: "/", with: "-"))
        if !manager.fileExists(atPath: target.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
            try? manager.copyItem(at: source, to: target)
        }

        return manager.fileExists(atPath: target.path) ? target : nil
    }
}
