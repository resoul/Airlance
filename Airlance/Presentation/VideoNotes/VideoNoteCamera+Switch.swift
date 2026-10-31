import AVFoundation

extension VideoNoteCamera {
    func switchCamera() {
        guard canSwitch, !isSwitching else {
            return
        }

        if stylized == nil, mainOutput.isRecording {
            isSwitching = true
            mainOutput.stopRecording()
        } else {
            swapInput()
        }
    }

    func swapInput() {
        let next: AVCaptureDevice.Position = position == .front ? .back : .front
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: next),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }

        session.beginConfiguration()
        if let videoInput {
            session.removeInput(videoInput)
        }
        if session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
            position = next
        } else if let videoInput, session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        orientConnections()
        session.commitConfiguration()
    }
}
