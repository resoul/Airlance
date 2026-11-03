import Haptics
import UIKit
import Vision

extension CameraViewController {
    private static let codeLifetime: UInt64 = 2_500_000_000

    func setUpScan() {
        var pill = UIButton.Configuration.plain()
        pill.baseForegroundColor = .black
        pill.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 16)
        pill.imagePadding = 8
        pill.titleLineBreakMode = .byTruncatingMiddle
        pill.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .systemFont(ofSize: 15, weight: .semibold)

            return attributes
        }
        codePill.configuration = pill
        codePill.backgroundColor = .systemYellow
        codePill.alpha = 0
        codePill.addAction(UIAction { [weak self] _ in
            self?.codeTapped()
        }, for: .touchUpInside)
        let symbol = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        scanButton.setImage(UIImage(systemName: "text.viewfinder", withConfiguration: symbol), for: .normal)
        scanButton.tintColor = .white
        scanButton.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        scanButton.accessibilityLabel = configuration.strings.scanText
        scanButton.addAction(UIAction { [weak self] _ in
            self?.scanText()
        }, for: .touchUpInside)
        camera.onCode = { [weak self] code in
            self?.found(code)
        }
    }

    func layoutScan(top: CGFloat) {
        scanButton.frame = CGRect(x: view.bounds.width - 164, y: top, width: 44, height: 44)
        scanButton.layer.cornerRadius = 22
        let width = min(view.bounds.width - 64, codePill.intrinsicContentSize.width + 8)
        codePill.frame = CGRect(
            x: (view.bounds.width - width) / 2,
            y: lensBar.frame.minY - 54,
            width: width,
            height: 40
        )
        codePill.layer.cornerRadius = 20
        textPanel?.frame = view.bounds
    }

    private func found(_ code: String) {
        guard textPanel == nil, galleryPanel == nil, !camera.isRecording, isCaptureEnabled else {
            return
        }

        codeHideTask?.cancel()
        if code != shownCode {
            shownCode = code
            let symbol = Self.url(from: code) == nil ? "doc.on.doc" : "link"
            let configuration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            codePill.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
            codePill.setTitle(Self.display(code), for: .normal)
            view.setNeedsLayout()
            Haptics.play(.selection)
            UIView.animate(withDuration: 0.2) {
                self.codePill.alpha = 1
                self.hintLabel.alpha = 0
            }
        }
        codeHideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.codeLifetime)
            guard !Task.isCancelled else {
                return
            }

            self?.hideCode()
        }
    }

    private func hideCode() {
        shownCode = nil
        UIView.animate(withDuration: 0.25) {
            self.codePill.alpha = 0
        }
    }

    private func codeTapped() {
        guard let code = shownCode else {
            return
        }

        Haptics.play(.tap)
        if let url = Self.url(from: code), let onOpenURL {
            onOpenURL(url)

            return
        }

        UIPasteboard.general.string = code
        codePill.setTitle(configuration.strings.copied, for: .normal)
        view.setNeedsLayout()
    }

    private static func url(from code: String) -> URL? {
        guard let url = URL(string: code.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else {
            return nil
        }

        return url
    }

    private static func display(_ code: String) -> String {
        guard let url = url(from: code), let host = url.host else {
            return code
        }

        return host + url.path
    }

    private func scanText() {
        guard textPanel == nil, isCaptureEnabled, !isProcessing else {
            return
        }

        Haptics.play(.tap)
        isProcessing = true
        flashScreen()
        camera.capturePhoto(fast: true) { [weak self] image in
            guard let self else {
                return
            }

            guard let cgImage = image?.cgImage else {
                self.isProcessing = false

                return
            }

            let orientation = image.map(Self.orientation) ?? .up
            Task { [weak self] in
                let text = await Self.recognize(cgImage, orientation: orientation)
                self?.showText(text)
            }
        }
    }

    private func showText(_ text: String) {
        isProcessing = false
        let panel = CameraTextView(text: text, strings: configuration.strings)
        panel.frame = view.bounds
        panel.onClose = { [weak self, weak panel] in
            panel?.hide()
            self?.textPanel = nil
        }
        view.addSubview(panel)
        textPanel = panel
        panel.show()
    }

    nonisolated private static func recognize(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation
    ) async -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["uk-UA", "en-US", "es-ES"]
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
        try? handler.perform([request])
        let lines = request.results?.compactMap { observation in
            observation.topCandidates(1).first?.string
        } ?? []

        return lines.joined(separator: "\n")
    }

    private static func orientation(_ image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .down:
            .down
        case .left:
            .left
        case .right:
            .right
        case .upMirrored:
            .upMirrored
        case .downMirrored:
            .downMirrored
        case .leftMirrored:
            .leftMirrored
        case .rightMirrored:
            .rightMirrored
        default:
            .up
        }
    }
}
