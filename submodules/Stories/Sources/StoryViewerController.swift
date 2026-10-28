import LiquidUI
import UIKit

@MainActor
public final class StoryViewerController: UIViewController {
    enum Phase {
        case opening
        case open
        case closing
    }

    public var onSeen: (@MainActor (String, Int) -> Void)?
    public var onClose: (@MainActor () -> Void)?
    public let transition = StoryViewerTransition()

    let authors: [StoryAuthor]
    let dim = UIView()
    let stage = UIView()
    let stageMask = CAShapeLayer()
    var page: StoryPageView?
    var authorIndex: Int
    var progress: CGFloat = 0
    var phase = Phase.opening
    var isHeld = false
    var isDragging = false
    var isTurning = false
    var isHorizontalPan = false
    var fadesWithSource = false
    var isCloseRequested = false
    var phaseCompletion: (@MainActor () -> Void)?
    var top = Spring(0, stiffness: 12, dampingRatio: 0.7)
    var bottom = Spring(0, stiffness: 9.5, dampingRatio: 0.66)
    var left = Spring(0, stiffness: 11, dampingRatio: 0.7)
    var right = Spring(0, stiffness: 10, dampingRatio: 0.68)
    var corner = Spring(0, stiffness: 10, dampingRatio: 0.85)
    var goal: CGRect = .zero
    lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.tick(deltaTime)
    }

    public init(authors: [StoryAuthor], startPeerID: String) {
        self.authors = authors.filter { author in
            !author.items.isEmpty
        }
        authorIndex = self.authors.firstIndex { author in
            author.id == startPeerID
        } ?? 0
        super.init(nibName: nil, bundle: nil)
        transition.viewer = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public var currentPeerID: String? {
        authors.indices.contains(authorIndex) ? authors[authorIndex].id : nil
    }

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    public func install(in container: UINavigationController, source: (any StoryTransitionSource)?) {
        transition.source = source
        container.setNavigationBarHidden(true, animated: false)
        container.view.backgroundColor = .clear
        container.modalPresentationStyle = .overFullScreen
        container.modalPresentationCapturesStatusBarAppearance = true
        container.transitioningDelegate = transition
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        dim.backgroundColor = .black
        dim.alpha = 0
        view.addSubview(dim)
        stage.layer.mask = stageMask
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 900
        stage.layer.sublayerTransform = perspective
        view.addSubview(stage)
        setupGestures()

        if authors.indices.contains(authorIndex) {
            let page = makePage(for: authors[authorIndex])
            stage.addSubview(page)
            self.page = page
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        dim.frame = view.bounds
        stage.bounds = CGRect(origin: .zero, size: view.bounds.size)
        stage.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        for case let page as StoryPageView in stage.subviews {
            page.bounds = stage.bounds
            page.center = CGPoint(x: stage.bounds.midX, y: stage.bounds.midY)
            page.safeTop = view.safeAreaInsets.top
        }
        if phase == .open, !isDragging {
            goal = view.bounds
        }
        applyStage()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if authors.isEmpty {
            requestClose()
        }
    }

    func makePage(for author: StoryAuthor) -> StoryPageView {
        let page = StoryPageView(author: author)
        page.frame = stage.bounds
        page.safeTop = view.safeAreaInsets.top
        page.closeButton.addAction(
            UIAction { [weak self] _ in
                self?.requestClose()
            },
            for: .touchUpInside
        )
        let index = author.startIndex
        page.show(index)
        onSeen?(author.id, index)

        return page
    }
}
