import UIKit
import UniformTypeIdentifiers

@MainActor
final class StoryTrackPicker: NSObject, UIDocumentPickerDelegate {
    var onPick: (@MainActor (URL) -> Void)?

    func present(from controller: UIViewController) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        controller.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            onPick?(url)
        }
    }
}
