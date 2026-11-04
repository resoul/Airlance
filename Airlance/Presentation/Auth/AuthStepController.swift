import Theme
import ToastUI
import UIKit

final class AuthStepController: ScreenViewController {
    private static let resendDelay = 60
    private static let sideInset: CGFloat = 24

    var onPrimary: (@MainActor ([String]) -> Void)?
    var onSecondary: (@MainActor () -> Void)?

    private let step: AuthStep
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let wordmark = UILabel()
    private let heroView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let codesView = AuthCodesView()
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)
    private let footer = UIStackView()
    private let playsIntro: Bool
    private var logo: AuthLogoParticles?
    private var fieldViews: [AuthFieldView] = []
    private var resendLeft = 0

    init(step: AuthStep, playsIntro: Bool = false, presentationSource: PresentationContext) {
        self.step = step
        self.playsIntro = playsIntro
        super.init(presentationSource: presentationSource)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonDisplayMode = .minimal
        buildContent()
        buildFooter()
        buildLogo()
        if case .code = step {
            startResendCountdown()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutLogo()
    }

    private func layoutLogo() {
        guard let logo else {
            return
        }

        scrollView.layoutIfNeeded()
        logo.chart.frame = view.bounds
        logo.layout(slot: wordmark.convert(wordmark.bounds, to: view))
    }

    func setLogoPaused(_ isPaused: Bool) {
        logo?.chart.isPaused = isPaused
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutLogo()
        fieldViews.first?.textField.becomeFirstResponder()
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let content = step.content(presentation.strings)
        wordmark.text = ParticleWordmark.word
        wordmark.textColor = theme.colors.accent
        logo?.update(tint: theme.colors.accent)
        wordmark.isHidden = true
        heroView.tintColor = theme.colors.accent
        heroView.isHidden = true
        switch content.hero {
        case .wordmark:
            wordmark.isHidden = false
        case .symbol(let name):
            heroView.image = UIImage(systemName: name)
            heroView.isHidden = false
        }
        titleLabel.text = content.title
        titleLabel.font = theme.fonts.title
        titleLabel.textColor = theme.colors.textPrimary
        messageLabel.text = content.message
        messageLabel.font = theme.fonts.body
        messageLabel.textColor = theme.colors.textSecondary
        codesView.apply(theme)
        for field in fieldViews {
            field.apply(presentation)
        }
        primaryButton.applyAuthFilled(title: content.primary, theme: theme)
        updateButtons()
    }

    private func buildContent() {
        wordmark.font = .systemFont(ofSize: 52, weight: .black)
        wordmark.textAlignment = .center
        wordmark.adjustsFontSizeToFitWidth = true
        heroView.contentMode = .scaleAspectFit
        heroView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 56, weight: .regular)
        for label in [titleLabel, messageLabel] {
            label.numberOfLines = 0
            label.textAlignment = .center
        }
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        for subview in [wordmark, heroView, titleLabel, messageLabel] as [UIView] {
            stack.addArrangedSubview(subview)
        }
        stack.setCustomSpacing(24, after: wordmark)
        stack.setCustomSpacing(24, after: heroView)
        stack.setCustomSpacing(24, after: messageLabel)
        fieldViews = step.fields.map(makeField)
        for field in fieldViews {
            stack.addArrangedSubview(field)
        }
        if case .recoveryCodes = step {
            stack.addArrangedSubview(codesView)
        }
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
    }

    private func buildFooter() {
        primaryButton.addAction(
            UIAction { [weak self] _ in
                self?.primaryTapped()
            },
            for: .touchUpInside
        )
        secondaryButton.addAction(
            UIAction { [weak self] _ in
                self?.secondaryTapped()
            },
            for: .touchUpInside
        )
        footer.addArrangedSubview(primaryButton)
        footer.addArrangedSubview(secondaryButton)
        footer.axis = .vertical
        footer.spacing = 6
        footer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footer)
        activateLayout()
    }

    private func buildLogo() {
        guard step.showsWordmark, AuthLogoParticles.isAvailable else {
            return
        }

        let logo = AuthLogoParticles(tint: presentation.theme.colors.accent, playsIntro: playsIntro)
        logo.onContentReveal = { [weak self] in
            self?.revealContent()
        }
        view.addSubview(logo.chart)
        wordmark.alpha = 0
        if playsIntro {
            stack.alpha = 0
            footer.alpha = 0
        }
        self.logo = logo
    }

    private func revealContent() {
        UIView.animate(withDuration: 0.5, delay: 0.25) {
            self.stack.alpha = 1
            self.footer.alpha = 1
        }
    }

    private func activateLayout() {
        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        let fitHeight = content.heightAnchor.constraint(equalTo: frame.heightAnchor)
        fitHeight.priority = .defaultLow
        let placement = step.isCentered
            ? stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
            : stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.sideInset)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
            fitHeight,
            placement,
            stack.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: Self.sideInset),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -Self.sideInset),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.sideInset),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.sideInset),
            footer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Self.sideInset),
            footer.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -Self.sideInset
            ),
            footer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
            primaryButton.heightAnchor.constraint(equalToConstant: 52),
            secondaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    private func makeField(_ kind: AuthFieldKind) -> AuthFieldView {
        let field = AuthFieldView(kind: kind)
        field.onChange = { [weak self] in
            self?.updateButtons()
        }

        return field
    }

    private func updateButtons() {
        primaryButton.isEnabled = fieldViews.allSatisfy(\.isValid)
        let theme = presentation.theme
        let title = secondaryTitle
        secondaryButton.isHidden = title == nil
        if let title {
            secondaryButton.applyAuthPlain(title: title, theme: theme)
        }
        if case .code = step {
            secondaryButton.isEnabled = resendLeft == 0
        }
    }

    private var secondaryTitle: String? {
        let strings = presentation.strings
        guard case .code = step else {
            return step.content(strings).secondary
        }

        return resendLeft > 0 ? strings.authCodeResendIn(resendLeft) : strings.authCodeResend
    }

    private func primaryTapped() {
        view.endEditing(true)
        onPrimary?(fieldViews.map(\.text))
    }

    private func secondaryTapped() {
        switch step {
        case .code:
            startResendCountdown()
        case .recoveryCodes:
            copyCodes()
        default:
            view.endEditing(true)
            onSecondary?()
        }
    }

    private func copyCodes() {
        UIPasteboard.general.string = AuthCodesView.samples.joined(separator: "\n")
        Toast(presentation.strings.authCodesCopied, symbol: "doc.on.doc")
            .show(theme: presentation.theme, in: view)
    }

    private func startResendCountdown() {
        resendLeft = Self.resendDelay
        updateButtons()
        Task { [weak self] in
            repeat {
                try? await Task.sleep(for: .seconds(1))
            } while self?.tickResend() == true
        }
    }

    private func tickResend() -> Bool {
        resendLeft -= 1
        updateButtons()

        return resendLeft > 0
    }
}
