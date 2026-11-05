import CameraUI
import MediaStore
import Stories
import UIKit

extension ChatsViewController {
    func createStory(seed: StorySeed? = nil) {
        let flow = dependencies.permissionFlow
        Task { [weak self] in
            guard let self, await flow.authorize(.takePhoto, from: self) else {
                return
            }

            self.presentStoryCamera(seed: seed)
        }
    }

    private func presentStoryCamera(seed: StorySeed?) {
        guard storyStudio == nil else {
            return
        }

        let media = dependencies.media
        guard let session = CameraSession(makeVideoURL: {
            media.reserve(.video, extension: "mov").url
        }) else {
            return
        }

        let strings = presentation.strings
        let controller = CameraViewController(
            session: session,
            configuration: .app(
                strings: strings,
                permissions: dependencies.permissionFlow,
                videoNotes: dependencies.videoNotes,
                videoLimit: StoryStudio.videoLimit,
                modes: [.photo, .video, .loop, .dual],
                gallery: CameraLibrary(permissions: dependencies.permissionFlow),
                selectionLimit: 6
            ),
            origin: storyOrigin
        )
        let studio = StoryStudio(controller: controller, context: makeStudioContext(media: media))
        studio.seed = seed
        controller.onOpenURL = { [weak self, weak controller] url in
            controller?.close()
            self?.router.open(.browser(url))
        }
        studio.onClose = { [weak self] in
            self?.storyStudio = nil
        }
        storyStudio = studio
        present(controller, animated: false) {
            studio.start()
        }
    }

    private func makeStudioContext(media: MediaStore) -> AppStoryStudioContext {
        AppStoryStudioContext(
            stories: dependencies.storiesStore,
            chats: dependencies.chatsStore,
            media: media,
            strings: presentation.strings,
            permissions: dependencies.permissionFlow,
            autoSubtitles: dependencies.videoNotes.autoSubtitlesEnabled,
            defaultLifetime: dependencies.storyLifetime()
        )
    }

    private var storyOrigin: CGRect? {
        guard let window = view.window,
              let mine = dependencies.storiesStore.ordered.first(where: \.isSelf) else {
            return nil
        }

        return header.avatarFrame(for: mine.peerID, in: window)
    }
}
