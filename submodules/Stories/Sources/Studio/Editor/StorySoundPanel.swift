import Haptics
import UIKit

final class StorySoundPanel: UIView {
    var onChange: (@MainActor (StorySound) -> Void)?
    var onPickTrack: (@MainActor () -> Void)?
    var onRecord: (@MainActor (Bool) -> Void)?

    private(set) var sound: StorySound
    let strip = StoryTrackStrip()
    private let strings: StoryStudioStrings
    private let isVideo: Bool
    private let length: TimeInterval
    private let trackButton = UIButton(type: .system)
    private let removeTrack = UIButton(type: .system)
    private let recordButton = UIButton(type: .system)
    private let removeVoice = UIButton(type: .system)
    private let rows: [StorySoundRow]
    private var isRecording = false

    init(sound: StorySound, strings: StoryStudioStrings, isVideo: Bool, length: TimeInterval) {
        self.sound = sound
        self.strings = strings
        self.isVideo = isVideo
        self.length = length
        rows = [
            StorySoundRow(title: strings.label(.soundOriginal)),
            StorySoundRow(title: strings.label(.soundTrack)),
            StorySoundRow(title: strings.label(.soundVoice)),
        ]
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.05, alpha: 0.72)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        setUpButtons()
        strip.onStart = { [weak self] start, isFinal in
            self?.sound.track?.start = start
            if isFinal, let sound = self?.sound {
                self?.onChange?(sound)
            }
        }
        addSubview(strip)
        for (index, row) in rows.enumerated() {
            row.onChange = { [weak self] value in
                self?.setVolume(value, row: index)
            }
            addSubview(row)
        }
        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var preferredHeight: CGFloat {
        var height: CGFloat = 14 + 40 + 12
        if sound.track != nil {
            height += 44 + 12
        }
        height += CGFloat(visibleRows.count) * 38

        return height + 48 + 16
    }

    func set(sound: StorySound) {
        self.sound = sound
        apply()
    }

    func setWaveform(_ samples: [Float]) {
        guard let track = sound.track else {
            return
        }

        strip.set(samples: samples, duration: track.duration, length: length, start: track.start)
    }

    func setRecording(_ isRecording: Bool) {
        self.isRecording = isRecording
        recordButton.backgroundColor = isRecording ? .systemRed : UIColor(white: 1, alpha: 0.14)
        let title = isRecording ? strings.label(.soundRecording) : strings.label(.soundRecord)
        recordButton.setTitle(" " + title, for: .normal)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inner = bounds.width - 32
        removeTrack.isHidden = sound.track == nil
        trackButton.frame = CGRect(x: 16, y: 14, width: inner - (removeTrack.isHidden ? 0 : 44), height: 40)
        removeTrack.frame = CGRect(x: bounds.width - 16 - 40, y: 14, width: 40, height: 40)
        var y = trackButton.frame.maxY + 12
        strip.isHidden = sound.track == nil
        if !strip.isHidden {
            strip.frame = CGRect(x: 16, y: y, width: inner, height: 44)
            y += 56
        }
        let visible = visibleRows
        for row in rows {
            row.isHidden = !visible.contains(where: { candidate in
                candidate === row
            })
        }
        for row in visible {
            row.frame = CGRect(x: 16, y: y, width: inner, height: 38)
            y += 38
        }
        removeVoice.isHidden = sound.voice == nil
        recordButton.frame = CGRect(x: 16, y: y + 4, width: inner - (removeVoice.isHidden ? 0 : 52), height: 44)
        removeVoice.frame = CGRect(x: bounds.width - 16 - 44, y: y + 4, width: 44, height: 44)
    }

    private var visibleRows: [StorySoundRow] {
        var visible: [StorySoundRow] = []
        if isVideo {
            visible.append(rows[0])
        }
        if sound.track != nil {
            visible.append(rows[1])
        }
        if sound.voice != nil {
            visible.append(rows[2])
        }

        return visible
    }

    private func apply() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        trackButton.setImage(UIImage(systemName: "music.note", withConfiguration: configuration), for: .normal)
        trackButton.setTitle(" " + trackTitle, for: .normal)
        rows[0].value = sound.originalVolume
        rows[1].value = sound.track?.volume ?? 1
        rows[2].value = sound.voice?.volume ?? 1
        setRecording(isRecording)
        setNeedsLayout()
    }

    private var trackTitle: String {
        guard let track = sound.track else {
            return strings.label(.soundAddTrack)
        }

        return [track.title, track.artist].compactMap(\.self).joined(separator: " · ")
    }

    private func setVolume(_ value: Float, row: Int) {
        switch row {
        case 0:
            sound.originalVolume = value
        case 1:
            sound.track?.volume = value
        default:
            sound.voice?.volume = value
        }
        onChange?(sound)
    }

    private func setUpButtons() {
        trackButton.tintColor = .white
        trackButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        trackButton.titleLabel?.lineBreakMode = .byTruncatingTail
        trackButton.contentHorizontalAlignment = .left
        trackButton.addAction(UIAction { [weak self] _ in
            self?.onPickTrack?()
        }, for: .touchUpInside)
        style(removeTrack, symbol: "xmark")
        removeTrack.addAction(UIAction { [weak self] _ in
            self?.remove(voice: false)
        }, for: .touchUpInside)
        style(removeVoice, symbol: "trash")
        removeVoice.addAction(UIAction { [weak self] _ in
            self?.remove(voice: true)
        }, for: .touchUpInside)
        recordButton.tintColor = .white
        recordButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        recordButton.layer.cornerRadius = 22
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        recordButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: configuration), for: .normal)
        recordButton.addAction(UIAction { [weak self] _ in
            self?.onRecord?(true)
        }, for: .touchDown)
        recordButton.addAction(UIAction { [weak self] _ in
            self?.onRecord?(false)
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
        for view in [trackButton, removeTrack, recordButton, removeVoice] {
            addSubview(view)
        }
    }

    private func style(_ button: UIButton, symbol: String) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(white: 1, alpha: 0.14)
        button.layer.cornerRadius = 20
    }

    private func remove(voice: Bool) {
        Haptics.play(.tap)
        if voice {
            sound.voice = nil
        } else {
            sound.track = nil
        }
        apply()
        onChange?(sound)
    }
}

final class StorySoundRow: UIView {
    var onChange: (@MainActor (Float) -> Void)?

    var value: Float {
        get {
            slider.value
        }
        set {
            slider.value = newValue
        }
    }

    private let label = UILabel()
    private let slider = UISlider()

    init(title: String) {
        super.init(frame: .zero)
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.25)
        slider.addAction(UIAction { [weak self] _ in
            guard let self else {
                return
            }

            self.onChange?(self.slider.value)
        }, for: .valueChanged)
        addSubview(label)
        addSubview(slider)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = CGRect(x: 0, y: 0, width: 84, height: bounds.height)
        slider.frame = CGRect(x: 92, y: 0, width: bounds.width - 92, height: bounds.height)
    }
}
