import UIKit

enum SettingsEntry: String, CaseIterable {
    case profile
    case saved
    case calls
    case devices
    case folders
    case notifications
    case privacy
    case permissions
    case passcode
    case appearance
    case videoNotes
    case language
    case about

    var section: Int {
        switch self {
        case .profile, .saved, .calls, .devices, .folders:
            0
        case .notifications, .privacy, .permissions, .passcode, .appearance, .videoNotes, .language:
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
        case .permissions:
            "hand.raised.fill"
        case .passcode:
            "lock.shield.fill"
        case .appearance:
            "paintbrush.fill"
        case .videoNotes:
            "video.bubble.fill"
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
        case .calls, .passcode:
            .systemGreen
        case .devices, .videoNotes:
            .systemOrange
        case .folders:
            .systemTeal
        case .privacy:
            .systemGray
        case .language:
            .systemPurple
        }
    }

    var route: AppRoute? {
        switch self {
        case .permissions:
            .permissions
        case .appearance, .language:
            .appearance
        case .folders:
            .chatFolders
        case .videoNotes:
            .videoNotes
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
        case .permissions:
            strings.settingsPermissions
        case .passcode:
            strings.settingsPasscode
        case .appearance:
            strings.settingsAppearance
        case .videoNotes:
            strings.videoNotesTitle
        case .language:
            strings.settingsLanguage
        case .about:
            strings.settingsAbout
        }
    }
}
