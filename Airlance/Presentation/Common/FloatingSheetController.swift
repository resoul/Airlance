import Theme
import UIKit

final class FloatingSheetController: UIViewController, UIGestureRecognizerDelegate {
    private static let margin: CGFloat = 8
    private static let maxWidth: CGFloat = 500
    private static let dragArea: CGFloat = 72

    private let content: UIViewController
    private let contentHeight: @MainActor (CGFloat) -> CGFloat
    private let theme: AppTheme
    private let dim = UIView()
    private let card = FloatingCard()
    private let hintBox = UIView()
    private let hintLabel = UILabel()
    private var isShown = false
    private var isClosing = false

    init(content: UIViewController, theme: AppTheme, height: @escaping @MainActor (CGFloat) -> CGFloat) {
        self.content = content
        self.theme = theme
        contentHeight = height
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        view.addSubview(dim)
        card.radius = 36
        card.apply(theme)
        let drag = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        drag.delegate = self
        card.addGestureRecognizer(drag)
        view.addSubview(card)
        addChild(content)
        card.content.addSubview(content.view)
        content.didMove(toParent: self)
        FloatingStyle.style(hintBox, theme: theme)
        hintBox.layer.cornerRadius = 16
        hintBox.alpha = 0
        hintLabel.font = theme.fonts.caption
        hintLabel.textColor = theme.colors.textPrimary
        hintBox.addSubview(hintLabel)
        view.addSubview(hintBox)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        dim.frame = view.bounds
        layoutCard()
        if !isShown {
            dim.alpha = 0
            card.transform = hiddenTransform
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !isShown else {
            return
        }

        isShown = true
        UIView.animate(withDuration: 0.25) {
            self.dim.alpha = 1
        }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0) {
            self.card.transform = .identity
        }
    }

    func updateHeight() {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.layoutCard()
            self.card.layoutIfNeeded()
        }
    }

    func close(then completion: (@MainActor () -> Void)? = nil) {
        guard !isClosing else {
            return
        }

        isClosing = true
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.dim.alpha = 0
            self.hintBox.alpha = 0
            self.card.transform = self.hiddenTransform
        } completion: { _ in
            self.dismiss(animated: false) {
                completion?()
            }
        }
    }

    func showHint(_ text: String?) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideHint), object: nil)
        guard let text else {
            hideHint()

            return
        }

        hintLabel.text = text
        let limit = view.bounds.width - 32
        let size = hintLabel.sizeThatFits(CGSize(width: limit - 24, height: 40))
        let width = min(ceil(size.width) + 24, limit)
        hintBox.frame = CGRect(x: card.frame.maxX - width, y: card.frame.minY - 42, width: width, height: 34)
        hintLabel.frame = hintBox.bounds.insetBy(dx: 12, dy: 0)
        UIView.animate(withDuration: 0.2) {
            self.hintBox.alpha = 1
        }
        perform(#selector(hideHint), with: nil, afterDelay: 2.5)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer.location(in: card).y < Self.dragArea
    }

    private var hiddenTransform: CGAffineTransform {
        CGAffineTransform(translationX: 0, y: card.bounds.height + Self.margin + view.safeAreaInsets.bottom)
    }

    private func layoutCard() {
        let margin = Self.margin
        let width = min(view.bounds.width - margin * 2, Self.maxWidth)
        let limit = view.bounds.height - view.safeAreaInsets.top - margin * 2
        let height = min(contentHeight(width), limit)
        card.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        card.center = CGPoint(x: view.bounds.midX, y: view.bounds.height - margin - height / 2)
        content.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    }

    @objc
    private func dimTapped() {
        close()
    }

    @objc
    private func hideHint() {
        UIView.animate(withDuration: 0.2) {
            self.hintBox.alpha = 0
        }
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        let offset = max(0, gesture.translation(in: view).y)
        switch gesture.state {
        case .changed:
            card.transform = CGAffineTransform(translationX: 0, y: offset)
        case .ended, .cancelled:
            if offset > 120 || gesture.velocity(in: view).y > 900 {
                close()
            } else {
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                    self.card.transform = .identity
                }
            }
        default:
            break
        }
    }
}

extension UIViewController {
    var floatingSheet: FloatingSheetController? {
        parent as? FloatingSheetController
    }
}
