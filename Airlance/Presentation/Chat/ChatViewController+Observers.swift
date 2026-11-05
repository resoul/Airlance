extension ChatViewController {
    func observeStores() {
        storeObservations = [
            dependencies.chatsStore.observe { [weak self] _ in
                self?.renderCurrent()
            },
            dependencies.connectionStatus.observe { [weak self] _ in
                self?.renderCurrent()
            },
        ]
    }

    private func renderCurrent() {
        render(presentation)
    }
}
