import CameraUI
import Foundation

extension CameraConfiguration {
    @MainActor
    static func app(
        strings: AppStrings,
        permissions: PermissionFlow,
        videoNotes: VideoNoteSettings,
        videoLimit: TimeInterval,
        modes: [CameraMode] = [.photo],
        gallery: (any CameraGallery)? = nil,
        selectionLimit: Int = 1
    ) -> CameraConfiguration {
        CameraConfiguration(
            strings: CameraStrings(
                close: strings.chatCancel,
                switchCamera: strings.videoNotesSwitchCamera,
                flash: strings.cameraFlash,
                hint: strings.cameraHint,
                zoom: strings.cameraZoom,
                modes: [
                    .photo: strings.cameraModePhoto,
                    .video: strings.cameraModeVideo,
                    .square: strings.cameraModeSquare,
                    .burst: strings.cameraModeBurst,
                    .loop: strings.cameraModeLoop,
                    .dual: strings.cameraModeDual,
                ],
                gallery: strings.cameraGallery,
                galleryDone: strings.cameraGalleryDone,
                lock: strings.cameraLock,
                timer: strings.cameraTimer,
                scanText: strings.cameraScanText,
                copyAll: strings.cameraCopyAll,
                copied: strings.cameraCopied,
                noText: strings.cameraNoText
            ),
            videoLimit: videoLimit,
            isVolumeZoomEnabled: videoNotes.volumeZoomEnabled,
            modes: modes,
            gallery: gallery,
            selectionLimit: selectionLimit,
            isMicrophoneAuthorized: {
                permissions.isAuthorized(.voiceMessage)
            },
            authorizeMicrophone: { presenter in
                await permissions.authorize(.voiceMessage, from: presenter)
            }
        )
    }
}
