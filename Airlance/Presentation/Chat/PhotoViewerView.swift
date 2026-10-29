import Haptics
import UIKit

struct PhotoViewerPage {
    let thumbnail: UIImage?
    let aspectRatio: CGFloat
    let source: String
    let video: URL?
}

struct PhotoViewerSource {
    let frame: @MainActor () -> CGRect?
    let setHidden: @MainActor (Bool) -> Void
    let corners: MediaCorners
}

final class PhotoViewerView: UIView, UIScrollViewDelegate {
    private let pagesData: [PhotoViewerPage]
    private let sources: [PhotoViewerSource]
    private let counterText: (Int, Int) -> String
    private let dim = UIView()
    private let pager = UIScrollView()
    private var flight: PhotoFlight?
    private let clipArea: CGRect
    private var pages: [UIScrollView] = []
    var players: [Int: VideoPlayerView] = [:]
    let controls = VideoControlsView()
    let topBar = UIView()
    private let counter = UILabel()
    private let subtitle = UILabel()
    private(set) var index: Int
    private var chromeHidden = false

    private var imageView: UIImageView? {
        pages[index].subviews.first as? UIImageView
    }

    init(
        pages: [PhotoViewerPage],
        sources: [PhotoViewerSource],
        start: Int,
        clipArea: CGRect,
        title: String,
        counterText: @escaping (Int, Int) -> String,
        host: UIView
    ) {
        pagesData = pages
        self.sources = sources
        self.counterText = counterText
        index = start
        self.clipArea = clipArea
        super.init(frame: host.bounds)
        host.addSubview(self)
        dim.backgroundColor = .black
        dim.frame = bounds
        dim.alpha = 0
        addSubview(dim)
        buildPager()
        buildChrome(title: title, safeTop: host.safeAreaInsets.top)
        buildControls(safeBottom: host.safeAreaInsets.bottom)
        let drag = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        drag.delegate = self
        addGestureRecognizer(drag)
        loadFullImages(scale: host.traitCollection.displayScale)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func open() {
        guard let target = imageView, let from = sources[index].frame() else {
            showChrome(alpha: 1)
            activateVideo()

            return
        }

        let flight = PhotoFlight(image: pagesData[index].thumbnail, in: self, below: topBar)
        self.flight = flight
        target.alpha = 0
        sources[index].setHidden(true)
        Haptics.play(.tap)
        flight.run(
            from: PhotoFlight.State(frame: from, clip: clipArea, corners: sources[index].corners),
            to: PhotoFlight.State(frame: target.frame, clip: bounds, corners: .zero)
        ) { [weak self] in
            target.alpha = 1
            flight.container.removeFromSuperview()
            self?.flight = nil
            self?.activateVideo()
        }
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.2) {
            self.showChrome(alpha: 1)
        }
    }

    private func buildPager() {
        pager.frame = bounds
        pager.isPagingEnabled = true
        pager.showsHorizontalScrollIndicator = false
        pager.contentInsetAdjustmentBehavior = .never
        pager.delegate = self
        pager.contentSize = CGSize(width: bounds.width * CGFloat(pagesData.count), height: bounds.height)
        addSubview(pager)
        for (page, data) in pagesData.enumerated() {
            let zoom = UIScrollView(frame: bounds.offsetBy(dx: bounds.width * CGFloat(page), dy: 0))
            zoom.minimumZoomScale = 1
            zoom.maximumZoomScale = 4
            zoom.delegate = self
            zoom.showsVerticalScrollIndicator = false
            zoom.showsHorizontalScrollIndicator = false
            zoom.contentInsetAdjustmentBehavior = .never
            let view = UIImageView(image: data.thumbnail)
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.layer.cornerCurve = .continuous
            view.frame = fittedFrame(data.aspectRatio)
            zoom.addSubview(view)
            if let url = data.video {
                addVideo(url, page: page, in: view)
            }
            zoom.contentSize = bounds.size
            let double = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
            double.numberOfTapsRequired = 2
            zoom.addGestureRecognizer(double)
            let single = UITapGestureRecognizer(target: self, action: #selector(toggleChrome))
            single.require(toFail: double)
            zoom.addGestureRecognizer(single)
            pager.addSubview(zoom)
            pages.append(zoom)
        }
        pager.contentOffset.x = bounds.width * CGFloat(index)
    }

    private func buildChrome(title: String, safeTop: CGFloat) {
        topBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: safeTop + 52)
        topBar.backgroundColor = UIColor(white: 0, alpha: 0.4)
        let close = UIButton(type: .system)
        let symbol = UIImage.SymbolConfiguration(pointSize: 19)
        close.setImage(UIImage(systemName: "chevron.backward", withConfiguration: symbol), for: .normal)
        close.tintColor = .white
        close.frame = CGRect(x: 6, y: safeTop + 4, width: 44, height: 44)
        close.addAction(
            UIAction { [weak self] _ in
                self?.close()
            },
            for: .touchUpInside
        )
        topBar.addSubview(close)
        for (label, size, y) in [(counter, CGFloat(16), safeTop + 6), (subtitle, CGFloat(13), safeTop + 26)] {
            label.textAlignment = .center
            label.textColor = label === counter ? .white : UIColor(white: 1, alpha: 0.7)
            label.font = .systemFont(ofSize: size, weight: label === counter ? .semibold : .regular)
            label.frame = CGRect(x: 60, y: y, width: bounds.width - 120, height: size + 4)
            topBar.addSubview(label)
        }
        subtitle.text = title
        topBar.alpha = 0
        addSubview(topBar)
        updateCounter()
    }

