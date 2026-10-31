import ChatHistory
import UIKit

extension ChatInputBar {
    var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: textView.font ?? UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: textView.textColor ?? UIColor.label,
        ]
    }

    func setComposed(_ composed: ComposedText, animated: Bool) {
        textView.attributedText = composed.attributed(base: baseAttributes, style: composerStyle)
        textView.typingAttributes = baseAttributes
        textViewDidChange(textView)
    }

    func insertMention(name: String, userID: String) {
        guard let query = mentionRange() else {
            return
        }

        let mention = NSMutableAttributedString(string: "@" + name, attributes: baseAttributes)
        mention.addAttributes(composerStyle.mention(userID), range: NSRange(location: 0, length: mention.length))
        mention.append(NSAttributedString(string: " ", attributes: baseAttributes))
        textView.textStorage.replaceCharacters(in: query.range, with: mention)
        textView.selectedRange = NSRange(location: query.range.location + mention.length, length: 0)
        textView.typingAttributes = baseAttributes
        textViewDidChange(textView)
    }

    func reportMention() {
        onMentionQuery?(mentionRange()?.query)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        textView.typingAttributes = baseAttributes
        removeMentions(touching: range)

        return true
    }

    func textView(
        _ textView: UITextView,
        editMenuForTextIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard range.length > 0, let title = spoilerTitle else {
            return nil
        }

        let isSpoiler = textView.attributedText.attribute(
            ComposedText.spoilerKey,
            at: range.location,
            effectiveRange: nil
        ) != nil
        let image = UIImage(systemName: isSpoiler ? "eye" : "eye.slash")
        let spoiler = UIAction(title: title, image: image) { [weak self] _ in
            self?.toggleSpoiler(range, on: !isSpoiler)
        }

        return UIMenu(children: suggestedActions + [spoiler])
    }

    private func toggleSpoiler(_ range: NSRange, on: Bool) {
        let storage = textView.textStorage
        if on {
            storage.addAttributes(composerStyle.spoiler, range: range)
        } else {
            storage.removeAttribute(ComposedText.spoilerKey, range: range)
            storage.removeAttribute(.backgroundColor, range: range)
        }
        textView.selectedRange = NSRange(location: NSMaxRange(range), length: 0)
        textView.typingAttributes = baseAttributes
    }

    private func removeMentions(touching range: NSRange) {
        let storage = textView.textStorage
        var mentions: [NSRange] = []
        storage.enumerateAttribute(
            ComposedText.mentionKey,
            in: NSRange(location: 0, length: storage.length)
        ) { value, run, _ in
            let isInside = run.location < range.location && range.location < NSMaxRange(run)
            if value != nil, NSIntersectionRange(run, range).length > 0 || isInside {
                mentions.append(run)
            }
        }
        for mention in mentions {
            storage.removeAttribute(ComposedText.mentionKey, range: mention)
            storage.addAttributes(baseAttributes, range: mention)
        }
    }

    private var spoilerTitle: String? {
        strings?.chatSpoiler
    }

    private func mentionRange() -> (query: String, range: NSRange)? {
        let selection = textView.selectedRange
        guard selection.length == 0, textView.isFirstResponder else {
            return nil
        }

        let string = textView.text as NSString
        var start = selection.location
        while start > 0 {
            let character = string.character(at: start - 1)
            if character == 64 {
                let before = start - 1 == 0 ? nil : string.character(at: start - 2)
                let isWordStart = before.map { code in
                    CharacterSet.whitespacesAndNewlines.contains(Unicode.Scalar(code) ?? " ")
                } ?? true
                guard isWordStart else {
                    return nil
                }

                let range = NSRange(location: start - 1, length: selection.location - start + 1)
                let query = string.substring(with: NSRange(location: start, length: selection.location - start))

                return (query, range)
            }
            guard let scalar = Unicode.Scalar(character), CharacterSet.alphanumerics.contains(scalar) else {
                return nil
            }

            start -= 1
        }

        return nil
    }
}
