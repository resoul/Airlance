import AVFoundation

public enum DeviceCameras {
    public static var supportsMultiCam: Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }
}
