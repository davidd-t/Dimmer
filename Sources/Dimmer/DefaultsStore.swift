import Foundation
import DimmerCore

/// Remembers the slider position between launches.
@MainActor
final class DefaultsStore: PositionStoring {
    private let key = "sliderPosition"

    var savedPosition: Double? {
        get { UserDefaults.standard.object(forKey: key) as? Double }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
