import ChatHistory
import QuickLook
import UIKit

final class FilePreviewSource: NSObject, QLPreviewControllerDataSource {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
        url as NSURL
    }
}

extension ChatViewController {
    func openFile(_ file: MessageFile) {
        guard let url = ChatFileFixtures.localCopy(of: file) else {
            return
        }

        inputBar.dismissKeyboard()
        let source = FilePreviewSource(url: url)
        let preview = QLPreviewController()
        preview.dataSource = source
        filePreviewSource = source
        present(preview, animated: true)
    }
}
