import AvatarUI
import EffectsUI
import LiquidUI
import ListUI
import Observers
import ParticlesUI
import PowerSaving

@MainActor
final class PowerSavingEffects {
    private var observation: ObservationToken?

    init(store: PowerSavingStore) {
        observation = store.observe { [weak store] _ in
            guard let store else {
                return
            }

            AvatarPlayback.shared.isAllowed = store.isEnabled(.videoAutoplay)
            LiquidEffects.isEnabled = store.isEnabled(.liquidEffects)
            ViewEffectsSettings.isEnabled = store.isEnabled(.particleEffects)
            ParticleEffects.isEnabled = store.isEnabled(.particleEffects)
            ListView.prefetchesAhead = store.isEnabled(.preload)
        }
    }
}
