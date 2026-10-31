import ChatHistory
import Foundation
import MediaStore

enum MapSnapshots {
    static func source(_ location: MessageLocation, dark: Bool) -> MediaSource {
        .map(latitude: location.latitude, longitude: location.longitude, isDark: dark)
    }

    static func mapsURL(_ location: MessageLocation) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        var items = [URLQueryItem(name: "ll", value: "\(location.latitude),\(location.longitude)")]
        if let title = location.title {
            items.append(URLQueryItem(name: "q", value: title))
        }
        components?.queryItems = items

        return components?.url
    }
}
