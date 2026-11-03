import Stories
import UIKit

@MainActor
enum StoryInteractions {
    static func handle(_ interaction: StoryInteraction, router: AppRouter, store: StoriesStore) {
        switch interaction {
        case .openPeer(let id):
            router.dismiss()
            router.open(.profile(id))
        case .openPlace(let place):
            if let url = mapsURL(place) {
                UIApplication.shared.open(url)
            }
        case .openLink(let url):
            router.dismiss()
            router.open(.browser(url))
        case .addYours(let prompt):
            seed(.addYours(prompt), router: router, store: store)
        case .edit(let item):
            if let draft = store.story(id: item)?.draft {
                seed(.edit(draft), router: router, store: store)
            }
        case .delete(let item):
            router.dismiss()
            store.delete(id: item)
        case .repost(let media, let peer):
            seed(.repost(media, peer), router: router, store: store)
        case .react, .vote, .answer:
            break
        }
    }

    private static func seed(_ seed: StorySeed, router: AppRouter, store: StoriesStore) {
        router.dismiss()
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            store.seed(seed)
        }
    }

    private static func mapsURL(_ place: StoryPlace) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        var items = [URLQueryItem(name: "q", value: place.title)]
        if let latitude = place.latitude, let longitude = place.longitude {
            items.append(URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"))
        }
        components?.queryItems = items

        return components?.url
    }
}
