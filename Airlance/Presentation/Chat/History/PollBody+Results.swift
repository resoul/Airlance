@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

extension PollBody {
    func addResult(
        _ index: Int,
        to body: inout BubbleBody,
        top: CGFloat,
        textHeight: CGFloat,
        width: CGFloat,
        style: HistoryStyle
    ) {
        let share = poll.share(of: index)
        let percent = MessageBubbleLayout.label(
            "\(Int((share * 100).rounded()))%",
            font: HistoryStyle.bold(style.metaFont),
            color: style.text(outgoing: outgoing),
            width: Self.percentWidth
        )
        percent.frame.origin = CGPoint(x: padding.left, y: top + (textHeight - percent.frame.height) / 2)
        body.content.addSubnode(percent)
        let barWidth = width - Self.percentWidth
        let bar = ASDisplayNode()
        bar.isLayerBacked = true
        bar.backgroundColor = barColor(index, style: style)
        bar.cornerRadius = 2
        bar.frame = CGRect(
            x: padding.left + Self.percentWidth,
            y: top + textHeight + 4,
            width: max(4, barWidth * share),
            height: 4
        )
        body.content.addSubnode(bar)
        body.pollBars.append(bar)
    }

    private func barColor(_ index: Int, style: HistoryStyle) -> UIColor {
        let tint = style.tint(outgoing: outgoing)
        let isChosen = poll.chosen.contains(index)
        guard poll.isQuiz else {
            return isChosen ? tint : tint.withAlphaComponent(0.45)
        }

        if index == poll.correctOption {
            return style.success
        }

        return isChosen ? style.failed : tint.withAlphaComponent(0.45)
    }

    func addFooter(to body: inout BubbleBody, at top: CGFloat, width: CGFloat, style: HistoryStyle) -> CGFloat {
        let meta = MessageMeta(input, delivery: outgoing ? input.message.delivery : nil, style: style)
        let footer = footerText()
        let color = footer.action == nil ? style.meta(outgoing: outgoing) : style.tint(outgoing: outgoing)
        let font = footer.action == nil ? style.metaFont : HistoryStyle.bold(style.metaFont)
        let available = width - padding.left - padding.right - meta.size.width * 2 - 8
        let label = MessageBubbleLayout.label(footer.text, font: font, color: color, width: available)
        let lineHeight = max(label.frame.height, meta.size.height)
        let labelY = top + (lineHeight - label.frame.height) / 2
        label.frame.origin = CGPoint(x: (width - label.frame.width) / 2, y: labelY)
        body.content.addSubnode(label)
        meta.place(in: body.content, bottomRight: CGPoint(x: width - padding.right, y: top + lineHeight))
        if let action = footer.action {
            let frame = CGRect(x: 0, y: top - 6, width: width, height: lineHeight + 12)
            body.actions.append(BubbleAction(frame: frame, kind: action))
        }

        return top + lineHeight
    }

    private func footerText() -> (text: String, action: BubbleAction.Kind?) {
        let canVote = poll.allowsMultiple && !poll.isQuiz && !poll.showsResults
        if canVote {
            return (titles.vote, input.pollDraft.isEmpty ? nil : .pollVote)
        }

        if poll.showsResults, !poll.isAnonymous, poll.voters > 0 {
            return (titles.results, .pollResults)
        }

        return (poll.voters == 0 ? titles.noVotes : titles.votes(poll.voters), nil)
    }
}

extension PollTitles {
    init(strings: AppStrings) {
        let locale = strings.pack.locale
        self.init(
            anonymous: strings.pollAnonymous,
            open: strings.pollPublic,
            quiz: strings.pollQuiz,
            anonymousQuiz: strings.pollAnonymousQuiz,
            multiple: strings.pollMultiple,
            closed: strings.pollClosed,
            vote: strings.pollVote,
            noVotes: strings.pollNoVotes,
            results: strings.pollResults,
            votes: { count in
                strings.count(count, one: strings.pollVotesOne, few: strings.pollVotesFew, many: strings.pollVotesMany)
            },
            closesAt: { date in
                let time = Date.FormatStyle.dateTime.hour().minute()
                let style = Calendar.current.isDateInToday(date) ? time : time.day().month(.abbreviated)

                return strings.pollClosesAt(date.formatted(style.locale(locale)))
            }
        )
    }
}
