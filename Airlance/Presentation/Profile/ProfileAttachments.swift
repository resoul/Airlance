import Foundation

enum ProfileAttachments {
    private static let files = ["Project notes.pdf", "Airlance design.fig", "Resources.zip", "Meeting notes.txt"]
    private static let links = [
        ("Texture", "texturegroup.org"),
        ("Swift", "swift.org"),
        ("Apple Developer", "developer.apple.com"),
        ("Airlance", "airlance.org"),
    ]

    static func items(
        _ kind: ProfileAttachmentItem.Kind,
        strings: AppStrings,
        onSelect: @escaping @MainActor (String) -> Void
    ) -> [ProfileAttachmentItem] {
        let formatter = DateFormatter()
        formatter.locale = strings.pack.locale
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        let now = Date()

        return (0..<36).map { index in
            let date = formatter.string(from: now.addingTimeInterval(-Double(index) * 86_400 * 2))
            let (title, detail) = content(kind, index: index, strings: strings)

            return ProfileAttachmentItem(
                kind: kind,
                index: index,
                title: title,
                detail: "\(detail) · \(date)",
                onSelect: onSelect
            )
        }
    }

    private static func content(
        _ kind: ProfileAttachmentItem.Kind,
        index: Int,
        strings: AppStrings
    ) -> (String, String) {
        switch kind {
        case .files:
            (files[index % files.count], "\(index % 8 + 1).\(index % 9 + 1) MB")
        case .links:
            links[index % links.count]
        case .voice:
            (strings.profileVoiceMessage, String(format: "0:%02d", 12 + index % 46))
        }
    }
}
