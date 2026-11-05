import AirlanceUI
import AvatarUI
import Protocol

extension ProfileViewController {
    func loadServerProfile() {
        guard let server = PeerAvatars.server(id), let load = dependencies.publicProfile else {
            return
        }

        Task { [weak self] in
            guard let data = await load(server.subject), let self else {
                return
            }

            self.peer.apply(data.fields)
            self.peer.phone = data.fields.phone
            self.apply(self.presentation)
            self.showServerPhotos(data, server: server)
        }
    }

    private func showServerPhotos(_ data: ProfileData, server: RemoteAvatar) {
        guard !data.photos.isEmpty else {
            return
        }

        let initials = AvatarDescriptor.initials(from: peer.name)
        photos = data.photos.enumerated().map { index, photo in
            RemoteAvatar(
                subject: server.subject,
                username: server.username,
                photoMediaID: photo.photoMediaID,
                videoMediaID: photo.videoMediaID,
                files: server.files
            ).descriptor(id: index == 0 ? id : "\(id).\(index)", initials: initials)
        }
        photoIndex = min(photoIndex, photos.count - 1)
        showPhoto()
    }

    func personItems() -> [PopupMenuItem] {
        guard let subject = PeerAvatars.server(id)?.subject, let privacy = dependencies.privacy else {
            return []
        }

        let strings = presentation.strings
        var items: [PopupMenuItem] = []
        if let contacts = dependencies.serverContacts {
            items.append(contactItem(subject, contacts: contacts))
        }
        let isBlocked = privacy.isBlocked(subject)
        items.append(PopupMenuItem(
            title: isBlocked ? strings.profileUnblock : strings.profileBlock,
            symbol: "hand.raised",
            isDestructive: !isBlocked
        ) { [weak self] in
            self?.changeBlock(subject, isBlocked: !isBlocked)
        })

        return items
    }

    private func contactItem(_ subject: String, contacts: ServerContactsStore) -> PopupMenuItem {
        let strings = presentation.strings
        let isContact = contacts.contact(for: subject) != nil

        return PopupMenuItem(
            title: isContact ? strings.profileRemoveContact : strings.profileAddContact,
            symbol: isContact ? "person.badge.minus" : "person.badge.plus"
        ) {
            Task {
                if isContact {
                    try? await contacts.remove(subject: subject)
                } else {
                    try? await contacts.add(subject: subject, firstName: "", lastName: "")
                }
            }
        }
    }

    private func changeBlock(_ subject: String, isBlocked: Bool) {
        let privacy = dependencies.privacy
        Task {
            try? await privacy?.setBlocked(subject, isBlocked: isBlocked)
        }
    }
}
