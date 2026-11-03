import ListUI
import Observers
import UIKit

struct PowerSavingDependencies {
    let presentationContext: PresentationContext
    let powerSaving: PowerSaving
}

final class PowerSavingController: ScreenViewController {
    private let dependencies: PowerSavingDependencies
    private let listView = ListView(theme: ListTheme())
    private var observation: ObservationToken?

    init(dependencies: PowerSavingDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observation = dependencies.powerSaving.observe { [weak self] _ in
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.powerTitle
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let power = dependencies.powerSaving
        let settings = power.settings
        let isAlways = settings.threshold >= PowerSavingSettings.always
        var items: [any ListItem] = [
            SectionHeaderItem(id: "mode", title: strings.powerMode),
            SettingsSliderItem(
                id: "slider",
                value: settings.threshold,
                leftTitle: strings.powerOff,
                rightTitle: strings.powerOn,
                title: { value in
                    Self.title(value, strings: strings)
                },
                onChange: { value in
                    power.update { settings in
                        settings.threshold = value
                    }
                }
            ),
            FootnoteItem(id: "mode-hint", text: Self.hint(settings.threshold, strings: strings)),
            SpacerItem(id: "gap", height: 12),
            SectionHeaderItem(id: "features", title: strings.powerFeatures),
        ]
        items += featureRows(settings, isAlways: isAlways)
        if power.isSaving, !isAlways {
            items.append(FootnoteItem(id: "active", text: strings.powerActive))
        }
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
    }

    private func featureRows(_ settings: PowerSavingSettings, isAlways: Bool) -> [SettingsOptionItem] {
        let strings = presentation.strings
        let power = dependencies.powerSaving
        let rows = PowerFeature.allCases.map { feature in
            SettingsOptionItem(
                id: feature.rawValue,
                title: feature.title(strings),
                subtitle: feature.subtitle(strings),
                symbol: feature.symbol,
                iconColor: feature.color,
                accessory: .toggle(!isAlways && !settings.disabled.contains(feature)),
                isEnabled: !isAlways,
                onToggle: { isOn in
                    power.update { settings in
                        if isOn {
                            settings.disabled.remove(feature)
                        } else {
                            settings.disabled.insert(feature)
                        }
                    }
                }
            )
        }

        return rows.positioned()
    }

    private static func title(_ value: Int, strings: AppStrings) -> String {
        switch value {
        case PowerSavingSettings.off:
            strings.powerNever
        case PowerSavingSettings.always...:
            strings.powerAlways
        default:
            strings.powerBelow("\(value)%")
        }
    }

    private static func hint(_ value: Int, strings: AppStrings) -> String {
        switch value {
        case PowerSavingSettings.off:
            strings.powerNeverHint
        case PowerSavingSettings.always...:
            strings.powerAlwaysHint
        default:
            strings.powerBelowHint("\(value)%")
        }
    }
}

extension PowerFeature {
    var symbol: String {
        switch self {
        case .videoAutoplay:
            "video.fill"
        case .liquidEffects:
            "drop.fill"
        case .particleEffects:
            "sparkles"
        case .preload:
            "arrow.down.circle.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .videoAutoplay:
            .systemRed
        case .liquidEffects:
            .systemTeal
        case .particleEffects:
            .systemPurple
        case .preload:
            .systemBlue
        }
    }

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .videoAutoplay:
            strings.powerVideo
        case .liquidEffects:
            strings.powerLiquid
        case .particleEffects:
            strings.powerParticles
        case .preload:
            strings.powerPreload
        }
    }

    func subtitle(_ strings: AppStrings) -> String {
        switch self {
        case .videoAutoplay:
            strings.powerVideoHint
        case .liquidEffects:
            strings.powerLiquidHint
        case .particleEffects:
            strings.powerParticlesHint
        case .preload:
            strings.powerPreloadHint
        }
    }
}
