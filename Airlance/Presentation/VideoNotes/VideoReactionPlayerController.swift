import ChatHistory
import UIKit

final class VideoReactionPlayerController: UIViewController {
    var onDelete: (@MainActor () -> Void)?

    private let reaction: MessageVideoReaction
    private let presentation: PresentationData
    private let noteView: VideoNoteView
    private let nameLabel = UILabel()
    private let deleteButton = UIButton(type: .system)

    init(reaction: MessageVideoReaction, presentation: PresentationData) {
        self.reaction = reaction
        self.presentation = presentation
        noteView = VideoNoteView(note: reaction.note, accent: presentation.theme.colors.accent)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.frame = view.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blur)
        view.addSubview(noteView)
        nameLabel.text = reaction.author.id == Reactions.me.id ? presentation.strings.chatYou : reaction.author.name
        nameLabel.font = HistoryStyle.bold(presentation.theme.fonts.body)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        view.addSubview(nameLabel)
        setupDelete()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let side = min(view.bounds.width - 60, 300)
        let origin = CGPoint(x: (view.bounds.width - side) / 2, y: view.bounds.midY - side / 2)
        noteView.frame = CGRect(origin: origin, size: CGSize(width: side, height: side))
        nameLabel.frame = CGRect(x: 20, y: noteView.frame.maxY + 18, width: view.bounds.width - 40, height: 24)
        let size = deleteButton.sizeThatFits(CGSize(width: view.bounds.width - 40, height: 44))
        deleteButton.frame = CGRect(
            x: (view.bounds.width - size.width) / 2,
            y: view.bounds.height - view.safeAreaInsets.bottom - size.height - 24,
            width: size.width,
            height: size.height
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        noteView.toggle()
    }

    private func setupDelete() {
        deleteButton.isHidden = reaction.author.id != Reactions.me.id
        var configuration = UIButton.Configuration.filled()
        configuration.title = presentation.strings.videoNotesReactionDelete
        configuration.image = UIImage(systemName: "trash")
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.white.withAlphaComponent(0.18)
        configuration.baseForegroundColor = .systemRed
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        deleteButton.configuration = configuration
        deleteButton.addAction(
            UIAction { [weak self] _ in
                self?.delete()
            },
            for: .touchUpInside
        )
        view.addSubview(deleteButton)
    }

    private func delete() {
        let onDelete = onDelete
        dismiss(animated: true) {
            onDelete?()
        }
    }

    @objc
    private func close() {
        dismiss(animated: true)
    }
}
