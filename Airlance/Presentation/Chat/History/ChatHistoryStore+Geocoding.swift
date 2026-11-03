import ChatHistory
import CoreLocation
import Foundation

extension ChatHistoryStore {
    func geocode(_ location: MessageLocation, messageID: String, chatID: String) {
        Task { [weak self] in
            let point = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(point)
            guard let place = placemarks?.first.flatMap(Self.place) else {
                return
            }

            self?.update(messageID, in: chatID) { message in
                guard case .location(let current) = message.content, current == location else {
                    return
                }

                message.content = .location(
                    MessageLocation(
                        latitude: location.latitude,
                        longitude: location.longitude,
                        title: place.title,
                        address: place.address
                    )
                )
            }
        }
    }

    private static func place(_ placemark: CLPlacemark) -> (title: String, address: String?)? {
        let street = [placemark.thoroughfare, placemark.subThoroughfare].compactMap(\.self).joined(separator: " ")
        let city = placemark.locality ?? placemark.administrativeArea
        guard let title = placemark.areasOfInterest?.first ?? placemark.name ?? city else {
            return nil
        }

        let parts = [street.isEmpty || street == title ? nil : street, city == title ? nil : city]
        let address = parts.compactMap(\.self).joined(separator: ", ")

        return (title, address.isEmpty ? nil : address)
    }
}
