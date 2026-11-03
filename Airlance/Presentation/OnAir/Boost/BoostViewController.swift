@preconcurrency import AsyncDisplayKit
import AvatarUI
import Observers
import UIKit

final class BoostViewController: ScreenViewController {
    let target: BoostTarget
    let store: OnAirStore
    let avatar = AvatarNode()
    let nameLabel = UILabel()
    let placeLabel = UILabel()
    let levelLabel = UILabel()
    let levelBar = UIProgressView(progressViewStyle: .default)
    let star = BoostStarButton()
    let hintLabel = UILabel()
    let costLabel = UILabel()
    let budgetBar = UIProgressView(progressViewStyle: .default)
    let budgetLabel = UILabel()
    let mineLabel = UILabel()
    let ruleLabel = UILabel()
    let resultLabel = UILabel()
    private var observation: ObservationToken?

    var channelID: String? {
        switch target {
        case .channel(let id):
            id
        case .post(let id):
            store.post(id)?.channelID
        }
    }

    init(target: BoostTarget, store: OnAirStore, presentationSource: PresentationContext) {
        self.target = target
        self.store = store
        super.init(presentationSource: presentationSource)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubnode(avatar)
        avatar.isOnScreen = true
        let labels = [nameLabel, placeLabel, levelLabel, hintLabel, costLabel, budgetLabel, mineLabel, ruleLabel]
        for label in labels + [resultLabel] {
            label.textAlignment = .center
            label.numberOfLines = 0
            view.addSubview(label)
        }
        placeLabel.numberOfLines = 3
        resultLabel.alpha = 0
        view.addSubview(levelBar)
        view.addSubview(star)
        view.addSubview(budgetBar)
        view.bringSubviewToFront(resultLabel)
        star.onBoost = { [weak self] isSuper in
            self?.boost(isSuper: isSuper)
        }
        star.onDenied = { [weak self] in
            self?.showResult(self?.presentation.strings.boostEmpty ?? "", color: .systemRed)
        }
        observation = store.observe { [weak self] _ in
            self?.update()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = min(view.bounds.width - 48, 420)
        let left = (view.bounds.width - width) / 2
        var y = view.safeAreaInsets.top + 28
        avatar.frame = CGRect(x: view.bounds.midX - 32, y: y, width: 64, height: 64)
        y = avatar.frame.maxY + 10
        y = place(nameLabel, x: left, y: y, width: width) + 2
        y = place(placeLabel, x: left, y: y, width: width) + 6
        y = place(levelLabel, x: left, y: y, width: width) + 4
        levelBar.isHidden = levelLabel.isHidden
        levelBar.frame = CGRect(x: view.bounds.midX - 60, y: y, width: 120, height: 4)
        y += levelBar.isHidden ? 40 : 48
        star.frame = CGRect(x: view.bounds.midX - 100, y: y, width: 200, height: 200)
        resultLabel.frame = CGRect(x: left, y: star.frame.minY - 36, width: width, height: 28)
        y = star.frame.maxY + 48
        y = place(hintLabel, x: left, y: y, width: width) + 8
        y = place(costLabel, x: left, y: y, width: width) + 18
        budgetBar.frame = CGRect(x: left + 24, y: y, width: width - 48, height: 4)
        y = budgetBar.frame.maxY + 8
        y = place(budgetLabel, x: left, y: y, width: width) + 4
        y = place(mineLabel, x: left, y: y, width: width) + 14
        _ = place(ruleLabel, x: left, y: y, width: width)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        view.backgroundColor = theme.groupedBackground
        nameLabel.font = theme.fonts.headline
        nameLabel.textColor = theme.colors.textPrimary
        placeLabel.font = theme.fonts.subheadline
        levelLabel.font = theme.fonts.subheadline
        hintLabel.font = theme.fonts.subheadline
        hintLabel.textColor = theme.colors.textPrimary
        hintLabel.text = presentation.strings.boostHint
        for label in [costLabel, budgetLabel, mineLabel, ruleLabel] {
            label.font = theme.fonts.caption
            label.textColor = theme.colors.textSecondary
        }
        ruleLabel.text = presentation.strings.boostRule
        resultLabel.font = .systemFont(ofSize: 20, weight: .heavy)
        budgetBar.progressTintColor = theme.colors.accent
        budgetBar.trackTintColor = theme.colors.separator
        levelBar.trackTintColor = theme.colors.separator
        star.baseColor = theme.colors.textPrimary
        update()
    }

    private func boost(isSuper: Bool) {
        let strings = presentation.strings
        guard store.boost(target, votes: isSuper ? 2 : 1) else {
            showResult(strings.boostEmpty, color: .systemRed)

            return
        }

        showResult(isSuper ? strings.boostSuperDone : strings.boostDone, color: .systemOrange)
    }

    private func showResult(_ text: String, color: UIColor) {
        resultLabel.text = text
        resultLabel.textColor = color
        resultLabel.layer.removeAllAnimations()
        resultLabel.alpha = 1
        resultLabel.transform = CGAffineTransform(translationX: 0, y: 24)
        UIView.animate(withDuration: 0.9, delay: 0, options: [.curveEaseOut]) {
            self.resultLabel.transform = CGAffineTransform(translationX: 0, y: -12)
        }
        UIView.animate(withDuration: 0.4, delay: 0.8, options: [.curveEaseIn]) {
            self.resultLabel.alpha = 0
        }
    }

    private func place(_ label: UILabel, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let hasText = label.text?.isEmpty == false || label.attributedText?.length ?? 0 > 0
        let height = hasText && !label.isHidden
            ? label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            : 0
        label.frame = CGRect(x: x, y: y, width: width, height: height)

        return label.frame.maxY
    }
}
