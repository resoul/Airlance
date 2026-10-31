import ChatHistory
import UIKit

final class VideoReactionPlayerController: UIViewController {
    private let reaction: MessageVideoReaction
    private let presentation: PresentationData
    private let noteView: VideoNoteView
    private let nameLabel = UILabel()

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
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let side = min(view.bounds.width - 60, 300)
        let origin = CGPoint(x: (view.bounds.width - side) / 2, y: view.bounds.midY - side / 2)
        noteView.frame = CGRect(origin: origin, size: CGSize(width: side, height: side))
        nameLabel.frame = CGRect(x: 20, y: noteView.frame.maxY + 18, width: view.bounds.width - 40, height: 24)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        noteView.toggle()
    }

    @objc
    private func close() {
        dismiss(animated: true)
    }
}
