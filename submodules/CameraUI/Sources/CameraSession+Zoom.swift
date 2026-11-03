import AVFoundation
import UIKit

extension CameraSession {
    static let zoomLimit: CGFloat = 10

    var baseFactor: CGFloat {
        let types = device?.constituentDevices.map(\.deviceType) ?? []
        guard types.contains(.builtInUltraWideCamera),
              let first = device?.virtualDeviceSwitchOverVideoZoomFactors.first else {
            return 1
        }

        return CGFloat(first.doubleValue)
    }

    public var zoomRange: ClosedRange<CGFloat> {
        let base = baseFactor
        let maximum = min((device?.maxAvailableVideoZoomFactor ?? 1) / base, Self.zoomLimit)

        return (1 / base)...max(maximum, 1)
    }

    public var zoom: CGFloat {
        (device?.videoZoomFactor ?? 1) / baseFactor
    }

    public var lensStops: [CGFloat] {
        let base = baseFactor
        let lenses = device?.virtualDeviceSwitchOverVideoZoomFactors.map { factor in
            CGFloat(factor.doubleValue) / base
        } ?? []
        var stops = Set(lenses.filter { lens in
            lens > 1
        })
        stops.formUnion([1, 2])
        if base > 1 {
            stops.insert(1 / base)
        }

        return stops.filter(zoomRange.contains).sorted()
    }

    var tangentAtUnitZoom: CGFloat {
        let degrees = CGFloat(device?.activeFormat.videoFieldOfView ?? 70)

        return tan(degrees * .pi / 360) / baseFactor
    }

    public func setZoom(_ display: CGFloat) {
        guard let device, (try? device.lockForConfiguration()) != nil else {
            return
        }

        let range = zoomRange
        device.videoZoomFactor = min(max(display, range.lowerBound), range.upperBound) * baseFactor
        device.unlockForConfiguration()
    }

    public func resetZoom() {
        setZoom(1)
    }

    static func camera(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: position)

        return types.lazy.compactMap { type in
            discovery.devices.first { device in
                device.deviceType == type
            }
        }.first
    }
}
