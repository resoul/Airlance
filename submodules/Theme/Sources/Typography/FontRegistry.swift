import CoreText
import Foundation
import os

enum FontRegistry {
    private static let bundleName = "Theme"
    private static let logger = Logger(subsystem: "Theme", category: "Fonts")

    static func registerBundledFonts() {
        guard
            let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL),
            let fontURLs = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil)
        else {
            logger.error("Bundled fonts not found")

            return
        }

        for url in fontURLs {
            register(url)
        }
    }

    private static func register(_ url: URL) {
        var error: Unmanaged<CFError>?
        guard !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            return
        }

        let code = error.map { error in
            CFErrorGetCode(error.takeRetainedValue())
        } ?? 0
        guard code != CTFontManagerError.alreadyRegistered.rawValue else {
            return
        }

        logger.error("Can't register \(url.lastPathComponent, privacy: .public): \(code)")
    }
}
