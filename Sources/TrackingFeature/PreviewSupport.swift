import SwiftUI
import DataLayer

// MARK: - Preview support (issue #7)
//
// Previews only. Repository APIs and `DataStore.init` are @MainActor, which
// a `#Preview` closure can't call directly, so this helper builds an
// in-memory `TrackingEnvironment` and runs the seeding closure on the main
// actor. Previews execute on the main actor, so `assumeIsolated` is safe.

/// Build an in-memory `TrackingEnvironment`, run `seed` on the main actor,
/// and return the configured content view.
func withPreviewEnvironment<Content: View>(
    seed: @MainActor (TrackingEnvironment) -> Void = { _ in },
    @ViewBuilder content: (TrackingEnvironment) -> Content
) -> some View {
    MainActor.assumeIsolated {
        let store = try! DataStore(inMemory: true)
        let env = TrackingEnvironment(store: store)
        seed(env)
        return content(env)
    }
}
