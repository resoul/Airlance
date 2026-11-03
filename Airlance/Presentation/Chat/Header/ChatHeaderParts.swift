import MusicPlayer
import Observers
import UIKit

@MainActor
final class ChatHeaderParts {
    let card = FloatingCard()
    let audioPanel = AudioPanelView()
    var isAudioShown = false
    var audioObservation: ObservationToken?
}
