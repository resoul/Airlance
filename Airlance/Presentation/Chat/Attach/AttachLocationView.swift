import CoreLocation
import Haptics
import MapKit
import Theme
import UIKit

final class AttachLocationView: UIView, MKMapViewDelegate {
    struct Pick {
        let coordinate: CLLocationCoordinate2D
        let isCurrent: Bool
    }

    var onPick: (@MainActor (Pick) -> Void)?

    private let presentation: PresentationData
    private let map = MKMapView()
    private let pin = UIImageView()
    private let sendButton = UIButton(type: .system)
    private let recenter = UIButton(type: .system)
    private var isStarted = false
    private var followsUser = true

    init(presentation: PresentationData) {
        self.presentation = presentation
        super.init(frame: .zero)
        let colors = presentation.theme.colors
        map.delegate = self
        map.layer.cornerRadius = 14
        map.layer.cornerCurve = .continuous
        map.showsCompass = false
        addSubview(map)
        pin.image = UIImage(
            systemName: "mappin.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 34)
        )
        pin.tintColor = colors.accent
        pin.contentMode = .bottom
        addSubview(pin)
        recenter.setImage(UIImage(systemName: "location.fill"), for: .normal)
        recenter.backgroundColor = colors.surface
        recenter.tintColor = colors.accent
        recenter.layer.cornerRadius = 20
        recenter.addAction(
            UIAction { [weak self] _ in
                self?.centerOnUser(animated: true)
            },
            for: .touchUpInside
        )
        addSubview(recenter)
        setupSendButton(colors)
        updateButton()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupSendButton(_ colors: ThemeColors) {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = colors.accent
        configuration.baseForegroundColor = colors.onAccent
        configuration.image = UIImage(systemName: "location.circle.fill")
        configuration.imagePadding = 8
        sendButton.configuration = configuration
        sendButton.addAction(
            UIAction { [weak self] _ in
                self?.send()
            },
            for: .touchUpInside
        )
        addSubview(sendButton)
    }

    func start() {
        guard !isStarted else {
            return
        }

        isStarted = true
        map.showsUserLocation = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let buttonHeight: CGFloat = 50
        map.frame = CGRect(x: 12, y: 0, width: bounds.width - 24, height: bounds.height - buttonHeight - 12)
        pin.frame = CGRect(x: map.frame.midX - 20, y: map.frame.midY - 40, width: 40, height: 40)
        recenter.frame = CGRect(x: map.frame.maxX - 52, y: map.frame.maxY - 52, width: 40, height: 40)
        sendButton.frame = CGRect(x: 12, y: map.frame.maxY + 10, width: bounds.width - 24, height: buttonHeight)
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if followsUser {
            centerOnUser(animated: false)
        }
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let isGesture = mapView.subviews.first?.gestureRecognizers?.contains { gesture in
            gesture.state == .began || gesture.state == .changed
        } ?? false
        if isGesture {
            followsUser = false
            updateButton()
        }
    }

    private func centerOnUser(animated: Bool) {
        guard let location = map.userLocation.location else {
            return
        }

        followsUser = true
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 600, longitudinalMeters: 600)
        map.setRegion(region, animated: animated)
        updateButton()
    }

    private func updateButton() {
        let strings = presentation.strings
        sendButton.configuration?.title = followsUser ? strings.attachSendMyLocation : strings.attachSendPlace
    }

    private func send() {
        let current = followsUser ? map.userLocation.location?.coordinate : nil
        Haptics.play(.tap)
        onPick?(Pick(coordinate: current ?? map.centerCoordinate, isCurrent: current != nil))
    }
}
