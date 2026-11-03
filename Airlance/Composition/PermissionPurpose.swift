import PermissionsAPI

enum PermissionPurpose {
    case attachMedia
    case takePhoto
    case voiceMessage
    case videoMessage
    case shareContact
    case findFriends
    case sendLocation
    case transcribeVoice

    var permissions: [Permission] {
        switch self {
        case .attachMedia:
            [.photos]
        case .takePhoto:
            [.camera]
        case .voiceMessage:
            [.microphone]
        case .videoMessage:
            [.camera, .microphone]
        case .shareContact, .findFriends:
            [.contacts]
        case .sendLocation:
            [.location]
        case .transcribeVoice:
            [.speech]
        }
    }
}
