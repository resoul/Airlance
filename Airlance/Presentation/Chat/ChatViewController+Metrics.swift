import ToastUI
import UIKit

extension ChatViewController {
    func placeMetrics() {
        guard ChatStressFixtures.isStress(id) else {
            return
        }

        let metrics = HistoryMetrics()
        history.metrics = metrics
        let overlay = HistoryMetricsView(metrics: metrics)
        overlay.onCopy = { [weak self] _ in
            guard let self else {
                return
            }

            Toast(self.presentation.strings.chatCopied, symbol: "doc.on.doc.fill")
                .show(theme: self.presentation.theme, in: self.view)
        }
        view.addSubview(overlay)
        metricsView = overlay
    }
}
