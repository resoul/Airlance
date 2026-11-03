import UIKit

public enum CameraMode: CaseIterable, Hashable, Sendable {
    case photo
    case video
    case square
    case burst
    case loop
    case dual
}

public struct CameraStrings: Sendable {
    public let close: String
    public let switchCamera: String
    public let flash: String
    public let hint: String
    public let zoom: String
    public let modes: [CameraMode: String]
    public let gallery: String
    public let galleryDone: String
    public let lock: String
    public let timer: String
    public let scanText: String
    public let copyAll: String
    public let copied: String
    public let noText: String

    public init(
        close: String,
        switchCamera: String,
        flash: String,
        hint: String,
        zoom: String,
        modes: [CameraMode: String],
        gallery: String,
        galleryDone: String,
        lock: String,
        timer: String,
        scanText: String,
        copyAll: String,
        copied: String,
        noText: String
    ) {
        self.close = close
        self.switchCamera = switchCamera
        self.flash = flash
        self.hint = hint
        self.zoom = zoom
        self.modes = modes
        self.gallery = gallery
        self.galleryDone = galleryDone
        self.lock = lock
        self.timer = timer
        self.scanText = scanText
        self.copyAll = copyAll
        self.copied = copied
        self.noText = noText
    }
}

@MainActor
public protocol CameraGallery: AnyObject {
    var isAuthorized: Bool { get }
    var count: Int { get }
    var onChange: (@MainActor () -> Void)? { get set }

    func authorize(from presenter: UIViewController) async -> Bool
    func identifier(at index: Int) -> String
    func duration(at index: Int) -> TimeInterval?
    func thumbnail(at index: Int, side: CGFloat, completion: @escaping @MainActor (UIImage?) -> Void)
    func load(at index: Int) async -> CameraCapture?
}

public struct CameraConfiguration {
    public let strings: CameraStrings
    public let videoLimit: TimeInterval
    public let isVolumeZoomEnabled: Bool
    public let modes: [CameraMode]
    public let gallery: (any CameraGallery)?
    public let selectionLimit: Int
    public let isMicrophoneAuthorized: @MainActor () -> Bool
    public let authorizeMicrophone: @MainActor (UIViewController) async -> Bool

    public init(
        strings: CameraStrings,
        videoLimit: TimeInterval,
        isVolumeZoomEnabled: Bool,
        modes: [CameraMode] = [.photo],
        gallery: (any CameraGallery)? = nil,
        selectionLimit: Int = 1,
        isMicrophoneAuthorized: @escaping @MainActor () -> Bool,
        authorizeMicrophone: @escaping @MainActor (UIViewController) async -> Bool
    ) {
        self.strings = strings
        self.videoLimit = videoLimit
        self.isVolumeZoomEnabled = isVolumeZoomEnabled
        self.modes = modes.isEmpty ? [.photo] : modes
        self.gallery = gallery
        self.selectionLimit = max(1, selectionLimit)
        self.isMicrophoneAuthorized = isMicrophoneAuthorized
        self.authorizeMicrophone = authorizeMicrophone
    }
}

public enum CameraCapture {
    case photo(UIImage)
    case video(URL)
}
