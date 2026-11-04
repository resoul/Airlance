import ChatHistory
import UIKit
import UniformTypeIdentifiers

extension ChatViewController {
    func attachSoundFiles() -> [AttachSoundFile] {
        let chats = dependencies.chatsStore
        let you = presentation.strings.chatYou

        return dependencies.historyStore.audioFiles().map { found in
            let chat = chats.chat(found.chatID)?.name ?? ""
            let source = found.message.isOutgoing ? "\(you) › \(chat)" : found.message.authorName

            return AttachSoundFile(id: found.message.id, file: found.file, source: source.isEmpty ? chat : source)
        }
    }

    func bindAttachSound(_ sheet: AttachSheet) {
        sheet.onPickSoundFiles = { [weak self] in
            self?.pickFiles(types: [.audio])
        }
        sheet.onSoundFile = { [weak self] file in
            self?.postAttachment(.file(file, caption: ""))
        }
        sheet.onContact = { [weak self] contact in
            let phone = contact.phoneNumbers.first ?? ""
            self?.postAttachment(.contact(MessageContact(name: contact.displayName, phone: phone)))
        }
    }

    func pickFiles(types: [UTType]) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }
}
