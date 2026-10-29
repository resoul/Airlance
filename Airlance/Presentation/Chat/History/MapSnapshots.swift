import ChatHistory
import MapKit
import UIKit

enum MapSnapshots {
    private static let prefix = "map:"
    private static let span: CLLocationDistance = 900

    static func source(_ location: MessageLocation, dark: Bool) -> String {
        "\(prefix)\(location.latitude),\(location.longitude),\(dark ? 1 : 0)"
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

    static func isMap(_ source: String) -> Bool {
        source.hasPrefix(prefix)
    }

    static func snapshot(_ source: String, size: CGSize, scale: CGFloat) async -> UIImage? {
        let values = source.dropFirst(prefix.count).split(separator: ",").compactMap { value in
            Double(value)
        }
        guard values.count == 3 else {
            return nil
        }

        let center = CLLocationCoordinate2D(latitude: values[0], longitude: values[1])
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: center, latitudinalMeters: span, longitudinalMeters: span)
        options.size = size
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(displayScale: scale),
            UITraitCollection(userInterfaceStyle: values[2] > 0 ? .dark : .light),
        ])

        return try? await MKMapSnapshotter(options: options).start().image
    }
}
