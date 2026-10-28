import Contacts
import Foundation

public final class DeviceContactThumbnails: @unchecked Sendable {
    private let cache = NSCache<NSString, NSData>()
    private let missing = NSCache<NSString, NSNumber>()

    init() {
        cache.totalCostLimit = 16 * 1024 * 1024
    }

    public func data(for id: String) async -> Data? {
        let key = id as NSString
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }

        guard missing.object(forKey: key) == nil, !Task.isCancelled else {
            return nil
        }

        let keys = [CNContactThumbnailImageDataKey as NSString]
        let contact = try? CNContactStore().unifiedContact(withIdentifier: id, keysToFetch: keys)
        guard let data = contact?.thumbnailImageData else {
            missing.setObject(true, forKey: key)

            return nil
        }

        cache.setObject(data as NSData, forKey: key, cost: data.count)

        return data
    }

    func removeAll() {
        cache.removeAllObjects()
        missing.removeAllObjects()
    }
}
