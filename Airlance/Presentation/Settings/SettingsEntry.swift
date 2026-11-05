import UIKit

enum SettingsEntry: String, CaseIterable {
    case profile
    case saved
    case calls
    case devices
    case folders
    case notifications
    case privacy
    case agents
    case permissions
    case passcode
    case appearance
    case tabs
    case storage
    case powerSaving
    case stories
    case language
    case about

    var section: Int {
        switch self {
        case .profile, .saved, .calls, .devices, .folders:
            0
        case .notifications, .privacy, .agents, .permissions, .passcode, .appearance, .tabs, .storage,
             .powerSaving, .stories, .language:
            1
        case .about:
            2
        }
    }

    var symbol: String {
        switch self {
        case .profile:
            "person.crop.circle.fill"
        case .saved:
            "bookmark.fill"
        case .calls:
            "phone.fill"
        case .devices:
            "laptopcomputer"
        case .folders:
            "folder.fill"
        case .notifications:
            "bell.badge.fill"
        case .privacy:
            "lock.fill"
        case .agents:
            "wand.and.stars"
        case .permissions:
            "hand.raised.fill"
        case .passcode:
            "lock.shield.fill"
        case .appearance:
            "paintbrush.fill"
        case .tabs:
            "square.grid.3x1.below.line.grid.1x2.fill"
        case .storage:
            "internaldrive.fill"
        case .powerSaving:
            "battery.75percent"
        case .stories:
            "circle.dashed"
        case .language:
            "globe"
        case .about:
            "info.circle.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .profile, .notifications:
            .systemRed
        case .saved, .permissions, .appearance, .about:
            .systemBlue
        case .calls, .passcode, .storage:
            .systemGreen
        case .devices, .powerSaving:
            .systemOrange
        case .folders, .stories:
            .systemTeal
        case .privacy:
            .systemGray
        case .language:
            .systemPurple
        case .tabs, .agents:
            .systemIndigo
        }
    }

    var route: AppRoute? {
        switch self {
        case .permissions:
            .permissions
        case .appearance:
            .appearance
        case .language:
            .settingsPage(.language)
        case .powerSaving:
            .settingsPage(.powerSaving)
        case .stories:
            .settingsPage(.stories)
        case .privacy:
            .settingsPage(.privacy)
        case .agents:
            .settingsPage(.agents)
        case .folders:
            .chatFolders
        case .storage:
            .storage
        case .tabs:
            .tabSettings
        default:
            nil
        }
    }

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .profile:
            strings.settingsProfile
        case .saved:
            strings.settingsSaved
        case .calls:
            strings.settingsCalls
        case .devices:
            strings.settingsDevices
        case .folders:
            strings.settingsFolders
        case .notifications:
            strings.settingsNotifications
        case .privacy:
            strings.settingsPrivacy
        case .agents:
            strings.settingsAgents
        case .permissions:
            strings.settingsPermissions
        case .passcode:
            strings.settingsPasscode
        case .appearance:
            strings.settingsAppearance
        case .tabs:
            strings.tabsTitle
        case .storage:
            strings.settingsStorage
        case .powerSaving:
            strings.powerTitle
        case .stories:
            strings.settingsStories
        case .language:
            strings.settingsLanguage
        case .about:
            strings.settingsAbout
        }
    }
}
