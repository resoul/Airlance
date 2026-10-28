import AirlanceUI
import ChatFolders
import UIKit

extension FolderEditorViewController {
    func openPicker(include: Bool) {
        let strings = presentation.strings
        let types: [FolderPickerOption] = include
            ? ChatFolderCategory.allCases.map { category in
                FolderPickerOption(
                    id: "type.\(category.rawValue)",
                    title: strings.title(for: category),
                    symbol: FolderStyle.symbol(for: category)
                )
            }
            : ChatFolderExclusion.allCases.map { exclusion in
                FolderPickerOption(
                    id: "type.\(exclusion.rawValue)",
                    title: strings.title(for: exclusion),
                    symbol: FolderStyle.symbol(for: exclusion)
                )
            }
        let chats = dependencies.chatsStore.chats.map { chat in
            FolderPickerOption(id: chat.id, title: chat.name, symbol: "bubble.left.fill")
        }
        let selectedTypes = include
            ? draft.categories.map { category in
                "type.\(category.rawValue)"
            }
            : draft.exclusions.map { exclusion in
                "type.\(exclusion.rawValue)"
            }
        let selected = Set(selectedTypes).union(include ? draft.included : draft.excluded)
        let picker = FolderPickerViewController(
            presentationSource: dependencies.presentationContext,
            title: include ? strings.folderAddChats : strings.folderExcludeChats,
            types: types,
            chats: chats,
            selected: selected
        )
        picker.onDone = { [weak self] selection in
            self?.applyPicked(selection, include: include)
        }
        presentSheet(picker)
    }

    func pickEmoji() {
        let picker = FolderEmojiPickerViewController(source: dependencies.presentationContext)
        picker.onPick = { [weak self] emoji in
            self?.draft.emoji = emoji
            self?.updateStyle()
        }
        presentSheet(picker, medium: true)
    }

    func confirmDelete() {
        let strings = presentation.strings
        let store = dependencies.chatFolders
        let router = router
        let id = draft.id
        PopupAlert.show(
            title: strings.foldersDeleteTitle,
            message: strings.foldersDeleteMessage,
            actions: [
                PopupAlertAction(title: strings.foldersDeleteConfirm, style: .destructive) {
                    Task {
                        try? await store.delete(id: id)
                        router.back()
                    }
                },
                PopupAlertAction(title: strings.foldersCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }

    private func applyPicked(_ selection: Set<String>, include: Bool) {
        let typeIDs = selection.filter { id in
            id.hasPrefix("type.")
        }
        let types = Set(typeIDs.compactMap { id in
            Int(id.dropFirst("type.".count))
        })
        let chats = selection.filter { id in
            !id.hasPrefix("type.")
        }
        if include {
            draft.categories = Set(types.compactMap(ChatFolderCategory.init(rawValue:)))
            draft.included = chats
            draft.excluded.subtract(chats)
        } else {
            draft.exclusions = Set(types.compactMap(ChatFolderExclusion.init(rawValue:)))
            draft.excluded = chats
            draft.included.subtract(chats)
        }
        updateSave()
        tableView.reloadData()
    }

    private func presentSheet(_ controller: UIViewController, medium: Bool = false) {
        let navigation = ScreenNavigationController(presentationSource: dependencies.presentationContext)
        navigation.viewControllers = [controller]
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = medium ? [.medium(), .large()] : [.large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        present(navigation, animated: true)
    }
}
