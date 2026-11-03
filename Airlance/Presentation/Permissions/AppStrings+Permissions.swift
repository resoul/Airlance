import PermissionsAPI

extension AppStrings {
    func title(for permission: Permission) -> String {
        switch permission {
        case .notifications:
            permissionNotificationsTitle
        case .camera:
            permissionCameraTitle
        case .microphone:
            permissionMicrophoneTitle
        case .photos:
            permissionPhotosTitle
        case .contacts:
            permissionContactsTitle
        case .location:
            permissionLocationTitle
        case .speech:
            permissionSpeechTitle
        }
    }

    func summary(for permission: Permission) -> String {
        switch permission {
        case .notifications:
            permissionNotificationsSummary
        case .camera:
            permissionCameraSummary
        case .microphone:
            permissionMicrophoneSummary
        case .photos:
            permissionPhotosSummary
        case .contacts:
            permissionContactsSummary
        case .location:
            permissionLocationSummary
        case .speech:
            permissionSpeechSummary
        }
    }

    func refusal(for permission: Permission) -> String {
        switch permission {
        case .notifications:
            permissionNotificationsRefusal
        case .camera:
            permissionCameraRefusal
        case .microphone:
            permissionMicrophoneRefusal
        case .photos:
            permissionPhotosRefusal
        case .contacts:
            permissionContactsRefusal
        case .location:
            permissionLocationRefusal
        case .speech:
            permissionSpeechRefusal
        }
    }

    func title(for status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            permissionStatusNotDetermined
        case .granted:
            permissionStatusGranted
        case .limited:
            permissionStatusLimited
        case .denied:
            permissionStatusDenied
        case .restricted:
            permissionStatusRestricted
        }
    }
}
