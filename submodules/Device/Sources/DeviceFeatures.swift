import Foundation

public enum DeviceFeatures {
    public static var volumeCaptureButtons: Bool {
        if #available(iOS 17.2, *) {
            return true
        }

        return false
    }
}
