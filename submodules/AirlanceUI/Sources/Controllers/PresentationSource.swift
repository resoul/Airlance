import Observers
import Theme

public protocol ThemedPresentation: Sendable {
    var theme: AppTheme { get }
}

@MainActor
public protocol PresentationSource<Presentation>: AnyObject {
    associatedtype Presentation: ThemedPresentation

    var presentation: Presentation { get }

    func observe(_ onChange: @escaping @MainActor @Sendable (Presentation) -> Void) -> ObservationToken
}
