@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct PollTitles: Sendable {
    let anonymous: String
    let open: String
    let quiz: String
    let anonymousQuiz: String
    let multiple: String
    let closed: String
    let vote: String
    let noVotes: String
    let results: String
    let votes: @Sendable (Int) -> String
    let closesAt: @Sendable (Date) -> String
}

struct PollBody {
    static let indicator: CGFloat = 20
    static let percentWidth: CGFloat = 44

    let poll: MessagePoll
    let input: MessageBubbleInput
    let scale: CGFloat
    let maxBubble: CGFloat
    let titles: PollTitles

    var padding: UIEdgeInsets {
        MessageBubbleLayout.padding
    }

    var outgoing: Bool {
        input.message.isOutgoing
    }

    func make(style: HistoryStyle) -> BubbleBody {
        let width = min(maxBubble, 300)
        let contentWidth = width - padding.left - padding.right
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: .zero, content: content)
        var y = padding.top
        let header = BubbleHeader(input, style: style, maxWidth: contentWidth, scale: scale)
        if !header.isEmpty {
            body.add(header.place(in: content, at: CGPoint(x: padding.left, y: y), width: contentWidth))
            y += header.size.height + 4
        }
        y = addTitle(to: &body, at: y, width: contentWidth, style: style) + 10
        for index in poll.options.indices {
            y = addOption(index, to: &body, at: y, width: contentWidth, style: style)
        }
        y = addFooter(to: &body, at: y + 4, width: width, style: style)
        let size = CGSize(width: ceil(width), height: ceil(y + padding.bottom))
        content.frame = CGRect(origin: .zero, size: size)
        body.size = size

        return body
    }

    private var hasExplanation: Bool {
        poll.isQuiz && poll.showsResults && !(poll.explanation ?? "").isEmpty
    }

    private func addTitle(to body: inout BubbleBody, at top: CGFloat, width: CGFloat, style: HistoryStyle) -> CGFloat {
        let bulb: CGFloat = hasExplanation ? 26 : 0
        let question = MessageBubbleLayout.label(
            poll.question,
            font: HistoryStyle.bold(style.textFont),
            color: style.text(outgoing: outgoing),
            width: width - bulb,
            lines: 0
        )
        question.frame.origin = CGPoint(x: padding.left, y: top)
        body.content.addSubnode(question)
        if hasExplanation {
            addExplanationButton(to: &body, top: top, width: width, style: style)
        }
        let meta = style.meta(outgoing: outgoing)
        let subtitle = MessageBubbleLayout.label(kindText, font: style.metaFont, color: meta, width: width)
        subtitle.frame.origin = CGPoint(x: padding.left, y: question.frame.maxY + 2)
        body.content.addSubnode(subtitle)

        return subtitle.frame.maxY
    }

    private var kindText: String {
        var kind: String
        if poll.isClosed {
            kind = titles.closed
        } else if poll.isQuiz {
            kind = poll.isAnonymous ? titles.anonymousQuiz : titles.quiz
        } else {
            kind = poll.isAnonymous ? titles.anonymous : titles.open
        }
        if poll.allowsMultiple, !poll.isQuiz, !poll.isClosed {
            kind += " · " + titles.multiple
        }
        if let date = poll.closeDate, !poll.isClosed {
            kind += " · " + titles.closesAt(date)
        }

        return kind
    }

    private func addExplanationButton(to body: inout BubbleBody, top: CGFloat, width: CGFloat, style: HistoryStyle) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let node = ASImageNode()
        node.isLayerBacked = true
        node.contentMode = .center
        node.image = UIImage(systemName: "lightbulb.fill", withConfiguration: configuration)?
            .withTintColor(style.tint(outgoing: outgoing), renderingMode: .alwaysOriginal)
        node.frame = CGRect(x: padding.left + width - 22, y: top, width: 22, height: 22)
        body.content.addSubnode(node)
        body.actions.append(BubbleAction(frame: node.frame.insetBy(dx: -10, dy: -8), kind: .pollExplanation))
    }

    private func addOption(
        _ index: Int,
        to body: inout BubbleBody,
        at top: CGFloat,
        width: CGFloat,
        style: HistoryStyle
    ) -> CGFloat {
        let showsResults = poll.showsResults
        let inset = showsResults ? Self.percentWidth : Self.indicator + 10
        let text = MessageBubbleLayout.label(
            optionTitle(index),
            font: style.textFont,
            color: style.text(outgoing: outgoing),
            width: width - inset,
            lines: 0
        )
        let textHeight = max(text.frame.height, Self.indicator)
        text.frame.origin = CGPoint(x: padding.left + inset, y: top + (textHeight - text.frame.height) / 2)
        body.content.addSubnode(text)
        let rowHeight = textHeight + (showsResults ? 12 : 14)
        if showsResults {
            addResult(index, to: &body, top: top, textHeight: textHeight, width: width, style: style)
        } else {
            body.content.addSubnode(indicator(for: index, top: top + (textHeight - Self.indicator) / 2, style: style))
            let frame = CGRect(x: 0, y: top - 6, width: width + padding.left + padding.right, height: rowHeight)
            body.actions.append(BubbleAction(frame: frame, kind: .pollOption(index)))
        }

        return top + rowHeight
    }

    private func optionTitle(_ index: Int) -> String {
        let text = poll.options[index].text
        guard poll.showsResults else {
            return text
        }

        if poll.isQuiz {
            if index == poll.correctOption {
                return "✓ " + text
            }

            return poll.chosen.contains(index) ? "✗ " + text : text
        }

        return poll.chosen.contains(index) ? "✓ " + text : text
    }

    private func indicator(for index: Int, top: CGFloat, style: HistoryStyle) -> ASImageNode {
        let isPicked = input.pollDraft.contains(index)
        let symbol = isPicked ? "checkmark.circle.fill" : "circle"
        let color = isPicked ? style.tint(outgoing: outgoing) : style.meta(outgoing: outgoing)
        let configuration = UIImage.SymbolConfiguration(pointSize: Self.indicator - 2)
        let node = ASImageNode()
        node.isLayerBacked = true
        node.contentMode = .center
        node.image = UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        node.frame = CGRect(x: padding.left, y: top, width: Self.indicator, height: Self.indicator)

        return node
    }
}
