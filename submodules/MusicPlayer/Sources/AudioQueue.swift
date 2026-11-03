struct AudioQueue {
    private(set) var tracks: [AudioTrack] = []
    private var sequence: [Int] = []
    private var cursor = 0

    var current: AudioTrack? {
        sequence.indices.contains(cursor) ? tracks[sequence[cursor]] : nil
    }

    var ordered: [AudioTrack] {
        sequence.map { index in
            tracks[index]
        }
    }

    mutating func jump(to position: Int) -> Bool {
        guard sequence.indices.contains(position) else {
            return false
        }

        cursor = position

        return true
    }

    var hasPrevious: Bool {
        cursor > 0
    }

    func hasNext(looping: PlaybackLooping) -> Bool {
        cursor + 1 < sequence.count || (looping == .all && !sequence.isEmpty)
    }

    mutating func load(_ tracks: [AudioTrack], start: Int, order: PlaybackOrder) {
        self.tracks = tracks
        arrange(order, keeping: start)
    }

    mutating func arrange(_ order: PlaybackOrder, keeping index: Int? = nil) {
        let anchor = index ?? (sequence.indices.contains(cursor) ? sequence[cursor] : 0)
        var indices = Array(tracks.indices)
        switch order {
        case .regular:
            break
        case .reversed:
            indices.reverse()
        case .random:
            indices.removeAll { item in
                item == anchor
            }
            indices.shuffle()
            indices.insert(anchor, at: 0)
        }
        sequence = indices
        cursor = sequence.firstIndex(of: anchor) ?? 0
    }

    mutating func advance(looping: PlaybackLooping) -> Bool {
        if cursor + 1 < sequence.count {
            cursor += 1

            return true
        }

        guard looping == .all, !sequence.isEmpty else {
            return false
        }

        cursor = 0

        return true
    }

    mutating func back() -> Bool {
        guard cursor > 0 else {
            return false
        }

        cursor -= 1

        return true
    }

    mutating func update(_ track: AudioTrack) {
        let index = tracks.firstIndex { item in
            item.id == track.id && item.groupID == track.groupID
        }
        guard let index else {
            return
        }

        tracks[index] = track
    }

    mutating func clear() {
        tracks = []
        sequence = []
        cursor = 0
    }
}