    private func loadFullImages(scale: CGFloat) {
        for (page, data) in pagesData.enumerated() {
            let size = fittedFrame(data.aspectRatio).size
            let request = MediaImageRequest(
                source: data.source,
                size: size,
                scale: scale,
                corners: .zero
            )
            Task { [weak self] in
                guard let image = await MediaImageLoader.shared.image(for: request), let self else {
                    return
                }

                (self.pages[page].subviews.first as? UIImageView)?.image = image
            }
        }
    }

    private func fittedFrame(_ aspectRatio: CGFloat) -> CGRect {
        let ratio = max(aspectRatio, 0.01)
        let scale = min(bounds.width / ratio, bounds.height)
        let size = CGSize(width: floor(scale * ratio), height: floor(scale))

        return CGRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func showChrome(alpha: CGFloat) {
        dim.alpha = alpha
        setChromeAlpha(chromeHidden ? 0 : alpha)
    }

    private func updateCounter() {
        counter.text = counterText(index + 1, pagesData.count)
    }

    func close() {
        guard let current = imageView else {
            stopVideos()
            removeFromSuperview()

            return
        }

        isUserInteractionEnabled = false
        stopVideos()
        self.flight?.container.removeFromSuperview()
        let flight = PhotoFlight(image: current.image, in: self, below: topBar)
        self.flight = flight
        let frame = current.convert(current.bounds, to: self)
        let radius = current.layer.cornerRadius * frame.width / max(current.bounds.width, 1)
        let corners = MediaCorners(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
        let start = PhotoFlight.State(frame: frame, clip: bounds, corners: corners)
        pager.isHidden = true
        UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.showChrome(alpha: 0)
        }
        guard let target = sources[index].frame() else {
            flight.run(from: start, to: start) {}
            UIView.animate(withDuration: 0.3) {
                flight.container.alpha = 0
                flight.container.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            } completion: { _ in
                self.finishClose()
            }

            return
        }

        let end = PhotoFlight.State(frame: target, clip: clipArea, corners: sources[index].corners)
        flight.run(from: start, to: end) { [weak self] in
            self?.finishClose()
        }
    }

    private func finishClose() {
        for source in sources {
            source.setHidden(false)
        }
        removeFromSuperview()
    }
}

extension PhotoViewerView {
    @objc
    private func toggleChrome() {
        chromeHidden.toggle()
        UIView.animate(withDuration: 0.25) {
            self.setChromeAlpha(self.chromeHidden ? 0 : 1)
        }
    }

    @objc
    private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        let zoom = pages[index]
        guard zoom.zoomScale <= 1 else {
            zoom.setZoomScale(1, animated: true)

            return
        }

        let point = gesture.location(in: zoom.subviews.first)
        let size = CGSize(width: zoom.bounds.width / 2.5, height: zoom.bounds.height / 2.5)
        let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        zoom.zoom(to: CGRect(origin: origin, size: size), animated: true)
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        guard let current = imageView else {
            return
        }

        let translation = gesture.translation(in: self)
        let progress = min(max(translation.y / 400, 0), 1)
        switch gesture.state {
        case .changed:
            let scale = 1 - progress * 0.3
            let move = CGAffineTransform(translationX: translation.x, y: translation.y)
            current.transform = move.scaledBy(x: scale, y: scale)
            current.layer.cornerRadius = min(1, progress * 4) * 16 / scale
            dim.alpha = 1 - progress
            setChromeAlpha(chromeHidden ? 0 : 1 - progress * 3)
        case .ended, .cancelled:
            if translation.y > 120 || gesture.velocity(in: self).y > 900 {
                close()
            } else {
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                    current.transform = .identity
                    current.layer.cornerRadius = 0
                    self.showChrome(alpha: 1)
                }
            }
        default:
            break
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        scrollView === pager ? nil : scrollView.subviews.first
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard let view = scrollView.subviews.first else {
            return
        }

        view.frame.origin = CGPoint(
            x: max(0, (scrollView.bounds.width - view.frame.width) / 2),
            y: max(0, (scrollView.bounds.height - view.frame.height) / 2)
        )
        scrollView.contentSize = CGSize(
            width: max(view.frame.width, scrollView.bounds.width),
            height: max(view.frame.height, scrollView.bounds.height)
        )
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === pager else {
            return
        }

        let page = Int((pager.contentOffset.x / max(pager.bounds.width, 1)).rounded())
        guard page != index, pages.indices.contains(page) else {
            return
        }

        pages[index].setZoomScale(1, animated: false)
        sources[index].setHidden(false)
        index = page
        sources[index].setHidden(true)
        updateCounter()
        setChromeAlpha(chromeHidden ? 0 : 1)
        activateVideo()
    }
}

extension PhotoViewerView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard let pan = gesture as? UIPanGestureRecognizer, pan.view === self else {
            return true
        }

        let velocity = pan.velocity(in: self)

        return pages[index].zoomScale <= 1.01 && velocity.y > abs(velocity.x)
    }

    func gestureRecognizer(
        _ gesture: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        gesture.view === self && other.view is UIScrollView
    }
}
