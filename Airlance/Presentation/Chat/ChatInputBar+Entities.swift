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
        guard range.length > 0, let strings else {
            return nil
        }

        let formats: [(MessageEntity.Kind, String, String)] = [
            (.bold, strings.chatFormatBold, "bold"),
            (.italic, strings.chatFormatItalic, "italic"),
            (.strikethrough, strings.chatFormatStrikethrough, "strikethrough"),
            (.code, strings.chatFormatCode, "chevron.left.forwardslash.chevron.right"),
            (.pre, strings.chatFormatPre, "curlybraces"),
            (.quote, strings.chatFormatQuote, "text.quote"),
            (.spoiler, strings.chatSpoiler, "eye.slash"),
        ]
        var actions = formats.map { kind, title, symbol in
            formatAction(kind, title: title, symbol: symbol, range: range)
        }
        let clearImage = UIImage(systemName: "textformat")
        let clear = UIAction(title: strings.chatFormatClear, image: clearImage) { [weak self] _ in
            self?.clearFormatting(range)
        }
        actions.append(clear)
        let formatImage = UIImage(systemName: "bold.italic.underline")
        let format = UIMenu(title: strings.chatFormat, image: formatImage, children: actions)

        return UIMenu(children: suggestedActions + [format])
    }

    private func formatAction(_ kind: MessageEntity.Kind, title: String, symbol: String, range: NSRange) -> UIAction {
        let isOn = ComposedText.key(for: kind).map { key in
            covers(range, key: key)
        } ?? false
        let action = UIAction(title: title, image: UIImage(systemName: symbol)) { [weak self] _ in
            self?.setFormat(kind, on: !isOn, range: range)
        }
        action.state = isOn ? .on : .off

        return action
    }

    private func covers(_ range: NSRange, key: NSAttributedString.Key) -> Bool {
        var covered = true
        textView.attributedText.enumerateAttribute(key, in: range) { value, _, stop in
            if value == nil {
                covered = false
                stop.pointee = true
            }
        }

        return covered
    }

    private func setFormat(_ kind: MessageEntity.Kind, on: Bool, range: NSRange) {
        guard let key = ComposedText.key(for: kind) else {
            return
        }

        let storage = textView.textStorage
        if on {
            storage.addAttribute(key, value: true, range: range)
        } else {
            storage.removeAttribute(key, range: range)
        }
        restyle(keeping: range)
    }

    private func clearFormatting(_ range: NSRange) {
        for format in ComposedText.formats {
            textView.textStorage.removeAttribute(format.key, range: range)
        }
        restyle(keeping: range)
    }

    private func restyle(keeping range: NSRange) {
        composerStyle.render(textView.textStorage, base: baseAttributes)
        textView.selectedRange = range
        textView.typingAttributes = baseAttributes
        textViewDidChange(textView)
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
        }
        if !mentions.isEmpty {
            composerStyle.render(storage, base: baseAttributes)
        }
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
