import Haptics
import MediaStore
import ParticlesUI
import UIKit

struct StorageDependencies {
    let presentationContext: PresentationContext
    let media: MediaStore
}

final class StorageViewController: ScreenViewController {
    let chart = ParticleChartView()
    let caption = UILabel()
    let hint = UILabel()
    let rows = StorageCategory.allCases.map { category in
        StorageRow(category: category)
    }
    let clearButton = HoldToClearButton()
    var usage = StorageUsage()
    var enabled = Set(StorageCategory.allCases)
    var selected: StorageCategory?
    var clearing: Set<StorageCategory> = []
    var lastCounts: [Int] = []
    var hasShown = false
    var isLoaded = false
    var effect = StorageEffect.blackHole
    var ringCenter = CGPoint.zero
    var outerRadius: CGFloat = 0
    var innerRadius: CGFloat = 0

    private let dependencies: StorageDependencies
    private let scroll = UIScrollView()
    private let effects = UISegmentedControl(items: StorageEffect.allCases.map { effect in
        UIImage(systemName: effect.symbol) as Any
    })
    private let card = UIView()
    private let note = UILabel()
    private var scanRevision = 0
    private var laidOutWidth: CGFloat = 0

    private var scanner: StorageScanner {
        StorageScanner(media: dependencies.media)
    }

    init(dependencies: StorageDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        for label in [caption, hint, note] {
            label.textAlignment = .center
            label.numberOfLines = 0
            scroll.addSubview(label)
        }
        effects.selectedSegmentIndex = effect.rawValue
        effects.addTarget(self, action: #selector(effectChanged), for: .valueChanged)
        scroll.addSubview(effects)
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        scroll.addSubview(card)
        for row in rows {
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            card.addSubview(row)
        }
        clearButton.onFire = { [weak self] in
            self?.clear()
        }
        card.addSubview(clearButton)
        chart.onTap = { [weak self] point in
            self?.chartTapped(at: point)
        }
        scroll.addSubview(chart)
        scan()
    }

    override func apply(_ presentation: PresentationData) {
        let theme = presentation.theme
        let strings = presentation.strings
        navigationItem.title = strings.settingsStorage
        view.backgroundColor = theme.colors.background
        card.backgroundColor = theme.colors.surface
        caption.font = HistoryStyle.bold(theme.fonts.title)
        caption.textColor = theme.colors.textPrimary
        hint.font = theme.fonts.caption
        hint.textColor = theme.colors.textSecondary
        note.font = theme.fonts.caption
        note.textColor = theme.colors.textSecondary
        note.text = strings.storageNote
        for row in rows {
            row.apply(theme, title: row.category.title(strings))
        }
        for effect in StorageEffect.allCases {
            effects.imageForSegment(at: effect.rawValue)?.accessibilityLabel = effect.title(strings)
        }
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scroll.frame = view.bounds
        let width = view.bounds.width
        guard width != laidOutWidth else {
            return
        }

        laidOutWidth = width
        layout(width: width)
        refresh()
    }

    private func layout(width: CGFloat) {
        outerRadius = min(width * 0.3, 118)
        innerRadius = outerRadius * 0.62
        ringCenter = CGPoint(x: width / 2, y: 20 + outerRadius)
        caption.frame = CGRect(x: 16, y: ringCenter.y + outerRadius + 26, width: width - 32, height: 30)
        hint.frame = CGRect(x: 16, y: caption.frame.maxY + 2, width: width - 32, height: 20)
        effects.frame = CGRect(x: 16, y: hint.frame.maxY + 18, width: width - 32, height: 32)
        let cardWidth = width - 32
        var y: CGFloat = 8
        for row in rows {
            row.frame = CGRect(x: 0, y: y, width: cardWidth, height: StorageRow.height)
            y += StorageRow.height
        }
        clearButton.frame = CGRect(x: 16, y: y + 12, width: cardWidth - 32, height: 50)
        card.frame = CGRect(x: 16, y: effects.frame.maxY + 14, width: cardWidth, height: clearButton.frame.maxY + 16)
        let noteHeight = ceil(note.sizeThatFits(CGSize(width: width - 48, height: 200)).height)
        note.frame = CGRect(x: 24, y: card.frame.maxY + 12, width: width - 48, height: noteHeight)
        let height = note.frame.maxY + 24
        scroll.contentSize = CGSize(width: width, height: height)
        chart.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let reach = outerRadius + 24
        chart.touchArea = CGRect(x: ringCenter.x - reach, y: ringCenter.y - reach, width: reach * 2, height: reach * 2)
    }

    func scan() {
        scanRevision += 1
        let revision = scanRevision
        let scanner = scanner
        Task { [weak self] in
            let usage = await scanner.scan()
            guard let self, revision == self.scanRevision else {
                return
            }

            self.usage = usage
            self.isLoaded = true
            self.clearing = []
            self.refresh()
        }
    }

    @objc
    private func effectChanged() {
        effect = StorageEffect(rawValue: effects.selectedSegmentIndex) ?? .blackHole
        Haptics.play(.selection)
    }

    @objc
    private func rowTapped(_ row: StorageRow) {
        guard clearing.isEmpty else {
            return
        }

        if enabled.remove(row.category) == nil {
            enabled.insert(row.category)
        }
        if !enabled.contains(row.category), selected == row.category {
            selected = nil
        }
        Haptics.play(.selection)
        refresh()
    }

    private func clear() {
        let categories = enabled.filter { category in
            usage.size(category) > 0
        }
        guard clearing.isEmpty, !categories.isEmpty else {
            return
        }

        clearing = categories
        selected = nil
        Haptics.play(.warning)
        refresh()
        pulseRows(categories)
        let scanner = scanner
        let duration = effect.duration
        Task { [weak self] in
            await scanner.clear(categories)
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            Haptics.play(.success)
            self?.scan()
        }
    }

    private func pulseRows(_ categories: Set<StorageCategory>) {
        guard effect == .rows else {
            return
        }

        for row in rows where categories.contains(row.category) {
            let delay = effect.duration * 0.55
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak row] in
                row?.show(bytes: 0, share: 0, isFirst: false)
                row?.pulse()
                Haptics.play(.tap)
            }
        }
    }
}
