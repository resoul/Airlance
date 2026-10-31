import ChatHistory
import Foundation

enum ChatLinkFixtures {
    struct Site {
        let url: String
        let preview: LinkPreview
    }

    static let sites = [
        Site(
            url: "https://www.swift.org/blog/",
            preview: LinkPreview(
                site: "Swift.org",
                title: "Swift.org Blog",
                summary: "Новини мови Swift, релізи та статті від команди проєкту.",
                photo: photo("swift", seed: 211, width: 1200, height: 630),
                hasLargePhoto: true
            )
        ),
        Site(
            url: "https://github.com/TextureGroup/Texture",
            preview: LinkPreview(
                site: "GitHub",
                title: "TextureGroup/Texture",
                summary: "Smooth asynchronous user interfaces for iOS apps.",
                photo: photo("texture", seed: 342, width: 400, height: 400),
                hasLargePhoto: false
            )
        ),
        Site(
            url: "https://developer.apple.com/design/human-interface-guidelines/",
            preview: LinkPreview(
                site: "Apple Developer",
                title: "Human Interface Guidelines",
                summary: "Best practices to design a great experience for any Apple platform.",
                photo: photo("hig", seed: 487, width: 1280, height: 720),
                hasLargePhoto: true
            )
        ),
        Site(
            url: "https://www.figma.com/community",
            preview: LinkPreview(
                site: "Figma",
                title: "Figma Community",
                summary: "Explore thousands of free files, plugins and widgets made by the community.",
                photo: photo("figma", seed: 563, width: 400, height: 400),
                hasLargePhoto: false
            )
        ),
        Site(
            url: "https://www.wikipedia.org/",
            preview: LinkPreview(
                site: "Wikipedia",
                title: "Wikipedia, the free encyclopedia",
                summary: "A free online encyclopedia, created and edited by volunteers around the world.",
                photo: nil,
                hasLargePhoto: false
            )
        ),
    ]

    static let forwardSources = [
        MessageForward(fromID: "tech-digest", fromName: "Tech Digest"),
        MessageForward(fromID: "design-daily", fromName: "Дизайн щодня"),
        MessageForward(fromID: "olena", fromName: "Олена"),
    ]

    private static let templates = [
        "Ось, тримай: %@",
        "%@ — глянь, коли буде хвилинка",
        "Знайшов те, про що казав %@",
    ]

    static func text(site: Int, template: Int) -> (text: String, link: MessageLink) {
        let site = sites[site % sites.count]
        let text = String(format: templates[template % templates.count], site.url)

        return (text, MessageLink(url: site.url, preview: site.preview))
    }

    static func preview(for url: String) -> LinkPreview? {
        sites.first { site in
            site.url == url
        }?.preview
    }

    private static func photo(_ id: String, seed: Int, width: Int, height: Int) -> MessagePhoto {
        MessagePhoto(id: "link-\(id)", width: width, height: height, source: .generated(seed: seed))
    }
}
