import CryptoKit
import Foundation
import WebKit

@MainActor
public enum BrowserDataStore {
    public static func store(for identifier: String) -> WKWebsiteDataStore {
        if #available(iOS 17.0, *) {
            return WKWebsiteDataStore(forIdentifier: uuid(for: identifier))
        }

        return .default()
    }

    public static func remove(identifier: String) async {
        if #available(iOS 17.0, *) {
            try? await WKWebsiteDataStore.remove(forIdentifier: uuid(for: identifier))
        }
    }

    private static func uuid(for identifier: String) -> UUID {
        let digest = Array(SHA256.hash(data: Data(("browser." + identifier).utf8)))

        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]
        ))
    }
}
