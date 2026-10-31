import SwiftUI

extension EnvironmentValues {
    /// The logged period starts, for the PMDD lens's labels and period toggles.
    @Entry var cycleCalendar = CycleCalendar.empty
}
