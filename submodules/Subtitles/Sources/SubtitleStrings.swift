public struct SubtitleStrings: Sendable {
    public let title: String
    public let show: String
    public let language: String
    public let style: String
    public let styleShadow: String
    public let stylePlate: String
    public let stylePop: String
    public let empty: String
    public let hint: String
    public let add: String
    public let edit: String
    public let save: String
    public let cancel: String

    public init(
        title: String,
        show: String,
        language: String,
        style: String,
        styles: (shadow: String, plate: String, pop: String),
        empty: String,
        hint: String,
        add: String,
        edit: String,
        save: String,
        cancel: String
    ) {
        self.title = title
        self.show = show
        self.language = language
        self.style = style
        styleShadow = styles.shadow
        stylePlate = styles.plate
        stylePop = styles.pop
        self.empty = empty
        self.hint = hint
        self.add = add
        self.edit = edit
        self.save = save
        self.cancel = cancel
    }
}
