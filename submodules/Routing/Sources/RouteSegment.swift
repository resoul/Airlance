public struct RouteSegment: Hashable, Sendable, CustomStringConvertible {
    public let name: String
    public let argument: String?

    public init(_ name: String, argument: String? = nil) {
        self.name = name
        self.argument = argument
    }

    init?(parsing text: Substring) {
        guard let open = text.firstIndex(of: "(") else {
            guard Self.isValid(text) else {
                return nil
            }

            self.init(String(text))

            return
        }

        let name = text[..<open]
        let argument = text[text.index(after: open)...].dropLast()
        guard text.hasSuffix(")"), Self.isValid(name), Self.isValid(argument) else {
            return nil
        }

        self.init(String(name), argument: String(argument))
    }

    public var description: String {
        guard let argument else {
            return name
        }

        return "\(name)(\(argument))"
    }

    private static func isValid(_ text: Substring) -> Bool {
        !text.isEmpty && text.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_" || character == "-"
        }
    }
}
