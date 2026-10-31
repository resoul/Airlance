extension AppStrings {
    func typing(_ name: String) -> String {
        name.isEmpty ? chatTyping : chatTypingName(name)
    }
}
