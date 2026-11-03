import Haptics
import UIKit

extension StoryViewerController {
    func showAnswer(prompt: String, hint: String, tint: UIColor, widget: UUID, item: String) {
        let answer = StoryAnswerView(prompt: prompt, hint: hint, tint: tint, sendTitle: label(.answerSend))
        answer.onClose = { [weak self] in
            self?.closeAnswer()
        }
        answer.onSend = { [weak self] text in
            self?.onInteraction?(.answer(item: item, widget: widget, text: text))
            Haptics.play(.success)
            self?.closeAnswer()
            self?.flash(self?.label(.answerSent) ?? "")
        }
        answer.frame = view.bounds
        view.addSubview(answer)
        answerView = answer
        isInteracting = true
        page?.media.setPaused(true)
        answer.layoutIfNeeded()
        answer.begin()
    }

    func burst(_ emoji: String, from widgetView: StoryWidgetView) {
        let origin = widgetView.convert(CGPoint(x: widgetView.bounds.midX, y: widgetView.bounds.midY), to: view)
        for index in 0..<8 {
            let label = UILabel()
            label.text = emoji
            label.font = .systemFont(ofSize: CGFloat.random(in: 26...40))
            label.sizeToFit()
            label.center = origin
            view.addSubview(label)
            let angle = CGFloat(index) / 8 * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let distance = CGFloat.random(in: 80...150)
            UIView.animate(withDuration: 0.9, delay: 0, options: .curveEaseOut) {
                label.center = CGPoint(
                    x: origin.x + cos(angle) * distance,
                    y: origin.y + sin(angle) * distance - 60
                )
                label.alpha = 0
                label.transform = CGAffineTransform(rotationAngle: CGFloat.random(in: -0.6...0.6))
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }

    private func closeAnswer() {
        answerView?.dismiss()
        answerView = nil
        isInteracting = false
        page?.media.setPaused(isHeld)
    }

    private func flash(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 0.08, alpha: 0.86)
        label.layer.cornerRadius = 18
        label.clipsToBounds = true
        label.bounds = CGRect(x: 0, y: 0, width: ceil(label.intrinsicContentSize.width) + 32, height: 36)
        label.center = CGPoint(x: view.bounds.midX, y: view.bounds.height * 0.4)
        label.alpha = 0
        view.addSubview(label)
        UIView.animate(withDuration: 0.2) {
            label.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.2) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }
}
